<?

# Настройки libhtml
$theme = '/var/www/postadmin/tpls';

# Настройки index
$view_default = 'users';

# Настройки index для подключения к БД
$host = '127.0.0.1';
$db = 'mail';
$user = 'mail';
$password = 'mail_password';

# Настройки libwidgets
$num_default = 15; # Количество строк для отображения в виджете по умолчанию
# Предлагаемые варианты отображения строк
$nums = array(5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 125, 150, 175, 200, 300, 400, 500, 750, 1000);

# Настройки libsession
$session_name = 'sid'; # Имя идентификатора сессии - имя кука
$session_timeout = '00:15:00'; # Таймаут сессии - 15 минут

?>
