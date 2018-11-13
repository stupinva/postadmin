<?

# Переход на страницу добавления нового пользователя
function act_go_user_new($link)
{
  return '?view=user_new';
}

# Удаление указанных пользователей
function act_users_remove($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  users_remove($link, $ids);
  return '?view=users';
}

# Отключение указанных пользователей
function act_users_disable($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  users_disable($link, $ids);
  return '?view=users';
}

# Включение указанных пользователей
function act_users_enable($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  users_enable($link, $ids);
  return '?view=users';
}

# Изменение квоты объёма для указанных пользователей
function act_users_change_max_bytes($link)
{
  global $max_bytes_default;

  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  $max_bytes = isset($_POST['max_bytes']) ? $_POST['max_bytes'] : $max_bytes_default;

  users_change_max_bytes($link, $ids, $max_bytes);
  return '?view=users';
}

# Изменение квоты количества сообщений для указанных пользователей
function act_users_change_max_messages($link)
{
  global $max_messages_default;

  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  $max_messages = isset($_POST['max_messages']) ? $_POST['max_messages'] : $max_messages_default;

  users_change_max_messages($link, $ids, $max_messages);
  return '?view=users';
}

# Обработчик формы для подписывания пользователей на рассылку
function act_users_subscribe($link)
{
  $email = isset($_POST['email']) ? $_POST['email'] : '';
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());
  $incoming = isset($_POST['outgoing']) ? FALSE : TRUE;

  users_subscribe($link, $email, $ids, $incoming);

  return '?view=users';
}

# Выбор шаблона адреса для вывода в списке подписок
function user_select_template($tpls, $row, $odd)
{
  if (isset($row['active']) && ($row['active'] == 'N'))
    return $odd ? $tpls['row_odd_disabled'] : $tpls['row_even_disabled'];
  return $odd ? $tpls['row_odd'] : $tpls['row_even'];
}

# Фильтр, добавляющий колонки квот в удобном для просмотра виде
function user_fields_filter($row)
{
  $row['hr_bytes'] = $row['max_bytes'] == 0 ?
                       to_hr_size($row['bytes']) :
                       round($row['bytes'] * 100 / $row['max_bytes']) . '%';

  $row['hr_messages'] = $row['max_messages'] == 0 ?
                          $row['messages'] :
                          round($row['messages'] * 100 / $row['max_messages']) . '%';

  $row['bytes'] = to_hr_size($row['bytes']);
  $row['max_bytes'] = to_hr_size($row['max_bytes']);

  return $row;
}

# Виджет вывода таблицы пользователей
function html_users($link, $namespace, $template)
{
  global $max_bytes_default;
  global $max_messages_default;

  $html = widget_table($link, $namespace, template_load($template),
                       'SELECT COUNT(*) FROM user',
                       "SELECT id,
                               active,
                               email,
                               surname,
                               name,
                               patronym,
                               department,
                               position,
                               phones,
                               ad_login,
                               IFNULL(lasttime, 'Никогда') AS lasttime,
                               IFNULL(lastip, '') AS lastip,
                               IFNULL(bytes, 0) AS bytes,
                               max_bytes,
                               IFNULL(messages, 0) AS messages,
                               max_messages,
                               smtp_acl
                        FROM user
                        ORDER BY email",
                       'user_select_template',
                       'user_fields_filter');

  return template_fill($html, array('%max_bytes_default%' => $max_bytes_default,
                                    '%max_messages_default%' => $max_messages_default));
}

?>
