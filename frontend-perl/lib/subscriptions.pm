package subscriptions;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(subscribe
                 unsubscribe
                 subscriptions_page);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Email::Valid;

use utils;
use domains;

# Создание переылки - подписка на список рассылки или создание псевдонима
sub subscribe($$$)
{
  my $email = field_text_default(shift, "");
  my $recipient = field_text_default(shift, "");
  my $incoming = field_number_default(shift, 1);

  # Проверка адреса-источника
  my $error = validate_email($email);
  return $error if $error;

  # Если подписка на входящие, тогда нужно проверить,
  # что домен адреса пересылки локальный
  if ($incoming)
  {
    # Делим адрес на ящик и домен
    my ($box, $domain) = split('\@', $email);

    # Если домен не локальный, сообщаем об этом
    my $error = validate_local_domain($domain);
    return $error if $error;
  }
  # Если подписка на исходящие, тогда нужно проверить,
  # что существует такой ящик
  else
  {
    my $sth = database()->prepare("SELECT COUNT(*)
                                   FROM user
                                   WHERE email = ?");
    $sth->execute($email);
    my ($num) = $sth->fetchrow_array();
    $sth->finish();

    if ($num == 0)
    {
      return "Источник исходящей почты $email не существует!\n";
    }
  }

  # Проверка адреса-получателя
  $error = validate_email($recipient);
  return $error if $error;

  # Проверяем, что ящик получателя существует
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM user
                                 WHERE email = ?");
  $sth->execute($recipient);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  if ($num == 0)
  {
    return "Получатель $recipient не существует!\n";
  }

  # Проверка, не приведёт ли создание подписки к зацикливанию цепочки подписок
  if ($incoming)
  {
    my $error = validate_subscription_on_loop($email, $recipient);
    return $error if $error;
  }

  # Добавляем подписку
  $sth = database()->prepare("INSERT IGNORE INTO subscription
                              SET email = ?,
                                  recipient = ?,
                                  direction = ?");

  $sth->execute($email, $recipient, $incoming ? "I" : "O");
  $sth->finish();

  # Всё хорошо
  return "";
}

# Удаление пересылок по их идентификаторам
sub unsubscribe($)
{
  my $ids = join_ids(shift);
  return "Некого отписывать!\n" unless $ids;

  # Отписываем всех указанных
  database()->do("DELETE FROM subscription
                  WHERE id IN ($ids)");

  # Всё хорошо
  return "";
}

# Возвращает данные для шаблона страницы с подписками
sub subscriptions_page($$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;

  # Узнаём общее количество строк в таблице
  my $sth = database->prepare("SELECT COUNT(*)
                               FROM subscription");
  $sth->execute();
  my ($total) = $sth->fetchrow_array();
  $sth->finish();

  my $navigation = navigation($all, $base, $num, $total);

  # Извлекаем из таблицы необходимые строки
  my $query = "SELECT subscription.id AS id,
                      subscription.email AS email,
                      subscription.recipient AS recipient,
                      IF(subscription.direction = 'I', 1, 0) AS incoming,
                      forwarder.id AS forwarder_id,
                      IF(forwarder.active = 'Y', 1, 0) AS active,
                      user.id AS recipient_id,
                      user.surname AS surname,
                      user.name AS name,
                      user.patronym AS patronym
               FROM subscription
               JOIN user ON user.email = subscription.recipient
               LEFT JOIN user AS forwarder ON forwarder.email = subscription.email
               ORDER BY subscription.email";
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

  return {%{$navigation},
          subscriptions => $table};
}

1;
