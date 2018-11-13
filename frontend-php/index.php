<?

require_once "settings.php";
require_once "libdb.php";
require_once "libhtml.php";
require_once "libwidgets.php";
require_once "libsession.php";

# Функция включения каталога с файлами PHP
function require_path($path)
{
  $dir = opendir($path)
    or error("Не могу открыть каталог $path!");
  while ($file = readdir($dir))
  {
    if (($file == '.') || ($file == '..'))
      continue;
    if (is_file("$path/$file"))
      require_once("$path/$file");
  }
  closedir($dir);
}

# Подключаем модули
require_path('modules');

# Подключаемся к базе данных
$link = db_connect($host, $db, $user, $password);

# Загружаем сессию, если клиент пришёл с идентификатором сессии
session_load($link);

# Пытаемся обнаружить запрошенное действие
if (isset($_POST['ok']) && isset($_POST['action']))
{
  $action = $_POST['action'];
  # Действие обнаружено - выбираем для него параметры
  foreach($_POST as $key => &$value)
  {
    $new_key = preg_replace("/^${action}_(.*)$/", '\1', $key);
    $_POST[$new_key] = $value;
    if ($key != $new_key)
      unset($_POST[$key]);
  }
}
else
  foreach($_POST as $key => $value)
    if (function_exists("act_${key}"))
    {
      $action = $key;
      break;
    }

# Если действие обнаружено - выполняем его
if (isset($action))
{
  if (!function_exists("act_${action}"))
    error("Обработчик действия $action не обнаружен!"); 
  $url = call_user_func("act_${action}", $link);
  if ($url != '')
    header("Location: $url");
}

# Выбираем шаблон представления
$view = isset($_GET['view']) ? $_GET['view'] : $view_default;

# Загружаем шаблон представления
$tpl_view = file("$theme/$view.html")
  or error("Не удалось загрузить шаблон представления $view");

# Заменяем в шаблоне представления вызовы виджетов их содержимым
$html = '';
foreach($tpl_view as &$line)
{
  preg_match('/^<!-- %([a-zA-Z\d_-]*):([a-zA-Z\d_-]*):([a-zA-Z\d_-]*)% --!>$/', $line, $match);
  # В строке найден виджет
  if (!empty($match))
  {
    $widget = $match[1];
    $namespace = $match[2];
    $template = $match[3];

    # Проверяем доступность функции отрисовки виждета
    if (!function_exists("html_${widget}"))
      error("Обработчик виджета $widget не обнаружен!"); 
    $content = call_user_func("html_${widget}", $link, $namespace, "${template}.htm");
    $line = str_replace("<!-- %$widget:$namespace:$template% --!>", $content, $line);
  }
  $html .= $line;
}

# Сохраняем сессию, если она активна
session_save($link);

# Отключаемся от базы данных
db_close($link);

# Выводим получившуюся страницу
echo $html;

?>
