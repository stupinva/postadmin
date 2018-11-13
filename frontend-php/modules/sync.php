<?

# Настройки подключения к порталу
global $portal_host;
global $portal_db;
global $portal_user;
global $portal_password;

$portal_host = '10.0.0.1';
$portal_db = 'WSS_Content';
$portal_user = 'portal';
$portal_password = 'portal_password';

# Синхронизация двух переменных
# Если одно из полей пустое, а другое нет, то в пустое копируется значение заполненного
# Если оба поля непустые, то в режиме '' поля не меняются
# Если оба поля непустые, то в режиме 'left' значение правого поля заменяется значением левого
# Если оба поля непустые, то в режиме 'right' значение левого поля заменяется значением правого
function sync_variables($mode, &$left, &$right)
{
  preg_match("/^[ ]*$/", $left, $matches);
  if (!empty($matches))
    $left = '';
  preg_match("/^[ ]*$/", $right, $matches);
  if (!empty($matches))
    $right = '';
  if (($left == '') && ($right != ''))
    $left = $right;
  else if (($left != '') && ($right == ''))
    $right = $left;
  else if (($left != '') && ($right != ''))
  {
    if ($mode == 'left')
      $right = $left;
    else if ($mode == 'right')
      $left = $right;
  }
}

# mode = 'mail' - если оба поля непустые, то предпочтение отдаётся полю из почтовой БД
# mode = 'portal' - если оба поля непустые, то предпочтение отдаётся полю из БД портала
# mode = '' или другое - если оба поля непустые, то они не меняются
function sync($link, $mode)
{
  global $portal_host;
  global $portal_db;
  global $portal_user;
  global $portal_password;

  # Подключение к БД портала SharePoint
  $portal = mssql_connect($portal_host, $portal_user, $portal_password)
    or die("Не удалось подключиться к БД портала!");
  mssql_select_db($portal_db, $portal)
    or die("Не удалось выбрать БД портала!");

  # Выбор режима синхронизации переменных
  if ($mode == 'mail')
    $mode = 'left';
  else if ($mode == 'portal')
    $mode = 'right';
  else
    $mode = '';

  # Запрос из почтовой БД - получаем список всех записей для синхронизации
  $mresult = mysql_query("SELECT email,
                                 surname,
                                 name,
                                 patronym,
                                 ad_login,
                                 department,
                                 position,
                                 phones
                          FROM user", $link)
    or die('Не удалось выполнить запрос: ' . mysql_error());

  # Цикл по записям из почтовой БД
  while($mrow = mysql_fetch_row($mresult))
  {
    $memail = $mrow[0];
    $msurname = $mrow[1];
    $mname = $mrow[2];
    $mpatronym = $mrow[3];
    $mfullname = "$msurname $mname $mpatronym";
    $mad_login = $mrow[4];
    $mdepartment = $mrow[5];
    $mposition = $mrow[6];
    $mphones = $mrow[7];

    $pfullname = '';
    $pad_login = '';
    $pdepartment = '';
    $pposition = '';
    $pphones = '';
    $p2fullname = '';
    $p2email = '';
    $p2department = '';
    $p2position = '';
    $p2phones = '';
    $p3fullname = '';
    $p3ad_login = '';
    $p4fullname = '';
    $p4email = '';

# Этап 1 - выемка информации из таблицы AllUserData портала по email
    $presult = mssql_query("SELECT nvarchar1, -- surname name patronym
                                   nvarchar3, -- ad_login
                                   nvarchar4, -- email
                                   nvarchar8, -- department
                                   nvarchar9, -- position
                                   nvarchar10 -- phones
                            FROM AllUserData
                            WHERE nvarchar4=N'$memail'", $portal);
    while($prow = mssql_fetch_row($presult))
    {
      foreach($prow as &$row)
        $row = iconv("WINDOWS-1251", "UTF-8", $row);

      $pfullname = $prow[0];
      $pad_login = $prow[1];
      $pemail = $prow[2];
      $pdepartment = $prow[3];
      $pposition = $prow[4];
      $pphones = $prow[5];

      sync_variables($mode, $mfullname, $pfullname);
      sync_variables($mode, $mad_login, $pad_login);
      sync_variables($mode, $mdepartment, $pdepartment);
      sync_variables($mode, $mposition, $pposition);
      sync_variables($mode, $mphones, $pphones);
    }
    mssql_free_result($presult);

# Этап 2 - выемка информации из таблицы AllUserData портала по ad_login
    $presult = mssql_query("SELECT nvarchar1, -- surname name patronym
                                   nvarchar3, -- ad_login
                                   nvarchar4, -- email
                                   nvarchar8, -- department
                                   nvarchar9, -- position
                                   nvarchar10 -- phones
                            FROM AllUserData
                            WHERE LOWER(nvarchar3)=LOWER(N'$mad_login')", $portal);
    while($prow = mssql_fetch_row($presult))
    {
      foreach($prow as &$row)
        $row = iconv("WINDOWS-1251", "UTF-8", $row);

      $p2fullname = $prow[0];
      $p2ad_login = $prow[1];
      $p2email = $prow[2];
      $p2department = $prow[3];
      $p2position = $prow[4];
      $p2phones = $prow[5];

      sync_variables($mode, $mfullname, $p2fullname);
      sync_variables('', $memail, $p2email);
      sync_variables($mode, $mdepartment, $p2department);
      sync_variables($mode, $mposition, $p2position);
      sync_variables($mode, $mphones, $p2phones);
    }
    mssql_free_result($presult);

# Этап 3 - выемка информации из таблицы UserInfo портала по email
    $presult = mssql_query("SELECT tp_Login, -- ad_login
                                   tp_Title, -- surname name patronym
                                   tp_Email -- email
                            FROM UserInfo
                            WHERE tp_Email=N'$memail'", $portal);
    while($prow = mssql_fetch_row($presult))
    {
      foreach($prow as &$row)
        $row = iconv("WINDOWS-1251", "UTF-8", $row);

      $p3ad_login = $prow[0];
      $p3fullname = $prow[1];
      $p3email = $prow[2];

      sync_variables($mode, $mfullname, $p3fullname);
      sync_variables($mode, $mad_login, $p3ad_login);
    }
    mssql_free_result($presult);

# Этап 4 - выемка информации из таблицы UserInfo портала по ad_login
    $presult = mssql_query("SELECT tp_Login, -- ad_login
                                   tp_Title, -- surname name patronym
                                   tp_Email -- email
                            FROM UserInfo
                            WHERE LOWER(tp_Login)=LOWER(N'$mad_login')", $portal);
    while($prow = mssql_fetch_row($presult))
    {
      foreach($prow as &$row)
        $row = iconv("WINDOWS-1251", "UTF-8", $row);

      $p4ad_login = $prow[0];
      $p4fullname = $prow[1];
      $p4email = $prow[2];

      sync_variables($mode, $mfullname, $p4fullname);
      sync_variables('', $memail, $p4email);
    }
    mssql_free_result($presult);

# Этап 5 - повторная синхронизация всех источников для взаимной синхронизации таблиц портала
    sync_variables($mode, $mfullname, $pfullname);
    sync_variables($mode, $mad_login, $pad_login);
    sync_variables($mode, $mdepartment, $pdepartment);
    sync_variables($mode, $mposition, $pposition);
    sync_variables($mode, $mphones, $pphones);
    sync_variables($mode, $mfullname, $p2fullname);
    sync_variables('', $memail, $p2email);
    sync_variables($mode, $mdepartment, $p2department);
    sync_variables($mode, $mposition, $p2position);
    sync_variables($mode, $mphones, $p2phones);
    sync_variables($mode, $mfullname, $p3fullname);
    sync_variables($mode, $mad_login, $p3ad_login);
    sync_variables($mode, $mfullname, $p4fullname);
    sync_variables('', $memail, $p4email);

# Этап 6 - обновление информации в почтовой базе
    list($msurname, $mname, $mpatronym) = explode(' ', $mfullname);

    $msurname = mysql_escape_string($msurname);
    $mname = mysql_escape_string($mname);
    $mpatronym = mysql_escape_string($mpatronym);
    $mad_login = mysql_escape_string($mad_login);
    $mdepartment = mysql_escape_string($mdepartment);
    $mposition = mysql_escape_string($mposition);
    $mphones = mysql_escape_string($mphones);

    $mquery = "UPDATE user
               SET surname='$msurname',
                   name='$mname',
                   patronym='$mpatronym',
                   department='$mdepartment',
                   ad_login='$mad_login',
                   position='$mposition',
                   phones='$mphones'
               WHERE email='$memail'";
    db_update($link, $mquery);

# Этап 7 - обновление информации в таблицe AllUserData портала по email

    $pquery = "UPDATE AllUserData
               SET nvarchar1=N'$pfullname',
                   nvarchar3=N'$pad_login',
                   nvarchar8=N'$pdepartment',
                   nvarchar9=N'$pposition',
                   nvarchar10=N'$pphones'
               WHERE nvarchar4=N'$memail'";
    #echo "$pquery<br>";
    $pquery = iconv("UTF-8", "WINDOWS-1251", $pquery);
    mssql_query($pquery, $portal);

# Этап 8 - обновление информации в таблицe UserInfo портала по email

    $pquery = "UPDATE UserInfo
               SET tp_Title=N'$p2fullname',
                   tp_Login=N'$p2ad_login'
               WHERE tp_Email=N'$memail'";
    #echo "$pquery<br>";
    $pquery = iconv("UTF-8", "WINDOWS-1251", $pquery);
    mssql_query($pquery, $portal);

# Этап 9 - обновление информации в таблицe AllUserData портала по ad_login

    $pquery = "UPDATE AllUserData
               SET nvarchar1=N'$p3fullname',
                   nvarchar3=N'$p3ad_login',
                   nvarchar4=N'$p3email',
                   nvarchar8=N'$p3department',
                   nvarchar9=N'$p3position',
                   nvarchar10=N'$p3phones'
               WHERE LOWER(nvarchar3)=LOWER(N'$mad_login')";
    #echo "$pquery<br>";
    $pquery = iconv("UTF-8", "WINDOWS-1251", $pquery);
    mssql_query($pquery, $portal);

# Этап 10 - обновление информации в таблицe UserInfo портала по ad_login

    $pquery = "UPDATE UserInfo
               SET tp_Title=N'$p4fullname',
                   tp_Email=N'$p4email',
                   tp_Login=N'$p4ad_login'
               WHERE LOWER(tp_Login)=LOWER(N'$mad_login')";
    #echo "$pquery<br>";
    $pquery = iconv("UTF-8", "WINDOWS-1251", $pquery);
    mssql_query($pquery, $portal);
  }

  mysql_free_result($mresult);
  mssql_close($portal);
}

function html_sync($link, $namespace, $template)
{
  $tpls = template_load($template);
  return $tpls['main'];
}

function act_sync($link)
{
  sync($link, isset($_POST['mode']) ? $_POST['mode'] : '');
  return '?view=sync';
}

?>
