<?

# === НАСТРОЙКИ МОДУЛЯ ПОЧТЫ ===

global $max_bytes_default;
global $max_messages_default;
global $smtp_acl_default;
global $domain_default;
global $pass_length_default;
global $pass_chars_default;
global $ad_domain_default;
global $pass_min_length_default;
global $pass_min_classes_default;

$max_bytes_default = '1G';
$max_messages_default = '1000';
$smtp_acl_default = 'permit_whitelist_auth';
$domain_default = 'domain.ru';
$ad_domain_default = 'MY';

$pass_length_default = 8;
$pass_chars_default = '23456789!%*-_' .
                      'abcdefghjikmnpqrstuvwxyz' .
                      'ABCDEFGHJKLMNPQRSTUVWXYZ';
$pass_min_length_default = 8;
$pass_min_classes_default = 2;

# === ФУНКЦИИ ПРОВЕРКИ ===

# Проверка, похожа ли указанная строка на DNS-домен
function check_domain($domain)
{
  preg_match('/^[a-zA-Z\d.-]+\.[a-zA-Z]{2,4}$/', $domain, $matches);
  if (empty($matches))
    error("Указанная строка $doamin не похожа на правильный домен DNS!");
}

# Проверка, похожа ли указанная строка на транспорт
function check_transport($transport)
{
  preg_match('/^(dovecot|virtual):$/', $transport, $matches);
  if (!empty($matches))
    return;
  preg_match('/^smtp:((\d{1,3}\.){3}\d{1,3}|[a-zA-Z\d.-]+\.[a-zA-Z]{2,4})(:\d{1,5})?$/', $transport, $matches);
  if (empty($matches))
    error("Указанная строка $transport не похожа на правильный транспорт Postfix!");
}

# Проверка, похожа ли указанная строка на email
function check_email($email)
{
  preg_match('/^[\w\d.-]+@[a-zA-Z\d.-]+\.[a-zA-Z]{2,4}$/', $email, $matches);
  if (empty($matches))
    error("Указанная строка $email не является правильным адресом электронной почты.");
}

