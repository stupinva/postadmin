<?

#CREATE TABLE `session` (
#  `id` varchar(32) NOT NULL,
#  `firsttime` datetime NOT NULL,
#  `lasttime` datetime NOT NULL,
#  `data` text NOT NULL,
#  `user_id` int(11) NOT NULL,
#  `ip` varchar(15) default NULL,
#  PRIMARY KEY  (`id`)
#) ENGINE=InnoDB DEFAULT CHARSET=utf8;

$session_id = '';
$session_user_id = '';

function session_to_get()
{
  # Переменные сессии используем наравне с переменными из адресной строки
  # Однако адресная строка имеет приоритет
  foreach($_SESSION as $key => $value)
    if (!isset($_GET[$key]))
      $_GET[$key] = $value;
}

function get_to_session()
{
  # Переменные сессии используем наравне с переменными из адресной строки
  # Однако адресная строка имеет приоритет
  foreach($_GET as $key => $value)
    $_SESSION[$key] = $value;
}

# Загрузка сессии, если клиент пришёл с валидным куком сессии
function session_load($link)
{
  global $session_name;
  global $session_timeout;
  global $session_id;
  global $session_user_id;

  # Узнаём идентификатор сессии, возвращённый браузером
  $session_id = isset($_POST[$session_name]) ? $_POST[$session_name] :
                  (isset($_GET[$session_name]) ? $_GET[$session_name] :
                    (isset($_COOKIE[$session_name]) ? $_COOKIE[$session_name] : ''));

  # Если найден годный идентификатор сессии, грузим её
  if ($session_id != '')
  {
    # Иначе пытаемся найти неистёкшую сессию с указанным идентификатором
    # и IP текущего клиента
    $ip = $_SERVER['REMOTE_ADDR'];
    $session_id = mysql_escape_string($session_id);
    $rows = db_select_keyvals($link, "SELECT user_id,
                                             data
                                      FROM session
                                      WHERE id='$session_id'
                                        AND ADDTIME(lasttime, '$session_timeout') > NOW()
                                        AND ip='$ip'");
  }
  else
    $rows = array();

  # Если сессия нашлась, извлекаем её и идентификатор пользователя
  if (!empty($rows))
  {
    $session_user_id = $rows[0]['user_id'];
    $session = unserialize($rows[0]['data']);

    # Дополняем отсутствующие значения из строки запроса значениями из сессии
    foreach($session as $key => $value)
      if (!isset($_GET[$key]))
        $_GET[$key] = $value;
  }
  else
  {
    # Удаляем идентификатор сессии, если он негоден и грузим переменные
    # сессии неаутентифицированного пользователя из его кук
    setcookie($session_name, $session_id, time() - 3600);

    # Дополняем отсутствующие значения из строки запроса значениями из кук
    foreach($_COOKIE as $key => $value)
      if (!isset($_GET[$key]))
        $_GET[$key] = $value;
  }
}

# Сохранение сессии, если сессия была открыта
function session_save($link)
{
  global $session_timeout;
  global $session_id;
  global $session_user_id;

  # Если сессия была открыта, то попытаемся её сохранить
  if ($session_id != '')
  {
    $session = mysql_escape_string(serialize($_GET));
    $ip = $_SERVER['REMOTE_ADDR'];

    # Обновляем данные сессии только если она существует, не истекла
    # а IP текущего клиента совпадает с IP в сессии
    db_update($link, "UPDATE session
                      SET data='$session',
                          lasttime=NOW()
                      WHERE id='$session_id'
                        AND ip='$ip'
                        AND ADDTIME(lasttime, '$session_timeout') > NOW()");
  }
  # Если сессия не была открыта, то сохраняем сессию неаутентифицированного
  # пользователя в его куки
  else
  {
    foreach($_GET as $key => $value)
      setcookie($key, $value);
  }
}

# Создание новой сессии с указанным идентификатором пользователя
function session_new($link, $user_id)
{
  global $session_name;
  global $session_timeout;
  global $session_id;
  global $session_user_id;

  # Генерируем новый идентификатор сессии
  $ip = $_SERVER['REMOTE_ADDR'];
  $session_user_id = $user_id;
  $time = time();
  $rand = rand();
  $session_id = md5("$ip-$session_user_id-$time-$rand");

  # Сохраняем пустую сессию
  db_update($link, "INSERT IGNORE INTO session
                    SET id='$session_id',
                        firsttime=NOW(),
                        lasttime=NOW(),
                        data='',
                        ip='$ip',
                        user_id='$user_id'");
  # И ставим куку
  setcookie($session_name, $session_id);
}

# Удаление текущей сессии из БД
function session_remove($link)
{
  global $session_name;
  global $session_timeout;
  global $session_id;
  global $session_user_id;

  # Если сессия открыта
  if ($session_id != '')
  {
    $ip = $_SERVER['REMOTE_ADDR'];
    db_update($link, "DELETE FROM session
                      WHERE (id='$session_id' AND ip='$ip')
                        OR ADDTIME(lasttime, '$session_timeout') < NOW()");
    $session_id = '';
    $session_user_id = '';
    setcookie($session_name, $session_id, time() - 3600);
  }
}

?>
