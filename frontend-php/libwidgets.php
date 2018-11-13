<?

include_once "settings.php";
include_once "libdb.php";
include_once "libhtml.php";

# Виджет выбора количества отображаемых на одной странице строк таблицы
function widget_nums($tpls, $all, $base, $num, $total)
{
  global $num_default;
  global $nums;

  $html_nums = '';
  # Выбор количества строк для отображения на одной странице
  foreach($nums as $n)
  {
    # Не показываем выбор количества строк большее, чем общее количество строк
    if ($n >= $total)
      break;

    if (($n == $num) && !$all)
      $html_nums .= str_replace('%num%', $n, $tpls['num_cur']);
    else
      $html_nums .= template_fill($tpls['num'], array('%all%' => 0,
                                                      '%base%' => $base - $base % $n,
                                                      '%num%' => $n));
  }
  return $html_nums;
}

# Виджет выбора отображения всех строк таблицы
function widget_all($tpls, $all, $base, $num, $total)
{
  $html_all = '';
  # Последняя ссылка - показать все страницы
  if ($all || ($num >= $total))
    $html_all = $tpls['all_cur'];
  else
    $html_all = template_fill($tpls['all'], array('%all%' => 1,
                                                  '%base%' => $base,
                                                  '%num%' => $num));
  return $html_all;
}

# Виджет выбора номера страницы отображаемых строк таблицы
function widget_pages($tpls, $all, $base, $num, $total)
{
  # Формируем ссылки на номера страниц
  $html_pages = '';
  $page = 1;

  if ($all)
    $html_pages .= str_replace('%page%', $page, $tpls['page_cur']);
  else
    for($i = 0; $i < $total; $i += $num)
    {
      if (($base >= $i) && ($base < ($i + $num)))
        $html_pages .= str_replace('%page%', $page, $tpls['page_cur']);
      else
        $html_pages .= template_fill($tpls['page'], array('%all%' => 0,
                                                          '%base%' => $i,
                                                          '%num%' => $num,
                                                          '%page%' => $page));
      $page++;
    }
  return $html_pages;
}

# Ссылка на предыдущую страницу
function widget_prev($tpls, $all, $base, $num, $total)
{
  $prev = $base - $num;
  if ($prev < 0)
    $prev = 0;
  if ($all || ($prev == $base))
    $html_prev = $tpls['no_prev'];
  else
    $html_prev = template_fill($tpls['prev'], array('%all%' => $all,
                                                    '%base%' => $prev,
                                                    '%num%' => $num));
  return $html_prev;
}

# Ссылка на следующую страницу
function widget_next($tpls, $all, $base, $num, $total)
{
  $next = $base + $num;
  if ($next > $total)
    $next = $total - $total % $num;
  else if ($next == $total)
    $next = $total - $num;
  if ($all || ($next == $base))
    $html_next = $tpls['no_next'];
  else
    $html_next = template_fill($tpls['next'], array('%all%' => $all,
                                                    '%base%' => $next,
                                                    '%num%' => $num));
  return $html_next;
}

# Строки с данными
function widget_rows($tpls, $rows, $select_row_template = '')
{
  $html_rows = '';
  $odd = TRUE;
  foreach($rows as $row)
  {
    if (($select_row_template != '') && function_exists($select_row_template))
      $html_row = call_user_func($select_row_template, $tpls, $row, $odd);
    else
      $html_row = $odd ? $tpls['row_odd'] : $tpls['row_even'];

    foreach($row as $key => $value)
      $html_row = str_replace("%$key%", htmlspecialchars($value), $html_row);

    $html_rows .= $html_row;
    $odd = !$odd;
  }
  return $html_rows;    
}

function norm_base_num($namespace, $total)
{
  global $num_default;

  $all = isset($_GET["${namespace}_all"]) ? $_GET["${namespace}_all"] != 0 : FALSE;
  $base = isset($_GET["${namespace}_base"]) ? floor($_GET["${namespace}_base"]) : 0;
  $num = isset($_GET["${namespace}_num"]) ? floor($_GET["${namespace}_num"]) : $num_default;

  $all = $all ? 1 : 0;

  if ($num <= 0)
    $num = $num_default;

  if (($base < 0) || ($total == 0))
    $base = 0;
  else if ($base + $num >= $total)
  {
    $last = $total % $num;
    if ($last == 0)
      $last = $num;
    $base = $total - $last;
  }

  return array($all, $base, $num);
}


# Универсальный блок просмотра таблиц
function widget_table($link, $namespace, $tpls, $query_total, $query_select, $select_row_template = '', $fields_callback = '')
{
  # Общее количество строк в таблице
  $total = db_select_value($link, $query_total);

  # Нормализация значений $base и $num
  list($all, $base, $num) = norm_base_num($namespace, $total);

  # Получение строк из БД
  if (!$all)
    $query_select .= " LIMIT $base, $num";
  $rows = db_select_keyvals($link, $query_select);
 
  # Дополнительная обработка строк, если указано
  if (($fields_callback != '') && function_exists($fields_callback))
    foreach($rows as &$row)
      $row = call_user_func($fields_callback, $row);

  $html_nums = widget_nums($tpls, $all, $base, $num, $total);
  $html_all = widget_all($tpls, $all, $base, $num, $total);
  $html_pages = widget_pages($tpls, $all, $base, $num, $total);
  $html_prev = widget_prev($tpls, $all, $base, $num, $total);
  $html_next = widget_next($tpls, $all, $base, $num, $total);
  $html_rows = widget_rows($tpls, $rows, $select_row_template);

  $html = template_fill($tpls['main'], array('%base%' => $base,
                                             '%num%' => count($rows),
                                             '%total%' => $total,
                                             '%rows%' => $html_rows,
                                             '%prev%' => $html_prev,
                                             '%next%' => $html_next,
                                             '%pages%' => $html_pages,
                                             '%nums%' => $html_nums,
                                             '%all%' => $html_all));

  return str_replace('%namespace%', $namespace, $html);
}

# Формирование страницы редактирования объекта
function widget_form($link, $namespace, $tpls, $query_total, $query_prev, $query_next, $query_select, $fields_callback = '')
{
  if (!isset($_GET["${namespace}_id"]))
    error("Не указан идентификатор объекта!");
  $id = floor($_GET["${namespace}_id"]);

  $query_total = str_replace('%id%', $id, $query_total);
  if (db_select_value($link, $query_total) == 0)
    error("Объект с идентификатором $id не существует!");

  # Ссылка на предыдущий объект
  $query_prev = str_replace('%id%', $id, $query_prev);
  $prev = db_select($link, $query_prev);
  if (count($prev))
    $html_prev = str_replace('%id%', $prev[0][0], $tpls['prev']);
  else
    $html_prev = $tpls['no_prev'];

  # Ссылка на следующий объект
  $query_next = str_replace('%id%', $id, $query_next);
  $next = db_select($link, $query_next);
  if (count($next))
    $html_next = str_replace('%id%', $next[0][0], $tpls['next']);
  else
    $html_next = $tpls['no_next'];

  $html = template_fill($tpls['main'],
                             array('%namespace%' => $namespace,
                                   '%prev%' => $html_prev,
                                   '%next%' => $html_next));

  # Извлекаем информацию об объекте
  $query_select = str_replace('%id%', $id, $query_select);
  $rows = db_select_keyvals($link, $query_select);

  if (($fields_callback != '') && function_exists($fields_callback))
    $rows[0] = call_user_func($fields_callback, $rows[0]);

  foreach($rows[0] as $key => $value)
    $html = str_replace("%$key%", htmlspecialchars($value), $html);

  return $html;
}

?>
