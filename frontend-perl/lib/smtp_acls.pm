package smtp_acls;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(smtp_acl_page
                 smtp_acls_page
                 smtp_acl_new
                 smtp_acl_edit
                 smtp_acls_remove);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;

use utils;
use validation;

# Создание нового правила доступа
sub smtp_acl_new($$$)
{
  my $acl = field_text_default(shift, "");
  my $address = field_text_default(shift, "");
  my $description = field_text_default(shift, "");

  # Проверка, что адрес является доменом или ящиком электронной почты
  my $error = validate_address($address);
  return $error if $error;

  # Проверка, что такое правило ещё не существует
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM smtp_acl
                                 WHERE acl = ?
                                   AND address = ?");
  $sth->execute($acl, $address);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  return "Адрес $address уже существует в списке $acl!" if $num;

  # Добавляем новое правило
  $sth = database()->prepare("INSERT INTO smtp_acl
                              SET acl = ?,
                                  address = ?,
                                  description = ?");
  $sth->execute($acl, $address, $description);
  $sth->finish();

  # Всё в порядке
  return "";
}

# Изменение адреса получателия или его описания
sub smtp_acl_edit($$$$)
{
  my $id = field_text_default(shift, "");
  my $acl = field_text_default(shift, "");
  my $address = field_text_default(shift, "");
  my $description = field_text_default(shift, "");

  $id = int($id);

  # Проверка, что адрес является доменом или ящиком электронной почты
  my $error = validate_address($address);
  return $error if $error;

  # Проверка, что такое правило правило ещё не существует
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM smtp_acl
                                 WHERE acl = ?
                                   AND address = ?
                                   AND id <> ?");
  $sth->execute($acl, $address, $id);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  return "Адрес $address уже существует в списке $acl!" if $num;

  # Редактируем правило
  $sth = database()->prepare("UPDATE smtp_acl
                              SET acl = ?,
                                  address = ?,
                                  description = ?
                              WHERE id = ?");
  $sth->execute($acl, $address, $description, $id);
  $sth->finish();

  # Всё в порядке
  return ""; 
}

# Удаление сразу нескольких правил
sub smtp_acls_remove($)
{
  my $ids = join_ids(shift);

  return "" unless $ids;

  database()->do("DELETE FROM smtp_acl
                  WHERE id IN ($ids)");
  return "";
}

# Возвращает данные для шаблона страницы с правилом доступа
sub smtp_acl_page($)
{
  my $id = shift;

  # Информация о редактируемом правиле доступа
  my $sth = database->prepare("SELECT id,
                                      acl,
                                      address,
                                      description
                               FROM smtp_acl
                               WHERE id = ?");
  $sth->execute($id);
  my $smtp_acl = $sth->fetchrow_hashref();
  $sth->finish();

  # Если объекта нет, возвращаем пустую ссылку
  return undef unless defined $smtp_acl;

  # Идентификатор предыдущего правила доступа
  $sth = database->prepare("SELECT prev.id
                            FROM smtp_acl AS prev
                            JOIN smtp_acl ON CONCAT(prev.acl, prev.address) < CONCAT(smtp_acl.acl, smtp_acl.address)
                              AND smtp_acl.id = ?
                            ORDER BY prev.acl DESC, prev.address DESC
                            LIMIT 1");
  $sth->execute($id);
  my ($prev_id) = $sth->fetchrow_array();
  $sth->finish();

  # Идентификатор следующего правила доступа
  $sth = database->prepare("SELECT next.id
                            FROM smtp_acl AS next
                            JOIN smtp_acl ON CONCAT(next.acl, next.address) > CONCAT(smtp_acl.acl, smtp_acl.address)
                              AND smtp_acl.id = ?
                            ORDER BY next.acl, next.address
                            LIMIT 1");
  $sth->execute($id);
  my ($next_id) = $sth->fetchrow_array();
  $sth->finish();

  return {%{$smtp_acl},
          prev_id => $prev_id,
          next_id => $next_id};
}

# Возвращает данные для шаблона страницы с правами доступа
sub smtp_acls_page($$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;

  # Узнаём общее количество строк в таблице
  my $sth = database->prepare("SELECT COUNT(*)
                               FROM smtp_acl");
  $sth->execute();
  my ($total) = $sth->fetchrow_array();
  $sth->finish();

  my $navigation = navigation($all, $base, $num, $total);

  # Извлекаем из таблицы необходимые строки
  my $query = "SELECT id,
                      acl,
                      address,
                      description
               FROM smtp_acl
               ORDER BY acl, address";
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
          smtp_acls => $table,
          smtp_acl_default => field_text_default(config->{postadmin}->{smtp_acl}, "")};
}

1;
