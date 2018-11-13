#!/usr/bin/perl -w

use strict;
use DBI;

# Каталог, где хранится почта в подкаталогах domain/user
my $mail = '/var/mail/virtual/';

# Настройки подключения к БД
my $host = '127.0.0.1';
my $db = 'mail';
my $user = 'mail';
my $password = 'mail_password';

# Принимает: подключение к БД, адрес электронной почты
# Возвращает список получателей указанного адреса
sub get_recipients($$)
{
  my ($dbh, $email) = @_;

  $email = $dbh->quote($email);
  my $sth = $dbh->prepare("SELECT subscription.recipient
                           FROM subscription
                           JOIN domain ON domain.domain=SUBSTRING_INDEX(subscription.recipient, '\@', -1)
                             AND domain.transport IN ('dovecot:', 'virtual:')
                           WHERE subscription.direction='I'
                             AND subscription.email=$email");
  $sth->execute();

  my @recipients = ();
  while (my @row = $sth->fetchrow_array())
  {
    push(@recipients, $row[0]);
  }
  $sth->finish;

  return @recipients;
}

# Копирование новых писем в ящики подписанных получателей
# Получает: подключение к БД, адрес ящика-источника, список ящиков-получателей
sub copy($$$)
{
  my ($dbh, $email, $recipients) = @_;

  my @recipients = @{$recipients};

  my ($login, $domain) = split('@', lc($email));

  foreach my $rcpt (@recipients)
  {
    my ($rlogin, $rdomain) = split('@', lc($rcpt));

    # Перемещаем почту пользователя в ящик получателя
    `rsync -avv $mail$domain/$login/new/* $mail$rdomain/$rlogin/new/`;

    print "  - copy from $domain/$login/new/ to $rdomain/$rlogin/new/\n";
  }
}

# Подключаемся к БД
my $dbh = DBI->connect("dbi:mysql:dbname=$db:$host", $user, $password);

# Получаем список доменов
my @domains = split('\n', `ls $mail`);

foreach my $domain (@domains)
{
  # Получаем список логинов для этого домена
  my @logins = split('\n', `ls $mail/$domain`);

  foreach my $login (@logins)
  {
    # Проверяем, существует ли в БД этот ящик
    my $email = $dbh->quote($login . "@" . $domain);
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM user WHERE email=$email");
    $sth->execute();
    my @row = $sth->fetchrow_array();
    my $found = $row[0];
    $sth->finish;

    # Если ящик в БД не существует, обрабатываем его
    if (!$found)
    {
      print "$domain/$login is unused\n";

      # Узнаем список получателей этого ящика
      my @list = get_recipients($dbh, $login . '@' . $domain);

      # Копируем письма из неиспользуемого ящика их получателям
      copy($dbh, $login . '@' . $domain, \@list);

      # Удаляем неиспользуемый ящик
      `rm -R $mail$domain/$login`;
    }
  }
}

# Отключаемся от БД
$dbh->disconnect();

