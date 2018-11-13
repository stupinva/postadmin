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

# Подключаемся к БД
my $dbh = DBI->connect("dbi:mysql:dbname=$db:$host", $user, $password);

# Пересчёт квот пользователя
# Вход: подключение к БД, адрес почтового ящика
sub user_quota($$)
{
  my ($dbh, $email) = @_;

  my ($login, $domain) = split('@', $email);

  # Получаем список всех файлов в каталоге Maildir пользователя
  my @files = split('\n', `find $mail/$domain/$login -type f`);

  my $messages = 0;
  my $bytes = 0;
  foreach my $file (@files)
  {
    # Выделяем по шаблону из имени файла его размер
    my $found = $file =~ s/^.*,S=(\d*)[,:].*$/$1/g;
    # Если размер найден, учитываем файл как письмо и учитываем его объём
    if ($found)
    {
      $messages++;
      $bytes += $file;
    }
  }

  # Вносим информацию о квотах в БД квот Dovecot
  $email = $dbh->quote($email);
  $dbh->do("UPDATE user SET bytes=$bytes, messages=$messages WHERE email=$email");

  # Показываем обработанную учётную запись
  print "$domain/$login - $messages $bytes\n";
}

# Получаем список доменов
my @domains = split('\n', `ls $mail`);

foreach my $domain (@domains)
{
  # Получаем список логинов для этого домена
  my @logins = split('\n', `ls $mail/$domain`);

  foreach my $login (@logins)
  {
    user_quota($dbh, $login . '@' . $domain);
  }
}

# Отключаемся от БД
$dbh->disconnect();

