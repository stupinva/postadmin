<?

# Обработчик формы для создания пересылки
function act_subscribe($link)
{
  $email = isset($_POST['email']) ? $_POST['email'] : '';
  $recipient = isset($_POST['recipient']) ? $_POST['recipient'] : '';
  $incoming = isset($_POST['outgoing']) ? FALSE : TRUE;

  subscribe($link, $email, $recipient, $incoming);

  return '?view=subscriptions';
}

# Обработчик формы для удаления пересылки
function act_unsubscribe($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  unsubscribe($link, $ids);

  return '?view=subscriptions';
}

# Выбор шаблона строки в зависимости от того, является является ли адрес
# пересылки одновременно адресом какого-либо пользователя
function subscription_select_template($tpls, $row, $odd)
{
  if ($row['forwarder_id'] != '')
  {
    if ($row['forwarder_active'] == 'Y')
      $tpl = $odd ? 'row_fwd_odd' : 'row_fwd_even';
    else
      $tpl = $odd ? 'row_fwd_disabled_odd' : 'row_fwd_disabled_even';
  }
  else
    $tpl = $odd ? 'row_odd' : 'row_even';

  return $tpls[$tpl];
}

# Виджет вывода таблицы пересылок
function html_subscriptions($link, $namespace, $template)
{
  return widget_table($link, $namespace, template_load($template),
                      'SELECT COUNT(*) FROM subscription',
                      "SELECT subscription.id AS id,
                              subscription.email AS email,
                              subscription.recipient AS recipient,
                              IF(subscription.direction='I', 'Входящие', 'Исходящие') AS direction,
                              IFNULL(forwarder.id, '') AS forwarder_id,
                              forwarder.active AS forwarder_active,
                              user.id AS recipient_id,
                              user.surname AS surname,
                              user.name AS name,
                              user.patronym AS patronym
                       FROM subscription
                       JOIN user ON user.email=subscription.recipient
                       LEFT JOIN user AS forwarder ON forwarder.email=subscription.email
                       ORDER BY subscription.email",
                       'subscription_select_template',
                       '');
}

?>