# Проверка, является ли домен указанного адреса локальным
function check_local_email($link, $email)
{
  if (db_select_value($link, "SELECT COUNT(*)
                              FROM domain
                              WHERE domain=SUBSTRING_INDEX('$email', '@', -1)
                                AND transport IN ('dovecot:', 'virtual:')") == 0)
    error("Домен $domain не является локальным!");
}


# Является ли этот ящик правильным и свободным?
function check_free_email($link, $email)
{
  check_email($email);

  check_local_email($link, $email);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM user
                              WHERE email='$email'") > 0)
    error("Уже существует почтовый ящик с адресом $email!");

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM subscription
                              WHERE email='$email' AND direction='I'") > 0)
    error("Адрес электронной почты $email уже использутеся в псевдониме или рассылке!");
}

# Проверка, является ли указанный пароль достаточно безопасным
function check_password($password)
{
  global $pass_min_length_default;
  global $pass_min_classes_default;

  if (strlen($password) < $pass_min_length_default)
    error("Указанный пароль не удовлетворяет требованиям безопасности:"
          . " пароль должен состоять не менее чем из $pass_min_length_default символов!");

  $classes = 0;
  preg_match('/\d+/', $password, $matches);
  if (count($matches) > 0)
    $classes++;

  preg_match('/[a-z]+/', $password, $matches);
  if (count($matches) > 0)
    $classes++;

  preg_match('/[A-Z]+/', $password, $matches);
  if (count($matches) > 0)
    $classes++;

  preg_match('/[~!@#$%^&*()_+-=\\[\]{};\:",.\/<>?\|]+`\'/', $password, $matches);
  if (count($matches) > 0)
    $classes++;

  if ($classes < $pass_min_classes_default)
    error("Указанный пароль не удовлетворяет требованиям безопасности:"
          . " пароль должен состоять не менее чем из $pass_min_classes_default символов разного класса"
          . " (строчные латинские буквы, прописные латинские буквы, цифры, знаки препинания)!");
}

# Проверка, является ли указанная строка адресом электронной почты или доменом
function check_address($address)
{
  preg_match('/^[a-zA-Z\d.-]+\.[a-zA-Z]{2,4}$/', $address, $matches);
  if (!empty($matches))
    return;

  preg_match('/^[\w\d.-]+@[a-zA-Z\d.-]+\.[a-zA-Z]{2,4}$/', $address, $matches);
  if (empty($matches))
    error("Указанная строка $address не похожа на правильный домен DNS или адрес электронной почты!");
}

# === ФУНКЦИИ ДЛЯ РАБОТЫ С ДОМЕНАМИ ===

# Заведение нового домена
function domain_new($link, $domain, $transport)
{
  $domain = trim($domain);
  $transport = trim($transport);

  check_domain($domain);
  check_transport($transport);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM domain
                              WHERE domain='$domain'") > 0)
    error("Домен $domain уже существует!");

  db_update($link, "INSERT INTO domain
                    SET domain='$domain',
                        transport='$transport'");
}

# Изменение имени домена или его транспорта
function domain_edit($link, $id, $domain, $transport)
{
  $id = floor($id);
  $domain = trim($domain);
  $transport = trim($transport);

  check_domain($domain);
  check_transport($transport);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM domain
                              WHERE domain='$domain' AND id<>$id") > 0)
    error("Домен $domain уже существует!");

  db_update($link, "UPDATE domain
                    SET domain='$domain',
                        transport='$transport'
                    WHERE id=$id");
}

# Замена транспорта для указанных доменов
function domains_change_transport($link, $ids, $transport)
{
  $transport = trim($transport);
  check_transport($transport);

  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(",", $ids);

  db_update($link, "UPDATE domain SET transport='$transport' WHERE id IN ($ids)");
}

# Удаление сразу нескольких доменов
function domains_remove($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM domain
                              JOIN user ON SUBSTRING_INDEX(user.email, '@', -1)=domain.domain
                              WHERE domain.id IN ($ids)") > 0)
    error("Нельзя удалить домены, к которым привязаны почтовые ящики!");
  if (db_select_value($link, "SELECT COUNT(*)
                              FROM domain
                              JOIN subscription ON SUBSTRING_INDEX(subscription.email, '@', -1)=domain.domain
                                AND subscription.direction='I'
                              WHERE domain.id IN ($ids)") > 0)
    error("Нельзя удалить домены, к которым привязаны подписки!");

  db_update($link, "DELETE FROM domain WHERE id IN ($ids)");
}

# === ФУНКЦИИ ДЛЯ РАБОТЫ С ПЕРЕСЫЛКАМИ ===

# Проверка, приведёт ли эта пересылка к зацикливанию пересылок
function is_cycled_subscription($link, $email, $recipient)
{
  # Если адреса списка и получателя пересылки совпадают - пересылка зациклена
  if ($email == $recipient)
    return TRUE;

  # Проверяем, есть ли пересылки, получателем которых является эта пересылка
  $rows = db_select($link, "SELECT email
                            FROM subscription
                            WHERE recipient='$email' AND direction='I'");
  # Нет таких - цикла нет
  if (empty($rows))
    return FALSE;

  # Есть - проверяем каждую из пересылок
  foreach($rows as $row)
    if (is_cycled_subscription($link, $row[0], $recipient))
      return TRUE;

  # Все пересылки проверены, а циклы не найдены
  return FALSE;
} 

# Проверка, приведёт ли эта пересылка к зацикливанию пересылок
function check_cycled_subscription($link, $email, $recipient)
{
  if (is_cycled_subscription($link, $email, $recipient))
    error("Указанный получаетель пересылки $recipient сам является источником почты для адреса $email!");
}

# Создание переылки - подписка на список рассылки или создание псевдонима
function subscribe($link, $email, $recipient, $incoming = TRUE)
{
  # Проверка адреса-источника
  check_email($email);

  if ($incoming)
    check_local_email($link, $email);

  else if (db_select_value($link, "SELECT COUNT(*)
                                   FROM user
                                   WHERE email='$email'") == 0)
    error("Источник исходящей почты $email не существует!");

  # Проверка адреса-получателя
  check_email($recipient);

  check_local_email($link, $recipient);

  # Проверка, не приведёт ли создание подписки к зацикливанию цепочки подписок
  if ($incoming)
    check_cycled_subscription($link, $email, $recipient);

  $direction = $incoming ? 'I' : 'O';

  db_update($link, "INSERT IGNORE INTO subscription
                    SET email='$email',
                        recipient='$recipient',
                        direction='$direction'");
}

# Подписка пользователей на рассылку
function users_subscribe($link, $email, $ids, $incoming = TRUE)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);

  $ids = implode(',', $ids);

  $recipients = db_select($link, "SELECT email FROM user WHERE id IN ($ids)");

  foreach($recipients as $recipient)
    subscribe($link, $email, $recipient[0], $incoming);
}

# Удаление пересылок по их идентификаторам
function unsubscribe($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  db_update($link, "DELETE FROM subscription WHERE id IN ($ids)");
}

# === ГЕНЕРАЦИЯ ЛОГИНОВ И ПАРОЛЕЙ ===

# Функция транслитерации по корпоративному стандарту СГ УралСиб
function ru2en($s)
{
  $src = array('ия ', 'ъб', 'ъв', 'ъг', 'ъд', 'ъж', 'ъз', 'ък', 'ъл', 'ъм', 'ън', 'ъп', 'ър', 'ъс', 'ът', 'ъф', 'ъх', 'ъц', 'ъч', 'ъш', 'ъщ',
    'ьб', 'ьв', 'ьг', 'ьд', 'ьж', 'ьз', 'ьк', 'ьл', 'ьм', 'ьн', 'ьп', 'ьр', 'ьс', 'ьт', 'ьф', 'ьх', 'ьц', 'ьч', 'ьш', 'ьщ',
    'ъа', 'ъе', 'ъё', 'ъи', 'ъй', 'ъо', 'ъу', 'ъы', 'ъэ', 'ъю',  'ъя',  'ия', 'ий', 'ый', 'ая',  'яя',  'ья', 'ьи', 'ью', 'ье', 'ие', 'ь',
    'Ия', 'Ий', 'Ый', 'Ая',  'Яя',  'Ие',
    'а', 'б', 'в', 'г', 'д', 'е', 'ё', 'ж',  'з', 'и', 'й', 'к', 'л', 'м', 'н', 'о',
    'п', 'р', 'с', 'т', 'у', 'ф', 'х',  'ц',  'ч',  'ш',  'щ',   'ы', 'э', 'ю',  'я',
    'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ё', 'Ж',  'З', 'И', 'Й', 'К', 'Л', 'М', 'Н', 'О',
    'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х',  'Ц',  'Ч',  'Ш',  'Щ',   'Ы', 'Э', 'Ю',  'Я');

  $dst = array('ia ', 'b',  'v',  'g',  'd',  'zh', 'z',  'k',  'l',  'm',  'n',  'p',  'r',  's',  't',  'f',  'kh', 'ts', 'ch', 'sh', 'sch',
    'b',  'v',  'g',  'd',  'zh', 'z',  'k',  'l',  'm',  'n',  'p',  'r',  's',  't',  'f',  'kh', 'ts', 'ch', 'sh', 'sch',
    'ia', 'ie', 'ie', 'ii', 'ij', 'io', 'iu', 'iy', 'ie', 'iyu', 'iya', 'ya', 'y',  'y',  'aya', 'aya', 'ya', 'ii', 'ju', 'ie', 'ie', '',
    'Ya', 'Y',  'Y',  'Aya', 'Aya', 'Ie',
    'a', 'b', 'v', 'g', 'd', 'e', 'e', 'zh', 'z', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p',  'r',  's', 't', 'u', 'f', 'kh',  'ts', 'ch', 'sh', 'sch', 'y', 'e', 'yu', 'ya',
    'A', 'B', 'V', 'G', 'D', 'E', 'E', 'Zh', 'Z', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'R', 'S', 'T', 'U', 'F', 'Kh', 'Ts', 'Ch', 'Sh', 'Sch', 'Y', 'E', 'Yu', 'Ya');

  $d = preg_replace('/ия$/', 'ia', $s);
  $d = str_replace($src, $dst, $d);

  return $d;
}

# Функция возвращает массив всех возможных логинов,
# удовлетворяющих корпоративному стандарту СГ УралСиб
# name - имя, patronym - отчество, surname - фамилия
# maxlen - максмальная длина логина, необязательный аргумент,
# по корпоративному стандарту должен равняться 12
function get_logins($surname, $name = '', $patronym = '', $maxlen = 12)
{
  # Удаляем из имени, отчества и фамилии пробелы слева и справа
  # Транслитерируем их
  $name = ru2en(trim($name));
  $patronym = ru2en(trim($patronym));
  $surname = ru2en(trim($surname));

  # Если фамилия не указана - возвращаем пустой список
  if (strlen($surname) == 0)
    return array();

  # Если указано имя, то первая буква имени включается в логин
  if (strlen($name) > 0)
  {
    $login = $name[0];
    # Если указана фамилия, то её первая буква включается в логин
    if (strlen($patronym) > 0)
      $login .= $patronym[0];
    # Суммарная длина логина - maxlen,
    # включая первые буквы имени и отчества, если они есть
    $login = substr($surname, 0, $maxlen - strlen($login)) . $login;
    $logins = array(strtolower($login) => $login);
  }
  else
  {
    # Логин генерируется только на основании фамилии,
    # поскольку имя не указано, то отчество игнорируется,
    # даже если оно было указано
    $login = substr($surname, 0, $maxlen);
    $logins = array(strtolower($login) => $login);
  }

  # Дополнительные логины, в которых вместо буквы отчества
  # используется одна из следующих букв имени
  for($i = 1; $i < strlen($name); $i++)
  {
    $login = substr($surname, 0, $maxlen - 2) . $name[0] . $name[$i];
    if (array_key_exists(strtolower($login), $logins))
      continue;
    $logins = array_merge($logins, array(strtolower($login) => $login));
  }
  $logins = array_values($logins);
  return $logins;
}

# Поиск ещё не занятого почтового адреса для указанных ФИО
function get_free_login($link, $domain, $surname, $name = '', $patronym = '')
{
  if (($domain == '') || ($surname == ''))
    return '';

  $logins = get_logins($surname, $name, $patronym);
  foreach($logins as $login)
  {
    if (db_select_value($link, "SELECT COUNT(*)
                                FROM user
                                WHERE email='$login@$domain'") > 0)
      continue;
    else if (db_select_value($link, "SELECT COUNT(*)
                                     FROM subscription
                                     WHERE email='$login@$domain' AND direction='I'") > 0)
      continue;
    else
      return $login;
  }
  return '';
}

# Генерация случайного пароля длиной $pass_length_default,
# используются только символы из строки $pass_chars_default
function get_password()
{
  global $pass_length_default;
  global $pass_chars_default;

  $pass = '';
  for($i = 0; $i < $pass_length_default; $i++)
    $pass .= substr($pass_chars_default, (rand() % strlen($pass_chars_default)), 1);
  return $pass;
}

# Добавление пользователя
function user_new($link, $active, $email, $password, $surname, $name, $patronym, $department, $position, $phones, $ad_login, $max_bytes, $max_messages, $smtp_acl)
{
  $active = $active ? 'Y' : 'N';

  check_free_email($link, $email);

  check_password($password);

  $surname = mysql_escape_string($surname);
  $name = mysql_escape_string($name);
  $patronym = mysql_escape_string($patronym);
  $department = mysql_escape_string($department);
  $position = mysql_escape_string($position);
  $phones = mysql_escape_string($phones);
  $ad_login = mysql_escape_string($ad_login);
  $max_bytes = from_hr_size($max_bytes);
  $max_messages = floor($max_messages);
  $smtp_acl = mysql_escape_string($smtp_acl);

  db_update($link, "INSERT INTO user
                    SET email='$email',
                        active='$active',
                        password=ENCRYPT('$password'),
                        surname='$surname',
                        name='$name',
                        patronym='$patronym',
                        department='$department',
                        position='$position',
                        phones='$phones',
                        ad_login='$ad_login',
                        bytes=0,
                        max_bytes=$max_bytes,
                        messages=0,
                        max_messages=$max_messages,
                        smtp_acl='$smtp_acl'");
}

# Редактирование пользователя
function user_edit($link, $id, $active, $password, $surname, $name, $patronym, $department, $position, $phones, $ad_login, $max_bytes, $max_messages, $smtp_acl)
{
  $id = floor($id);

  $active = $active ? 'Y' : 'N';

  # Пароль меняем только в том случае, если указан не пустой пароль
  if ($password != '')
  {
    check_password($password);
    $password = "password=ENCRYPT('$password'),";
  }

  $surname = mysql_escape_string($surname);
  $name = mysql_escape_string($name);
  $patronym = mysql_escape_string($patronym);
  $department = mysql_escape_string($department);
  $position = mysql_escape_string($position);
  $phones = mysql_escape_string($phones);
  $ad_login = mysql_escape_string($ad_login);
  $max_bytes = from_hr_size($max_bytes);
  $max_messages = floor($max_messages);
  $smtp_acl = mysql_escape_string($smtp_acl);

  db_update($link, "UPDATE user
                    SET $password
                        active='$active',
                        surname='$surname',
                        name='$name',
                        patronym='$patronym',
                        department='$department',
                        position='$position',
                        phones='$phones',
                        ad_login='$ad_login',
                        max_bytes=$max_bytes,
                        max_messages=$max_messages,
                        smtp_acl='$smtp_acl'
                    WHERE id=$id");
}

# Удаление пользователя с передачей подписок по наследству
function user_remove($link, $id)
{
  $id = floor($id);

  # Извлекаем адрес удаляемого пользователя на входящие
  $rows = db_select($link, "SELECT email
                            FROM user
                            WHERE user.id=$id");
  $email = $rows[0][0];

  # Извлекаем подписки удаляемого пользователя на входящие
  $rows = db_select($link, "SELECT subscription.email
                            FROM subscription
                            JOIN user ON user.email=subscription.recipient
                              AND user.id=$id
                            WHERE subscription.direction='I'");
  $incoming = array();
  foreach($rows as $row)
    $incoming[] = $row[0];

  # Извлекаем подписки удаляемого пользователя на исходящие
  $rows = db_select($link, "SELECT subscription.email
                            FROM subscription
                            JOIN user ON user.email=subscription.recipient
                              AND user.id=$id
                            WHERE subscription.direction='O'");
  $outgoing = array();
  foreach($rows as $row)
    $outgoing[] = $row[0];

  # Извлекаем список получателей
  $rows = db_select($link, "SELECT subscription.recipient
                            FROM subscription
                            JOIN user ON user.email=subscription.email
                              AND user.id=$id
                            WHERE subscription.direction='I'");
  $recipients = array();
  foreach($rows as $row)
    $recipients[] = $row[0];

  $queries = array();

  # Подписываем получателей на входящие
  foreach($incoming as $email)
    foreach($recipients as $rcpt)
      $queries[] = "INSERT IGNORE subscription
                    SET email='$email',
                        recipient='$rcpt',
                        direction='I'";

  # Подписываем получателей на исходящие
  foreach($outgoing as $email)
    foreach($recipients as $rcpt)
      $queries[] = "INSERT IGNORE subscription
                    SET email='$email',
                        recipient='$rcpt',
                        direction='I'";

  # Подписываем получателей на адрес удаляемого пользователя
  foreach($recipients as $rcpt)
    $queries[] = "INSERT IGNORE subscription
                  SET email='$email',
                      recipient='$rcpt',
                      direction='I'";

  # Удаляем подписки удаляемого пользователя
  $queries[] = "DELETE FROM subscription
                WHERE recipient=(SELECT email FROM user WHERE id=$id)";

  # Удаляем самого пользователя
  $queries[] = "DELETE FROM user WHERE id=$id";

  # Выполняем сформированный список запросов
  db_update($link, $queries);
}

# Удаление пользователей с передачей их подписок по наследству
function users_remove($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as $id)
    user_remove($link, $id);
}

# Редактирование квоты объёма ящика
function users_change_max_bytes($link, $ids, $max_bytes)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  $max_bytes = from_hr_size($max_bytes);
  db_update($link, "UPDATE user SET max_bytes=$max_bytes WHERE id IN ($ids)");
}

# Редактирование квоты количества сообщений
function users_change_max_messages($link, $ids, $max_messages)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  $max_messages = floor($max_messages);
  db_update($link, "UPDATE user SET max_messages=$max_messages WHERE id IN ($ids)");
}

# Отключение пользователей
function users_disable($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  db_update($link, "UPDATE user SET active='N' WHERE id IN ($ids)");
}

# Включение пользователей
function users_enable($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  db_update($link, "UPDATE user SET active='Y' WHERE id IN ($ids)");
}

# === ФУНКЦИИ КОНВЕРТИРОВАНИЯ ОБЪЁМА ПАМЯТИ ===

# Перевод объёма из человекочитаемого формата в байты
function from_hr_size($size)
{
  $match = array('/^(\d*[.]?\d*)[bBбБ]?$/u',
                 '/^(\d*[.]?\d*)[kKкК]{1}[bBбБ]?$/u',
                 '/^(\d*[.]?\d*)[mMмМ]{1}[bBбБ]?$/u',
                 '/^(\d*[.]?\d*)[gGгГ]{1}[bBбБ]?$/u',
                 '/^(\d*[.]?\d*)[tTтТ]{1}[bBбБ]?$/u');
  $replace = array('\1:1',
                   '\1:1024',
                   '\1:1048576',
                   '\1:1073741824',
                   '\1:1099511627776');
  $size = str_replace(',', '.', trim($size));
  list($num, $mul) = explode(':', preg_replace($match, $replace, $size));
  if (!is_numeric($num))
    return 0;
  return $num * $mul;
}

# Перевод объёма из байтов в человекочитаемый формат
function to_hr_size($size)
{
  if (!is_numeric($size))
    return 0;
  $sizes = array(1024, 1048576, 1073741824, 1099511627776);
  $suffixes = array('K', 'M', 'G', 'T');

  $div = 1;
  $suffix = '';
  for($i = 0; $i < count($sizes); $i++)
    if ($size >= $sizes[$i])
    {
      $div = $sizes[$i];
      $suffix = $suffixes[$i];
    }

  $size = round($size / $div, 2);
  return "$size$suffix";
}

# === ФУНКЦИИ ДЛЯ РАБОТЫ С СПИСКАМИ УПРАВЛЕНИЯ ДОСТУПОМ SMTP ===

# Заведение нового получателя
function smtp_acl_new($link, $acl, $address, $description = '')
{
  $acl = trim($acl);
  $address = trim($address);
  $description = trim($description);

  $acl = mysql_escape_string($acl);
  check_address($address);
  $description = mysql_escape_string($description);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM smtp_acl
                              WHERE acl='$acl' AND address='$address'") > 0)
    error("Адрес $address уже существует в списке $acl!");

  db_update($link, "INSERT INTO smtp_acl
                    SET acl='$acl',
                        address='$address',
                        description='$description'");
}

# Изменение адреса получателия или его описания
function smtp_acl_edit($link, $id, $acl, $address, $description)
{
  $id = floor($id);
  $acl = trim($acl);
  $address = trim($address);
  $description = trim($description);

  $acl = mysql_escape_string($acl);
  check_address($address);
  $description = mysql_escape_string($description);

  if (db_select_value($link, "SELECT COUNT(*)
                              FROM smtp_acl
                              WHERE acl='$acl' AND address='$address' AND id<>$id") > 0)
    error("Адрес $address уже существует в списке $acl!");

  db_update($link, "UPDATE smtp_acl
                    SET acl='$acl',
                        address='$address',
                        description='$description'
                    WHERE id=$id");
}

# Удаление сразу нескольких адресов
function smtp_acls_remove($link, $ids)
{
  $ids = is_array($ids) ? $ids : array($ids);

  if (empty($ids))
    return 0;

  foreach($ids as &$id)
    $id = floor($id);
  $ids = implode(',', $ids);

  db_update($link, "DELETE FROM smtp_acl WHERE id IN ($ids)");
}

?>
