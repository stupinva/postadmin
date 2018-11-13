<?

function db_connect($host, $db, $user, $password)
{
  $link = mysql_connect($host, $user, $password)
    or error('Не удалось подключиться к БД: ' . mysql_error());
  mysql_select_db($db, $link)
    or error('Не удалось выбрать указанную БД: ' . mysql_error());
  mysql_query("SET CHARACTER SET 'UTF8'", $link)
    or error('Не удалось выполнить запрос: ' . mysql_error());
  return $link;
}

function db_close($link)
{
  mysql_close($link);
}

# Эта функция написана на основе функции из следующей статьи:
# http://davidwalsh.name/backup-mysql-database-php
# Возвращает массив, содержащий запросы для импорта таблиц
function db_export($link, $tables = '*')
{
  # Формируем список таблиц
  if ($tables == '*')
  {
    $tables = array();
    $result = mysql_query('SHOW TABLES', $link)
      or error('Не удалось выполнить запрос: ' . mysql_error());
    while($row = mysql_fetch_row($result))
      $tables[] = $row[0];
    mysql_free_result($result);
  }
  else
    $tables = is_array($tables) ? $tables : explode(',', $tables);

  $result = array();
  foreach($tables as $table)
  {
    # Удалить таблицу
    $return[] = "DROP TABLE $table";

    # Создать схему таблицы
    $result = mysql_query("SHOW CREATE TABLE $table", $link)
      or error('Не удалось выполнить запрос: ' . mysql_error());
    $row = mysql_fetch_row($result);
    $return[] = $row[1];
    mysql_free_result($result);

    # Наполнить таблицу
    $result = mysql_query("SELECT * FROM $table", $link)
      or error('Не удалось выполнить запрос: ' . mysql_error());

    $rows = array();
    # Цикл по строкам таблицы
    while($row = mysql_fetch_row($result))
    {
      for($i = 0; $i < count($row); $i++)
        $row[$i] = "'" . mysql_escape_string($row[$i]) . "'";
      $rows[] = '(' . implode(',', $row) . ')';
    }
    $return[] = "INSERT INTO $table VALUES " . implode(',', $rows);
    mysql_free_result($result);
  }
  return $return;
}

function db_update($link, $query)
{
  $queries = is_array($query) ? $query : array($query);

  $num = 0;
  foreach($queries as $q)
  {
    mysql_query($q, $link)
      or error("Не удалось выполнить запрос ($q): " . mysql_error());

    $num += mysql_affected_rows($link);
  }
  return $num;
}

function db_select($link, $query)
{
  $result = mysql_query($query, $link)
    or error('Не удалось выполнить запрос: ' . mysql_error());
  $rows = array();
  while($row = mysql_fetch_row($result))
    $rows[] = $row;
  mysql_free_result($result);
  return $rows;
}

function db_select_value($link, $query)
{
  $result = mysql_query($query, $link)
    or error('Не удалось выполнить запрос: ' . mysql_error());
  $total = mysql_num_rows($result);
  if ($total != 1)
    error("Запрос $query вернул $total значений вместо одного!");
  $row = mysql_fetch_row($result);
  mysql_free_result($result);
  return $row[0];
}

# Отбор строк из таблицы, где каждая колонка
# является элементом ассоциативного массива
function db_select_keyvals($link, $query)
{
  $result = mysql_query($query, $link)
    or error('Не удалось выполнить запрос: ' . mysql_error());
  $rows = array();
  while($row = mysql_fetch_assoc($result))
    $rows[] = $row;
  mysql_free_result($result);
  return $rows;
}

# Отбор строк для отображения на одной странице
function db_rows($link, $all, $base, $display, $query_total, $query_rows)
{
  global $default_display;

  $base = floor($base);
  $display = floor($display);

  $total = db_select_value($link, $query_total);
  if ($all)
  {
    $base = 0;
    $display = $total;
  }

  if ($display <= 0)
    $display = $default_display;

  if (($base < 0) || ($total == 0))
    $base = 0;
  else if ($base + $display >= $total)
  {
    $last = $total % $display;
    if ($last == 0)
      $last = $display;
    $base = $total - $last;
  }

  $rows = db_select_keyvals($link, "$query_rows LIMIT $base, $display");

  return array($rows, $base, $display, $total);
}

# Функция устарела и от неё необходимо избавиться
function db_select_num_rows($link, $query)
{
  $result = mysql_query($query, $link)
    or error('Не удалось выполнить запрос: ' . mysql_error());
  $total = mysql_num_rows($result);
  mysql_free_result($result);
  return $total;
}

?>
