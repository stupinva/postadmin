<?

# Выбор шаблона адреса для вывода в списке подписок
function email_select_template($tpls, $row, $odd)
{
  if (isset($row['user_id']) && ($row['user_id'] != ''))
    return $tpls['user']; 
  return $tpls['email'];
}

# Виджет редактирования информации о пользователе
function html_user($link, $namespace, $template)
{
  $tpls = template_load($template);
  $html = widget_form($link, $namespace, $tpls,
                      'SELECT COUNT(*) FROM user WHERE id=%id%',
                      'SELECT prev.id
                       FROM user AS prev
                       JOIN user ON prev.email < user.email
                         AND user.id=%id%
                       ORDER BY prev.email DESC
                       LIMIT 1',
                      'SELECT next.id
                       FROM user AS next
                       JOIN user ON next.email > user.email
                         AND user.id=%id%
                       ORDER BY next.email
                       LIMIT 1',
                      "SELECT id,
                              IF(active='Y', 'checked', '') AS active,
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
                       WHERE id=%id%",
                      'user_fields_filter');

  # Идентификатор редактируемого пользователя
  $id = isset($_GET["${namespace}_id"]) ? floor($_GET["${namespace}_id"]) : -1;

  # incoming_subscriptions - список подписок на входящие
  $rows = db_select_keyvals($link, "SELECT subscription.id AS id,
                                           subscription.email AS email,
                                           IFNULL(source.id,'') AS user_id,
                                           IFNULL(source.surname,'') AS surname,
                                           IFNULL(source.name,'') AS name,
                                           IFNULL(source.patronym,'') AS patronym
                                    FROM subscription
                                    JOIN user ON user.email=subscription.recipient AND user.id=$id
                                    LEFT JOIN user AS source ON source.email=subscription.email
                                    WHERE subscription.direction='I'");
  $html_incoming_subscriptions = widget_rows($tpls, $rows, 'email_select_template');

  # outgoing_subscriptions - список подписок на исходящие
  $rows = db_select_keyvals($link, "SELECT subscription.id AS id,
                                           subscription.email AS email,
                                           IFNULL(source.id,'') AS user_id,
                                           IFNULL(source.surname,'') AS surname,
                                           IFNULL(source.name,'') AS name,
                                           IFNULL(source.patronym,'') AS patronym
                                    FROM subscription
                                    JOIN user ON user.email=subscription.recipient AND user.id=$id
                                    LEFT JOIN user AS source ON source.email=subscription.email
                                    WHERE subscription.direction='O'");
  $html_outgoing_subscriptions = widget_rows($tpls, $rows, 'email_select_template');

  # incoming_recipients - список получателей копий входящих
  $rows = db_select_keyvals($link, "SELECT subscription.id AS id,
                                           subscription.recipient AS email,
                                           recipient.id AS user_id,
                                           recipient.surname AS surname,
                                           recipient.name AS name,
                                           recipient.patronym AS patronym
                                    FROM subscription
                                    JOIN user AS recipient ON recipient.email=subscription.recipient
                                    JOIN user ON user.email=subscription.email AND user.id=$id
                                    WHERE subscription.direction='I'");
  $html_incoming_recipients = widget_rows($tpls, $rows, 'email_select_template');

  # outgoing_recipients - список получателей копий исходящих
  $rows = db_select_keyvals($link, "SELECT subscription.id AS id,
                                           subscription.recipient AS email,
                                           recipient.id AS user_id,
                                           recipient.surname AS surname,
                                           recipient.name AS name,
                                           recipient.patronym AS patronym
                                    FROM subscription
                                    JOIN user AS recipient ON recipient.email=subscription.recipient
                                    JOIN user ON user.email=subscription.email AND user.id=$id
                                    WHERE subscription.direction='O'");
  $html_outgoing_recipients = widget_rows($tpls, $rows, 'email_select_template');

  $html = template_fill($html, array('%incoming_subscriptions%' => $html_incoming_subscriptions,
                                     '%outgoing_subscriptions%' => $html_outgoing_subscriptions,
                                     '%incoming_recipients%' => $html_incoming_recipients,
                                     '%outgoing_recipients%' => $html_outgoing_recipients));
  return $html;
}

# Редактирование подписок пользователя
function subscriptions_edit($link)
{
  $ids = isset($_POST['unsubscribe_ids']) ? $_POST['unsubscribe_ids'] : array();
  unsubscribe($link, $ids);

  $email = isset($_POST['email']) ? $_POST['email'] : '';
  $incoming_subscription = isset($_POST['incoming_subscription']) ? trim($_POST['incoming_subscription']) : '';
  $outgoing_subscription = isset($_POST['outgoing_subscription']) ? trim($_POST['outgoing_subscription']) : '';
  $incoming_recipient = isset($_POST['incoming_recipient']) ? trim($_POST['incoming_recipient']) : '';
  $outgoing_recipient = isset($_POST['outgoing_recipient']) ? trim($_POST['outgoing_recipient']) : '';

  if ($email != '')
  {
    if ($incoming_subscription != '')
      subscribe($link, $incoming_subscription, $email);
    if ($outgoing_subscription != '')
      subscribe($link, $outgoing_subscription, $email, FALSE);
    if ($incoming_recipient != '')
      subscribe($link, $email, $incoming_recipient);
    if ($outgoing_recipient != '')
      subscribe($link, $email, $outgoing_recipient, FALSE);
  }
}

# Редактирование пользователя
function act_user_edit($link)
{
  global $max_bytes_default;
  global $max_messages_default;
  global $smtp_acl_default;

  $id = isset($_POST['id']) ? trim($_POST['id']) : -1;

  $active = isset($_POST['active']);

  $password = isset($_POST['password']) ? trim($_POST['password']) : '';
  $password2 = isset($_POST['password2']) ? trim($_POST['password2']) : '';

  if ($password != $password2)
    error('Пароль и подтверждение пароля не совпадают!');

  $surname = isset($_POST['surname']) ? trim($_POST['surname']) : '';
  $name = isset($_POST['name']) ? trim($_POST['name']) : '';
  $patronym = isset($_POST['patronym']) ? trim($_POST['patronym']) : '';

  $department = isset($_POST['department']) ? trim($_POST['department']) : '';
  $position = isset($_POST['position']) ? trim($_POST['position']) : '';
  $phones = isset($_POST['phones']) ? trim($_POST['phones']) : '';
  $ad_login = isset($_POST['ad_login']) ? trim($_POST['ad_login']) : '';

  $max_bytes = isset($_POST['max_bytes']) ? $_POST['max_bytes'] : $max_bytes_default;
  $max_messages = isset($_POST['max_messages']) ? $_POST['max_messages'] : $max_messages_default;
  $smtp_acl = isset($_POST['smtp_acl']) ? trim($_POST['smtp_acl']) : $smtp_acl_default;

  subscriptions_edit($link);

  user_edit($link, $id, $active, $password, $surname, $name, $patronym, $department, $position, $phones, $ad_login, $max_bytes, $max_messages, $smtp_acl);

  return "?view=user&user_id=$id";
}

?>
