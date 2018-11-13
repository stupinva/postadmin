<?

# Функция вывода сообщения об ошибке по шаблону
function error($error)
{
  global $theme;
  $text = file("$theme/error.html")
    or die($error);

  $html = '';
  foreach($text as $line)
    $html .= str_replace('%error%', $error, $line);

  echo $html;
  exit;
}

# Написано 03-11-2011

# Новая модная функция загрузки шаблонов

# Строки между строками, начинающимися с
# <!-- %macro%
# и строками, начинающимися с
# %macro% --!>
# загружаются в элемент ассоциативного массива $template['macro']

# Остальной текст загружается в элемент ассоциативного массива $template['main'],
# а изъятые фрагменты заменяются на текст '%macro%'
# %macro% может быть любым текстом, начинающимся и оканчивающимся знаком процента

function template_load($template_name)
{
  global $theme;
  $text = file("$theme/$template_name")
    or error("Не удалось загрузить шаблон $template_name.");

  $macro = 'main';
  $template = array();
  $template['main'] = '';
  foreach($text as $line)
  {
    preg_match('/^<!-- %(.*)%$/', $line, $begin);
    preg_match('/^%(.*)% --!>$/', $line, $end);
    if (!empty($begin))
    {
      if ($macro != 'main')
        error("Макрос $macro не закрыт.");
      $macro = $begin[1];
      $template[$macro] = '';
    }
    else if (!empty($end))
    {
      if ($macro == 'main')
        error("Попытка закрыть не открытый макрос {$end[1]}.");
      else if ($macro != $end[1])
        error("Попытка закрыть макрос $macro макросом {$end[1]}.");
      $macro = 'main';
    }
    else
      $template[$macro] .= $line;
  }
  return $template;
}

# Заполнение уже загруженного шаблона
function template_fill($template, $keyvals)
{
  # Выполняем подстановку макросов в шаблоне
  foreach($keyvals as $key => $value)
    $template = str_replace($key, $value, $template);

  # Выводим заполненный шаблон
  return $template;
}

?>

