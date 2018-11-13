package validation;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(validate_domain
                 validate_transport
                 validate_local_domain
                 validate_new_email
                 validate_password
                 validate_email
                 validate_subscription_on_loop
                 validate_address
                 login_max_length
                 password_min_length
                 password_min_classes
                 password_chars);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Data::Validate::Domain;
use Data::Validate::IP qw(is_ipv4);

use utils;

use constant {login_max_length => 12,
              password_min_length => 8,
              password_min_classes => 3,
              password_chars => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456.,:;|[]{}()-_+=*&^%$#@!~'};

# ====== Валидация доменов и транспортов ======

# Проверка домена
sub validate_domain($)
{
  my $value = field_text_default(shift, "");

  # Всё в порядке
  return undef if is_domain($value);

  return "Указанная строка $value не похожа на правильный домен DNS!\n";
}

# Проверка транспорта (ipv6 не поддерживается)
sub validate_transport($)
{
  my $value = field_text_default(shift, "");

  # Если настройка локальных транспортов определена и указан хотя бы один транспорт
  if ((defined config->{postadmin}->{local_transports}) &&
      (scalar @{config->{postadmin}->{local_transports}}))
  {
    # Если транспорт имеется в списке локальных - всё в порядке
    foreach my $transport (@{config->{postadmin}->{local_transports}})
    {
      return "" if $value eq $transport;
    }
  }

  # Делим строку транспорта на части
  my ($transport, $host, $port) = split(":", $value);

  # Транспорты, отличные от smtp, считаются не правильными
  return "Неправильный транспорт $value.\n" if $transport ne "smtp";

  # Если узел - это домен или IPv4-адрес
  if (is_domain($host) || is_ipv4($host))
  {
    # И порт - целое число, то всё в порядке
    return undef if $port =~ m/^\d+$/;
  }

  return "Указанная строка $value не похожа на правильный транспорт Postfix!\n";
}

# Проверка, что домен является локальным для почтовой системы
sub validate_local_domain($)
{
  my $value = field_text_default(shift, "");

  my $sth = database->prepare("SELECT COUNT(*)
                               FROM domain
                               WHERE domain = ?
                                 AND transport = ?");

  # Если настройка локальных транспортов определена и указан хотя бы один транспорт
  if ((defined config->{postadmin}->{local_transports}) &&
      (scalar @{config->{postadmin}->{local_transports}}))
  {
    # Перебираем локальные транспорты
    foreach my $transport (@{config->{postadmin}->{local_transports}})
    {
      # Если не удалось выполнить запрос, сообщаем об этом
      unless ($sth->execute($value, $transport))
      {
        $sth->finish();
        return "Не удалось проверить, является ли домен $value локальным.\n";
      }

      # Если домен действительно локальный, то больше ничего не проверяем
      my ($num) = $sth->fetchrow_array();
      if ($num > 0)
      {
        $sth->finish();
        return "";
      }
    }
    $sth->finish();
  }

  return "Домен $value не является локальным!\n";
}

# ====== Валидация пользователей и ящиков ======

# Проверка, что адрес электронной почты является локальным для почтового сервера
# и что этот адрес не занят
sub validate_new_email($)
{
  my $value = field_text_default(shift, "");

  # Делим адрес на ящик и домен
  my ($box, $domain) = split('\@', $value);

  # Если домен не локальный, сообщаем об этом
  my $error = validate_local_domain($domain);
  return $error if $error;

  # Проверка, занят ли этот адрес почтовым ящиком
  my $sth = database->prepare("SELECT COUNT(*)
                               FROM user
                               WHERE email = ?");
  unless ($sth->execute($value))
  {
    $sth->finish();
    return "Не удалось проверить, занят ли адрес $value.\n";
  }
  my ($num) = $sth->fetchrow_array();
  if ($num > 0)
  {
    $sth->finish();
    return "Уже существует почтовый ящик с адресом $value!\n";
  }
  $sth->finish();

  # Проверка, занят ли этот адрес псевдонимом или рассылкой
  $sth = database->prepare("SELECT COUNT(*)
                            FROM subscription
                            WHERE email = ?
                              AND direction = 'I'");
  unless ($sth->execute($value))
  {
    $sth->finish();
    return "Не удалось проверить, занят ли адрес $value.\n";
  }
  ($num) = $sth->fetchrow_array();
  if ($num > 0)
  {
    $sth->finish();
    return "Уже существует псеводним или рассылка с адресом $value!\n";
  }
  $sth->finish();

  return "";
}

# Проверка, что пароль достаточно длинный и сложный
sub validate_password($)
{
  my $value = field_text_default(shift, "");

  my $password_min_length = field_text_default(config->{postadmin}->{password_min_length}, password_min_length);

  if (length($value) < $password_min_length)
  {
    return "Минимальная длина пароля - $password_min_length символов.\n";
  }

  my $classes = 0;
  $classes++ if ($value =~ m/[a-z]+/);
  $classes++ if ($value =~ m/[A-Z]+/);
  $classes++ if ($value =~ m/\d+/);
  $classes++ if ($value =~ m/[.,:;\|\[\]\{\}\(\)-_\+=\*&\^%\$#@!~]+/);

  my $password_min_classes = field_text_default(config->{postadmin}->{password_min_classes}, password_min_classes);
  if ($classes < $password_min_classes)
  {
    return "Минимальная количество символов разного класса - $password_min_classes.\n";
  }

  return "";
}

# ====== Валидация подписок ======

# Проверка, приведёт ли эта пересылка к зацикливанию пересылок
sub is_looped_subscription($$)
{
  my $email = field_text_default(shift, "");
  my $recipient = field_text_default(shift, "");

  # Если адрес пересылки совпадает с адресом получателя - пересылка зациклена
  return 1 if $email eq $recipient;

  # Проверяем, есть ли пересылки, получателем которых является эта пересылка
  my $sth = database()->prepare("SELECT email
                                 FROM subscription
                                 WHERE recipient = ?
                                   AND direction = 'I'");
  $sth->execute($email);
  while (my ($email) = $sth->fetchrow_array())
  {
    if (&is_looped_subscription($email, $recipient))
    {
      # Цикл найден
      $sth->finish();
      return 1;
    }
  }
  $sth->finish();

  # Цикл не найден
  return 0;
}

# Проверка, приведёт ли эта пересылка к зацикливанию пересылок
sub validate_subscription_on_loop($$)
{
  my $email = field_text_default(shift, "");
  my $recipient = field_text_default(shift, "");

  if (is_looped_subscription($email, $recipient))
  {
    return "Указанный получаетель пересылки $recipient сам является источником почты для адреса $email!\n";
  }

  # Всё в порядке
  return "";
}

# Проверка правильности адреса электронной почты
sub validate_email($)
{
  my $value = field_text_default(shift, "");

  # Проверяем правильность адреса электронной почты с настройками по умолчанию
  return "" if Email::Valid->address($value);
  
  return "Указанная строка $value не является правильным адресом электронной почты.\n";
}

# ====== Валидация правил доступа ======

# Проверка, что указанный адрес - это домен DNS или адрес электронной почты
sub validate_address($)
{
  my $address = field_text_default(shift, "");

  my $error = validate_email($address);
  if ($error)
  {
    $error = validate_domain($address);
  }
  return "" unless $error;

  return "Указанная строка $address не похожа на правильный домен DNS или адрес электронной почты!";
}

1;
