<?

# Виджет выбора локальных доменов
function widget_select_domain($link, $template, $selected_domain)
{
  $domains = db_select($link, "SELECT domain
                               FROM domain
                               WHERE transport IN ('dovecot:', 'virtual:')");

  $html_domains = '';
  foreach($domains[0] as $domain)
  {
    if ($domain == $selected_domain)
      $selected = 'selected';
    else
      $selected = '';
    $html_domains .= template_fill($template, array('%domain%' => $domain,
                                                    '%selected%' => $selected));
  }
  return $html_domains;
}

# Виджет создания нового почтового ящика
function html_user_new($link, $namespace, $template)
{
  global $max_bytes_default;
  global $max_messages_default;
  global $domain_default;
  global $ad_domain_default;
  global $smtp_acl_default;

  # Поля формы, если они не указаны, заполняются пустыми строками
  # или значениями по умолчанию
  $_POST['active'] = isset($_POST['active']) ? $_POST['active'] : '';
  $_POST['surname'] = isset($_POST['surname']) ? $_POST['surname'] : '';
  $_POST['name'] = isset($_POST['name']) ? $_POST['name'] : '';
  $_POST['patronym'] = isset($_POST['patronym']) ? $_POST['patronym'] : '';
  $_POST['department'] = isset($_POST['department']) ? $_POST['department'] : '';
  $_POST['position'] = isset($_POST['position']) ? $_POST['position'] : '';
  $_POST['phones'] = isset($_POST['phones']) ? $_POST['phones'] : '';
  $_POST['domain'] = isset($_POST['domain']) ? $_POST['domain'] : $domain_default;
  $_POST['email'] = isset($_POST['email']) && ($_POST['email'] != '') ? $_POST['email'] :
    get_free_login($link, $_POST['domain'], $_POST['surname'], $_POST['name'], $_POST['patronym']);
  $_POST['ad_login'] = isset($_POST['ad_login']) && ($_POST['ad_login'] != '') ? $_POST['ad_login'] :
    $ad_domain_default . '\\' . $_POST['email'];
  $_POST['password'] = isset($_POST['password']) && ($_POST['password'] != '') ? $_POST['password'] : get_password();
  $_POST['max_bytes'] = isset($_POST['max_bytes']) ? $_POST['max_bytes'] : $max_bytes_default;
  $_POST['max_messages'] = isset($_POST['max_messages']) ? $_POST['max_messages'] : $max_messages_default;
  $_POST['smtp_acl'] = isset($_POST['smtp_acl']) ? trim($_POST['smtp_acl']) : $smtp_acl_default;

  # Грузим шаблон виджета
  $tpls = template_load($template);

  # Формируем виджет выбора домена
  $html_domains = widget_select_domain($link, $tpls['domains'], $_POST['domain']);

  # Заполняем страницу значениями полей
  $html = $tpls['main'];
  foreach($_POST as $key => $value)
    $html = str_replace("%$key%", htmlspecialchars($value), $html);

  return str_replace('%domains%', $html_domains, $html);
}

# Заполнение поля почтового ящика в форме создания пользователя первым свободным ящиком
# для указанного сочетания домена, фамилии, имени и отчества пользователя
function act_get_email($link)
{
  global $domain_default;

  $_POST['surname'] = isset($_POST['surname']) ? $_POST['surname'] : '';
  $_POST['name'] = isset($_POST['name']) ? $_POST['name'] : '';
  $_POST['patronym'] = isset($_POST['patronym']) ? $_POST['patronym'] : '';
  $_POST['domain'] = isset($_POST['domain']) ? $_POST['domain'] : $domain_default;
  $_POST['email'] = get_free_login($link, $_POST['domain'], $_POST['surname'], $_POST['name'], $_POST['patronym']);

  return '';
}

# Заполнение поля пароля в форме создания пользователя случайным паролем
function act_get_password($link)
{
  $_POST['password'] = get_password();
  return '';
}

# Создание нового пользователя
function act_user_new($link)
{
  global $domain_default;
  global $max_bytes_default;
  global $max_messages_default;
  global $smtp_acl_default;

  $active = isset($_POST['active']) ? trim($_POST['active']) : '';

  $email = isset($_POST['email']) ? trim($_POST['email']) : '';
  $domain = isset($_POST['domain']) ? trim($_POST['domain']) : $domain_default;
  $password = isset($_POST['password']) ? trim($_POST['password']) : '';

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

  user_new($link, $active, "$email@$domain", $password, $surname, $name, $patronym, $department, $position, $phones, $ad_login, $max_bytes, $max_messages, $smtp_acl);

  return '?view=users';
}

?>
