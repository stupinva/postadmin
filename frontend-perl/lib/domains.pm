package domains;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(domain_new
                 domain_edit
                 domains_remove
                 domains_change_transport
                 domains_page
                 domain_page);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;

use utils;
use validation;

# Заведение нового домена
sub domain_new($$)
{
  my $domain = field_text_default(shift, "");
  my $transport = field_text_default(shift, "");

  # Если строка с доменом не похожа на домен, сообщаем об этом, прекращая работу
  my $error = validate_domain($domain);
  return $error if $error;

  # Если строка с транспортом не похожа на транспорт, сообщаем об этом, прекращая работу
  $error = validate_transport($transport);
  return $error if $error;

  # Проверяем, существует ли уже такой домен
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM domain
                                 WHERE domain = ?");
  $sth->execute($domain);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  # Домен существует, сообщаяем об этом, прекращая работу
  if ($num > 0)
  {
    return "Домен $domain уже существует!\n";
  }

  # Добавляем домен
  $sth = database()->prepare("INSERT INTO domain
                              SET domain = ?,
                                  transport = ?");
  $sth->execute($domain, $transport);
  $sth->finish();

  # Ошибки не было
  return "";
}

# Изменение имени домена или его транспорта
sub domain_edit($$$)
{
  my $id = field_number_default(shift, "");
  my $domain = field_text_default(shift, "");
  my $transport = field_text_default(shift, "");

  # Если строка с доменом не похожа на домен, сообщаем об этом, прекращая работу
  my $error = validate_domain($domain);
  return $error if $error;

  # Если строка с транспортом не похожа на транспорт, сообщаем об этом, прекращая работу
  $error = validate_transport($transport);
  return $error if $error;

  # Проверяем, существует ли уже такой домен
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM domain
                                 WHERE domain = ?
                                   AND id <> ?");
  $sth->execute($domain, $id);
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  # Домен существует, сообщаяем об этом, прекращая работу
  if ($num > 0)
  {
    return "Домен $domain уже существует!\n";
  }

  # Обновляем домен
  $sth = database()->prepare("UPDATE domain
                              SET domain = ?,
                                  transport = ?
                              WHERE id = ?");
  $sth->execute($domain, $transport, $id);
  $sth->finish();

  # Ошибки не было
  return "";
}

# Удаление сразу нескольких доменов
sub domains_remove($)
{
  my $ids = join_ids(shift);

  return "Нечего удалять!\n" unless defined $ids;

  # Проверяем, что в удаляемых доменах нет пользователей
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM domain
                                 JOIN user ON SUBSTRING_INDEX(user.email, '\@', -1) = domain.domain
                                 WHERE domain.id IN ($ids)");
  $sth->execute();
  my ($num) = $sth->fetchrow_array();
  $sth->finish();

  # В домене есть пользователи, сообщаем об этом и прекращаем работу
  if ($num > 0)
  {
    return "Нельзя удалить домены, к которым привязаны почтовые ящики!\n";
  }

  # Проверяем, что в удаляемых доменах нет подписок
  # Проверяются только входящие подписки, поскольку подписки на исходящие не существуют без пользователя,
  # а мы уже проверили, что пользователей в этом домене нет
  $sth = database()->prepare("SELECT COUNT(*)
                              FROM domain
                              JOIN subscription ON SUBSTRING_INDEX(subscription.email, '\@', -1) = domain.domain
                                AND subscription.direction = 'I'
                              WHERE domain.id IN ($ids)");
  $sth->execute();
  ($num) = $sth->fetchrow_array();
  $sth->finish();

  # В домене есть подписки, сообщаем об этом и прекращаем работу
  if ($num > 0)
  {
    return "Нельзя удалить домены, к которым привязаны подписки!\n";
  }
  
  # Удаляем домены
  database()->do("DELETE FROM domain WHERE id IN ($ids)");

  # Ошибки не было
  return "";
}

# Замена транспорта для указанных доменов
sub domains_change_transport($$)
{
  my $ids = join_ids(shift);
  my $transport = field_text_default(shift, "");

  return "Нечего обновлять!\n" unless $ids;

  # Если строка с транспортом не похожа на транспорт, сообщаем об этом, прекращая работу
  my $error = validate_transport($transport);
  return $error if $error;

  my $sth = database()->prepare("UPDATE domain
                                 SET transport = ?
                                 WHERE id IN ($ids)");
  $sth->execute($transport);
  $sth->finish();

  return "";
}

# Возвращает данные для шаблона страницы с доменами
sub domains_page($$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;

  # Узнаём общее количество строк в таблице
  my $sth = database()->prepare("SELECT COUNT(*)
                                 FROM domain");
  $sth->execute();
  my ($total) = $sth->fetchrow_array();
  $sth->finish();

  my $navigation = navigation($all, $base, $num, $total);

  # Извлекаем из таблицы необходимые строки
  my $query = "SELECT id,
                      domain,
                      transport
               FROM domain
               ORDER BY domain";
  if ($navigation->{all})
  {
    $sth = database()->prepare($query);
    $sth->execute();
  }
  else
  {
    $sth = database()->prepare("$query LIMIT ?, ?");
    $sth->execute($navigation->{base}, $navigation->{num});
  }
  my $table = $sth->fetchall_arrayref({});
  $sth->finish();

  return {%{$navigation},
          domains => $table};
}

# Возвращает данные для шаблона страницы с доменом
sub domain_page($)
{
  my $id = shift;

  # Информация о редактируемом домене
  my $sth = database()->prepare("SELECT id,
                                        domain,
                                        transport
                                 FROM domain
                                 WHERE id = ?");
  $sth->execute($id);

  my $domain = $sth->fetchrow_hashref();
  $sth->finish();

  return undef unless defined $domain;

  # Идентификатор предыдущего домена
  $sth = database()->prepare("SELECT prev.id
                              FROM domain AS prev
                              JOIN domain ON prev.domain < domain.domain
                                AND domain.id = ?
                              ORDER BY prev.domain DESC
                              LIMIT 1");
  $sth->execute($id);
  my ($prev_id) = $sth->fetchrow_array();
  $sth->finish();

  # Идентификатор следующего домена
  $sth = database()->prepare("SELECT next.id
                              FROM domain AS next
                              JOIN domain ON next.domain > domain.domain
                                AND domain.id = ?
                              ORDER BY next.domain
                              LIMIT 1");
  $sth->execute($id);
  my ($next_id) = $sth->fetchrow_array();
  $sth->finish();

  return {%{$domain},
          prev_id => $prev_id,
          next_id => $next_id};
}

1;
