package users;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(users_remove
                 users_change_max_bytes
                 users_change_max_messages
                 users_disable
                 users_enable
                 user_page
                 users_page
                 users_subscribe
                 user_edit
                 user_subscriptions_edit
                 get_password
                 get_free_login
                 get_ad_login
                 user_new
                 user_new_page);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Math::Round qw/round/;

use utils;
use validation;

# Удаление пользователя с передачей подписок по наследству
sub user_remove($)
{
  my $id = shift;
  $id = int($id);

  # Извлекаем адрес удаляемого пользователя
  my $sth = database()->prepare("SELECT email
                                 FROM user
                                 WHERE user.id = ?");
  $sth->execute($id);
  my ($email) = $sth->fetchrow_array();
  $sth->finish();

  if (!defined $id)
  {
    return "Пользователь с идентификатором $id не существует!\n";
  }

  # Извлекаем подписки удаляемого пользователя
  $sth = database()->prepare("SELECT subscription.email,
                                     subscription.direction
                              FROM user
                              JOIN subscription ON subscription.recipient = user.email
                              WHERE user.id = ?");
  $sth->execute($id);
  my $subscriptions = $sth->fetchall_arrayref();
  $sth->finish();

  # Извлекаем список получателей входящей почты удаляемого пользователя
  $sth = database()->prepare("SELECT subscription.recipient
                              FROM subscription
                              JOIN user ON user.email = subscription.email
                                AND user.id = ?
                              WHERE subscription.direction = 'I'");
  $sth->execute($id);
  my $recipients = $sth->fetchall_arrayref();
  $sth->finish();

  # Если у удаляемого пользователя были подписчики,
  # передаём подписки удаляемого пользователя подписчикам по наследству
  if (defined $recipients)
  {
    # Передача подписок по наследству
    $sth = database()->prepare("INSERT IGNORE subscription
                                SET email = ?,
                                    recipient = ?,
                                    direction = ?");

    # Если у удаляемого пользователя были подписки
    if (defined $subscriptions)
    {
      foreach my $rcpt (@{$recipients})
      {
        # Подписываем получателей на почту других пользователей,
        # которую получал удаляемый пользователь
        foreach my $subscription (@{$subscriptions})
        {
          $sth->execute($subscription->[0], $rcpt->[0], $subscription->[1]);
        }
      }
    }

    # Подписываем получателей на входящие удаляемого пользователя
    foreach my $rcpt (@{$recipients})
    {
      $sth->execute($email, $rcpt->[0], "I");
    }

    $sth->finish();
  }

  # Удаляем подписки удаляемого пользователя
  $sth = database()->prepare("DELETE FROM subscription
                              WHERE recipient = ?");
  $sth->execute($email);
  $sth->finish();

  # Удаляем подписки на исходящие удаляемого пользователя
  # Поскольку пользователя теперь не будет, не будет и исходящей почты от него
  $sth = database()->prepare("DELETE FROM subscription
                              WHERE direction = 'O'
                                AND email = ?");
  $sth->execute($email);
  $sth->finish();

  # Удаляем самого пользователя
  $sth = database()->prepare("DELETE FROM user
                              WHERE id = ?");
  $sth->execute($id);
  $sth->finish();

  # Всё прошло нормально
  return "";
}

# Массовое удаление пользователей с передачей их подписок по наследству
sub users_remove($)
{
  my $ids = shift;

  my $errors = "";
  if (ref($ids) eq "ARRAY")
  {
    return "Нечего удалять!\n" unless scalar @{$ids};

    foreach my $id (@{$ids})
    {
      $errors .= user_remove($id);
    }
  }
  elsif (ref($ids) eq "")
  {
    $ids = int($ids);
    $errors = user_remove($ids);
  }
  else
  {
    return "Нераспознанный тип аргумента!\n";
  }

  return $errors;
}

# Редактирование квоты объёма ящика
sub users_change_max_bytes($$)
{
  my $ids = shift;
  my $max_bytes = shift;

  $ids = join_ids($ids);
  return "Нечего обновлять!\n" unless defined $ids;

  $max_bytes = hr2bytes($max_bytes);

  my $sth = database()->prepare("UPDATE user
                                 SET max_bytes = ?
                                 WHERE id IN ($ids)");
  $sth->execute($max_bytes);
  $sth->finish();

  return "";
}

# Редактирование квоты количества сообщений
sub users_change_max_messages($$)
{
  my $ids = join_ids(shift);
  my $max_messages = field_number_default(shift, config->{postadmin}->{max_messages});

  $max_messages = int($max_messages);

  my $sth = database()->prepare("UPDATE user
                                 SET max_messages = ?
                                 WHERE id IN ($ids)");
  $sth->execute($max_messages);
  $sth->finish();

  return "";
}

# Отключение пользователей
sub users_disable($)
{
  my $ids = join_ids(shift);

  my $sth = database()->prepare("UPDATE user
                                 SET active = 'N'
                                 WHERE id IN ($ids)");
  $sth->execute();
  $sth->finish();

  return "";
}

# Включение пользователей
sub users_enable($)
{
  my $ids = join_ids(shift);

  my $sth = database()->prepare("UPDATE user
                                 SET active = 'Y'
                                 WHERE id IN ($ids)");
  $sth->execute();
  $sth->finish();

  return "";
}

# Возвращает данные для шаблона страницы с пользователем
sub user_page($)
{
  my $id = shift;

  # Информация о редактируемом пользователе
  my $sth = database->prepare("SELECT id,
                                      IF(active = 'Y', 1, 0) AS active,
                                      email,
                                      surname,
                                      name,
                                      patronym,
                                      department,
                                      position,
                                      phones,
                                      ad_login,
                                      lasttime,
                                      IFNULL(lastip, '') AS lastip,
                                      IFNULL(bytes, 0) AS bytes,
                                      max_bytes,
                                      IFNULL(messages, 0) AS messages,
                                      max_messages,
                                      smtp_acl
                               FROM user
                               WHERE id = ?");
  $sth->execute($id);
  my $user = $sth->fetchrow_hashref();
  $sth->finish();

  # Если пользователь не найден возвращаем пустую ссылку
  return undef unless defined $user;
  $user->{bytes} = bytes2hr($user->{bytes});
  $user->{max_bytes} = bytes2hr($user->{max_bytes});

  # Идентификатор предыдущего пользователя
  $sth = database->prepare("SELECT prev.id
                            FROM user AS prev
                            JOIN user ON prev.email < user.email
                              AND user.id = ?
                            ORDER BY prev.email DESC
                            LIMIT 1");
  $sth->execute($id);
  my ($prev_id) = $sth->fetchrow_array();
  $sth->finish();

  # Идентификатор следующего пользователя
  $sth = database->prepare("SELECT next.id
                            FROM user AS next
                            JOIN user ON next.email > user.email
                              AND user.id = ?
                            ORDER BY next.email
                            LIMIT 1");
  $sth->execute($id);
  my ($next_id) = $sth->fetchrow_array();
  $sth->finish();

  # Подписки на получение чужой почты
  $sth = database->prepare("SELECT subscription.id AS id,
                                   subscription.email AS email,
                                   IFNULL(source.id, '') AS user_id,
                                   IFNULL(source.surname, '') AS surname,
                                   IFNULL(source.name, '') AS name,
                                   IFNULL(source.patronym, '') AS patronym
                            FROM subscription
                            JOIN user ON user.email = subscription.recipient AND user.id = ?
                            LEFT JOIN user AS source ON source.email = subscription.email
                            WHERE subscription.direction = ?");
  # incoming_subscriptions - список подписок на входящие
  $sth->execute($id, "I");
  my $incoming_subscriptions = $sth->fetchall_arrayref({});

  # outgoing_subscriptions - список подписок на исходящие
  $sth->execute($id, "O");
  my $outgoing_subscriptions = $sth->fetchall_arrayref({});
  $sth->finish();

  # Подписки других на получение почты этого пользователя
  $sth = database->prepare("SELECT subscription.id AS id,
                                   subscription.recipient AS email,
                                   recipient.id AS user_id,
                                   recipient.surname AS surname,
                                   recipient.name AS name,
                                   recipient.patronym AS patronym
                            FROM subscription
                            JOIN user AS recipient ON recipient.email = subscription.recipient
                            JOIN user ON user.email = subscription.email AND user.id = ?
                            WHERE subscription.direction = ?");
  # incoming_recipients - список получателей копий входящих
  $sth->execute($id, "I");
  my $incoming_recipients = $sth->fetchall_arrayref({});

  # outgoing_recipients - список получателей копий исходящих
  $sth->execute($id, "O");
  my $outgoing_recipients = $sth->fetchall_arrayref({});
  $sth->finish();

  return {%{$user},
          prev_id => $prev_id,
          next_id => $next_id,
          incoming_subscriptions => $incoming_subscriptions,
          outgoing_subscriptions => $outgoing_subscriptions,
          incoming_recipients => $incoming_recipients,
          outgoing_recipients => $outgoing_recipients};
}

# Возвращает данные для шаблона страницы с пользователями
sub users_page($$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;

  # Узнаём общее количество строк в таблице
  my $sth = database->prepare("SELECT COUNT(*)
                               FROM user");
  $sth->execute();
  my ($total) = $sth->fetchrow_array();
  $sth->finish();

  my $navigation = navigation($all, $base, $num, $total);

  # Извлекаем из таблицы необходимые строки
  my $query = "SELECT id,
                      IF(active = 'Y', 1, 0) AS active,
                      email,
                      surname,
                      name,
                      patronym,
                      department,
                      position,
                      phones,
                      ad_login,
                      IFNULL(lasttime, '') AS lasttime,
                      IFNULL(lastip, '') AS lastip,
                      IFNULL(bytes, 0) AS bytes,
                      max_bytes,
                      IFNULL(messages, 0) AS messages,
                      max_messages,
                      smtp_acl
               FROM user
               ORDER BY email";
  if ($navigation->{all})
  {
    $sth = database->prepare($query);
    $sth->execute();
  }
  else
  {
    $sth = database->prepare("$query LIMIT ?, ?");
    $sth->execute($navigation->{base}, $navigation->{num});
  }
  my $table = $sth->fetchall_arrayref({});
  $sth->finish();

  # Дополнительные поля для более удобного восприятия человеком
  foreach my $row (@{$table})
  {
    # Если нет квоты объёма, выводим используемый объём
    if ($row->{max_bytes} == 0)
    {
      $row->{hr_bytes} = bytes2hr($row->{bytes});
    }
    # Если есть квота объёма, выводим процент использования квоты
    else
    {
      $row->{hr_bytes} = round($row->{bytes} * 100 / $row->{max_bytes}) . '%';
    }
    $row->{bytes} = bytes2hr($row->{bytes});
    $row->{max_bytes} = bytes2hr($row->{max_bytes});

    # Если нет квоты количества сообщений, выводим текущее количество сообщений
    if ($row->{max_messages} == 0)
    {
      $row->{hr_messages} = bytes2hr($row->{messages});
    }
    # Если есть квота количества сообщений, выводим процент использования квоты
    else
    {
      $row->{hr_messages} = round($row->{messages} * 100 / $row->{max_messages}) . '%';
    }
  }

  return {%{$navigation},
          users => $table,
          max_bytes_default => field_text_default(config->{postadmin}->{max_bytes}, ""),
          max_messages_default => field_number_default(config->{postadmin}->{max_messages}, 0)};
}

# Подписка пользователей на рассылку
sub users_subscribe($$$)
{
  my $email = field_text_default(shift, "");
  my $ids = join_ids(shift);
  my $incoming = field_text_default(shift, "");

  my $sth = database()->prepare("SELECT email
                                 FROM user
                                 WHERE id IN ($ids)");
  $sth->execute();
  my $recipients = $sth->fetchall_arrayref();
  $sth->finish();

  return "Некого подписывать!\n" unless defined $recipients;

  my $errors = "";
  foreach my $recipient (@{$recipients})
  {
    $errors .= subscribe($email, $recipient->[0], $incoming);
  }

  return $errors;
}

# Редактирование пользователя
sub user_edit($$$$$$$$$$$$$$)
{
  my $id = field_text_default(shift, "");
  my $active = shift;
  my $password = field_text_default(shift, "");
  my $confirm = field_text_default(shift, "");
  my $surname = field_text_default(shift, "");
  my $name = field_text_default(shift, "");
  my $patronym = field_text_default(shift, "");
  my $department = field_text_default(shift, "");
  my $position = field_text_default(shift, "");
  my $phones = field_text_default(shift, "");
  my $ad_login = field_text_default(shift, "");
  my $max_bytes = field_bytes_default(shift, config->{postadmin}->{max_bytes});
  my $max_messages = field_number_default(shift, config->{postadmin}->{max_messages});
  my $smtp_acl = field_text_default(shift, config->{postadmin}->{smtp_acl});

  $id = int($id);

  $max_bytes = hr2bytes($max_bytes);
  $max_messages = int($max_messages);

  # Если пароль не равен подтверждению, сообщаем об этом
  if ($password ne $confirm)
  {
    return "Пароль и подтверждение отличаются!";
  }

  # Если пароль отличается от пустого
  if ($password ne "")
  {
    my $error = validate_password($password);
    return $error if $error;

    $password = database()->quote($password);

    $password = "password = ENCRYPT($password),";
  }

  # Проверка уникальности пользователя по ФИО
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM user
                                 WHERE surname = ?
                                   AND name = ?
                                   AND patronym = ?
                                   AND id <> ?");
  $sth->execute($surname, $name, $patronym, $id);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  if ($num)
  {
    return "Пользователь $surname $name $patronym уже существует!";
  }

  # Вносим обновления в базу
  $sth = database()->prepare("UPDATE user
                              SET $password
                                  active = ?,
                                  surname = ?,
                                  name = ?,
                                  patronym = ?,
                                  department = ?,
                                  position = ?,
                                  phones = ?,
                                  ad_login = ?,
                                  max_bytes = ?,
                                  max_messages = ?,
                                  smtp_acl = ?
                              WHERE id = ?");
  $sth->execute($active ? "Y" : "N", $surname, $name, $patronym,
                $department, $position, $phones, $ad_login,
                $max_bytes, $max_messages, $smtp_acl, $id);
  $sth->finish();

  # Всё хорошо
  return "";
}

# Редактирование подписок пользователя
sub user_subscriptions_edit($$$$$$)
{
  my $unsubscribe_ids = join_ids(shift);
  my $email = field_text_default(shift, "");
  my $incoming_subscription = field_text_default(shift, "");
  my $outgoing_subscription = field_text_default(shift, "");
  my $incoming_recipient = field_text_default(shift, "");
  my $outgoing_recipient = field_text_default(shift, "");

  my $errors = "";

  # Удаляем подписки
  $errors = unsubscribe($unsubscribe_ids) if $unsubscribe_ids;

  # Добавляем подписки
  if ($email)
  {
    $errors .= subscribe($incoming_subscription, $email, 1) if $incoming_subscription;
    $errors .= subscribe($outgoing_subscription, $email, 0) if $outgoing_subscription;
    $errors .= subscribe($email, $incoming_recipient, 1) if $incoming_recipient;
    $errors .= subscribe($email, $outgoing_recipient, 0) if $outgoing_recipient;
  }

  return $errors;
}

# Функция транслитерации по корпоративному стандарту СГ УралСиб
sub ru2en($)
{
  my $s = shift;

  my %t = ('ия$' => 'ia',
           'ия ' => 'ia ',
           'ъб' => 'b',
           'ъв' => 'v',
           'ъг' => 'g',
           'ъд' => 'd',
           'ъж' => 'zh',
           'ъз' => 'z',
           'ък' => 'k',
           'ъл' => 'l',
           'ъм' => 'm',
           'ън' => 'n',
           'ъп' => 'p',
           'ър' => 'r',
           'ъс' => 's',
           'ът' => 't',
           'ъф' => 'f',
           'ъх' => 'kh',
           'ъц' => 'ts',
           'ъч' => 'ch',
           'ъш' => 'sh',
           'ъщ' => 'sch',
           'ьб' => 'b',
           'ьв' => 'v',
           'ьг' => 'g',
           'ьд' => 'd',
           'ьж' => 'zh',
           'ьз' => 'z',
           'ьк' => 'k',
           'ьл' => 'l',
           'ьм' => 'm',
           'ьн' => 'n',
           'ьп' => 'p',
           'ьр' => 'r',
           'ьс' => 's',
           'ьт' => 't',
           'ьф' => 'f',
           'ьх' => 'kh',
           'ьц' => 'ts',
           'ьч' => 'ch',
           'ьш' => 'sh',
           'ьщ' => 'sch',
           'ъа' => 'ia',
           'ъе' => 'ie',
           'ъё' => 'ie',
           'ъи' => 'ii',
           'ъй' => 'ij',
           'ъо' => 'io',
           'ъу' => 'iu',
           'ъы' => 'iy',
           'ъэ' => 'ie',
           'ъю' => 'iyu',
           'ъя' => 'iya',
           'ия' => 'ya',
           'ий' => 'y',
           'ый' => 'y',
           'ая' => 'aya',
           'яя' => 'aya',
           'ья' => 'ya',
           'ьи' => 'ii',
           'ью' => 'ju',
           'ье' => 'ie',
           'ие' => 'ie',
           'ь' => '',
           'Ия' => 'Ya',
           'Ий' => 'Y',
           'Ый' => 'Y',
           'Ая' => 'Aya',
           'Яя' => 'Aya',
           'Ие' => 'Ie',
           'а' => 'a',
           'б' => 'b',
           'в' => 'v',
           'г' => 'g',
           'д' => 'd',
           'е' => 'e',
           'ё' => 'e',
           'ж' => 'zh',
           'з' => 'z',
           'и' => 'i',
           'й' => 'j',
           'к' => 'k',
           'л' => 'l',
           'м' => 'm',
           'н' => 'n',
           'о' => 'o',
           'п' => 'p',
           'р' => 'r',
           'с' => 's',
           'т' => 't',
           'у' => 'u',
           'ф' => 'f',
           'х' => 'kh',
           'ц' => 'ts',
           'ч' => 'ch',
           'ш' => 'sh',
           'щ' => 'sch',
           'ы' => 'y',
           'э' => 'e',
           'ю' => 'yu',
           'я' => 'ya',
           'А' => 'A',
           'Б' => 'B',
           'В' => 'V',
           'Г' => 'G',
           'Д' => 'D',
           'Е' => 'E',
           'Ё' => 'E',
           'Ж' => 'Zh',
           'З' => 'Z',
           'И' => 'I',
           'Й' => 'J',
           'К' => 'K',
           'Л' => 'L',
           'М' => 'M',
           'Н' => 'N',
           'О' => 'O',
           'П' => 'P',
           'Р' => 'R',
           'С' => 'S',
           'Т' => 'T',
           'У' => 'U',
           'Ф' => 'F',
           'Х' => 'Kh',
           'Ц' => 'Ts',
           'Ч' => 'Ch',
           'Ш' => 'Sh',
           'Щ' => 'Sch',
           'Ы' => 'Y',
           'Э' => 'E',
           'Ю' => 'Yu',
           'Я' => 'Ya');
  while (my ($k, $v) = each %t)
  {
    $s =~ s/$k/$v/g;
  }

  return $s;
}

# Возвращает логин для указанных фамилии, имени и отчества
sub get_logins($$$)
{
  my $surname = field_text_default(shift, "");
  my $name = field_text_default(shift, "");
  my $patronym = field_text_default(shift, "");

  $surname = ru2en($surname);

  $name = ru2en($name);

  $patronym = ru2en($patronym);

  # Если нет фамилии, то нет и логинов
  return [] unless $surname;

  # Максимальная длина логина
  my $maxlength = field_text_default(config->{postadmin}->{login_max_length}, login_max_length);

  my @logins = ();
  for(my $i = 0; $i < length($name); $i++)
  {
    # Первая буква имени
    my $login = substr($name, 0, 1);
    # Первая буква отчества
    if ($i == 0)
    {
      $login .= substr($patronym, 0, 1) if $patronym ne "";
    }
    # Или следующая буква имени
    else
    {
      $login .= substr($name, $i, 1);
    }

    # Выясняем, сколько букв фамилии можно использовать
    my $len = $maxlength - length($login);
    # Если от фамилии нельзя использовать ни одной буквы, то логинов больше нет
    last if $len == 0;

    # Генерируем ещё один логин
    $login = substr($surname, 0, $len) . $login;

    # Если такой логин уже есть, затираем его
    foreach my $l (@logins)
    {
      if (lc($l) eq lc($login))
      {
        $login = "";
        last;
      }
    }

    # Добавляем новый не пустой логин в массив
    push(@logins, $login) if $login ne "";
  }
  # Если имени нет, то и отчество не используем, генерируем логин только из одной фамилии
  if ($name eq "")
  {
    my $login = substr($surname, 0, $maxlength);
    push(@logins, $login);
  }

  return \@logins;
}

# Возвращает свободный логин для этого домена и ФИО
sub get_free_login($$$$)
{
  my $domain = field_text_default(shift, config->{postadmin}->{domain});
  my $surname = field_text_default(shift, "");
  my $name = field_text_default(shift, "");
  my $patronym = field_text_default(shift, "");

  # Не проверяем свободность логина, если не указан домен или фамилия
  return "" unless $domain;
  return "" unless $surname;

  # Получаем список логинов
  my $logins = get_logins($surname, $name, $patronym);

  foreach my $login (@{$logins})
  {
    # Пробуем другой логин, если этот занят или не правильный
    next if validate_new_email("$login\@$domain");

    # Нашли незанятый логин
    return $login;
  }
  return "";
}

# Возвращает доменный логин для этого логина и домена
sub get_ad_login($;$)
{
  my $login = field_text_default(shift, "");
  my $domain = field_text_default(shift, config->{postadmin}->{ad_domain});

  return "$domain\\$login" if ($login && $domain);
  return "";
}

# Возвращает случайный пароль
sub get_password()
{
  my $password = "";
  my $len = field_text_default(config->{postadmin}->{password_min_length}, password_min_length);
  my $chars = field_text_default(config->{postadmin}->{password_chars}, password_chars);

  for(my $i = 0; $i < $len; $i++)
  {
    $password .= substr($chars, rand(length($chars)), 1);
  }
  return $password;
}

# Создаёт нового пользователя
sub user_new($$$$$$$$$$$$$$)
{
  my $active = field_text_default(shift, "");
  my $surname = field_text_default(shift, "");
  my $name = field_text_default(shift, "");
  my $patronym = field_text_default(shift, "");
  my $department = field_text_default(shift, "");
  my $position = field_text_default(shift, "");
  my $phones = field_text_default(shift, "");
  my $domain = field_text_default(shift, config->{postadmin}->{domain});
  my $email = field_text_default(shift, "");
  my $ad_login = field_text_default(shift, get_ad_login($email));
  my $password = field_text_default(shift, get_password());
  my $max_bytes = field_bytes_default(shift, config->{postadmin}->{max_bytes});
  my $max_messages = field_number_default(shift, config->{postadmin}->{max_messages});
  my $smtp_acl = field_text_default(shift, config->{postadmin}->{smtp_acl});

  $max_messages = int($max_messages);

  $active = $active ? "Y" : "N";

  my $error = validate_new_email("$email\@$domain");
  return $error if $error;

  $error = validate_password($password);
  return $error if $error;

  # Проверка уникальности пользователя по ФИО
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM user
                                 WHERE surname = ?
                                   AND name = ?
                                   AND patronym = ?");
  $sth->execute($surname, $name, $patronym);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  if ($num)
  {
    return "Пользователь $surname $name $patronym уже существует!";
  }

  # Создаём пользователя
  $sth = database()->prepare("INSERT INTO user
                              SET email = ?,
                                  active = ?,
                                  password = ENCRYPT(?),
                                  surname = ?,
                                  name = ?,
                                  patronym = ?,
                                  department = ?,
                                  position = ?,
                                  phones = ?,
                                  ad_login = ?,
                                  bytes = 0,
                                  max_bytes = ?,
                                  messages = 0,
                                  max_messages = ?,
                                  smtp_acl = ?");

  $sth->execute("$email\@$domain", $active, $password, $surname, $name, $patronym,
                $department, $position, $phones, $ad_login,
                $max_bytes, $max_messages, $smtp_acl);
  $sth->finish();

  return "";
}

# Возвращает список локальных доменов с отменным указанным доменом
sub domain_select($)
{
  my $selected_domain = shift;

  my @domains = ();

  # Если настройка локальных транспортов определена и указан хотя-бы один транспорт
  if ((defined config->{postadmin}->{local_transports}) &&
      (scalar @{config->{postadmin}->{local_transports}}))
  {
    # Запрос для извлечения доменов для указанного транспорта
    my $sth = database()->prepare("SELECT domain
                                   FROM domain
                                   WHERE transport = ?");

    # Перебираем транспорты, указанные как локальные в конфиге
    foreach my $transport (@{config->{postadmin}->{local_transports}})
    {
      # Домены для этого транспорта
      $sth->execute($transport);
 
      # Каждый домен добавляем в список
      while (my ($domain) = $sth->fetchrow_array())
      {
        push(@domains, {domain => $domain,
                        selected => ($selected_domain eq $domain)});
      }
    }
    $sth->finish();
  }

  return \@domains;
}

# Возвращает данные для отрисовки страницы заведения нового пользователя
sub user_new_page($$$$$$$$$$$$$$)
{
  my $active = field_text_default(shift, "");
  my $surname = field_text_default(shift, "");
  my $name = field_text_default(shift, "");
  my $patronym = field_text_default(shift, "");
  my $department = field_text_default(shift, "");
  my $position = field_text_default(shift, "");
  my $phones = field_text_default(shift, "");
  my $domain = field_text_default(shift, config->{postadmin}->{domain});
  my $email = field_text_default(shift, "");
  my $ad_login = field_text_default(shift, get_ad_login($email));
  my $password = field_text_default(shift, get_password());
  my $max_bytes = field_bytes_default(shift, config->{postadmin}->{max_bytes});
  my $max_messages = field_number_default(shift, config->{postadmin}->{max_messages});
  my $smtp_acl = field_text_default(shift, config->{postadmin}->{smtp_acl});

  $max_messages = int($max_messages);

  # Извлекаем домены для выбора адреса почтового ящика
  my $domains = domain_select($domain);

  return {active => $active,
          surname => $surname,
          name => $name,
          patronym => $patronym,
          department => $department,
          position => $position,
          phones => $phones,
          domain => $domain,
          email => $email,
          ad_login => $ad_login,
          password => $password,
          max_bytes => bytes2hr($max_bytes),
          max_messages => $max_messages,
          smtp_acl => $smtp_acl,
          domains => $domains};
}

1;
