<?

# Настройки menu
global $menu;
$menu = array('domains' => 'Домены',
              'users' => 'Пользователи',
              'user_new' => 'Новый пользователь',
              'subscriptions' => 'Подписки',
              'smtp_acls' => 'Доступ',
              'sync' => 'Синхронизация');

function html_menu($link, $namespace, $template)
{
  global $view_default;
  global $menu;

  $view = isset($_GET['view']) ? $_GET['view'] : $view_default;
  $tpls = template_load($template);
  $html = '';
  foreach($menu as $key => $value)
    if ($key == $view)
      $html .= str_replace('%text%', $value, $tpls['menu_cur']);
    else
      $html .= template_fill($tpls['menu'], array('%url%' => "?view=$key",
                                                  '%text%' => $value));
  $html = str_replace('%menus%', $html, $tpls['main']);
  return $html;
}

?>
