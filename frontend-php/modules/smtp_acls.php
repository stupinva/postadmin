<?

function act_smtp_acl_new($link)
{
  $acl = isset($_POST['acl']) ? $_POST['acl'] : '';
  $address = isset($_POST['address']) ? $_POST['address'] : '';
  $description = isset($_POST['description']) ? $_POST['description'] : '';

  smtp_acl_new($link, $acl, $address, $description);

  return '?view=smtp_acls';
}

function act_smtp_acl_edit($link)
{
  $id = isset($_POST['id']) ? $_POST['id'] : -1;
  $acl = isset($_POST['acl']) ? $_POST['acl'] : '';
  $address = isset($_POST['address']) ? $_POST['address'] : '';
  $description = isset($_POST['description']) ? $_POST['description'] : '';

  smtp_acl_edit($link, $id, $acl, $address, $description);

  return "?view=smtp_acl&smtp_acl_id=$id";
}

function act_smtp_acls_remove($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  smtp_acls_remove($link, $ids);

  return '?view=smtp_acls';
}

function html_smtp_acls($link, $namespace, $template)
{
  global $smtp_acl_default;

  $html = widget_table($link, $namespace, template_load($template),
                       'SELECT COUNT(*) FROM smtp_acl',
                       'SELECT id,
                               acl,
                               address,
                               description
                        FROM smtp_acl
                        ORDER BY acl, address');

  return str_replace("%smtp_acl_default%", $smtp_acl_default, $html);
}

function html_smtp_acl($link, $namespace, $template)
{
  return widget_form($link, $namespace, template_load($template),
                     'SELECT COUNT(*) FROM smtp_acl WHERE id=%id%',
                     "SELECT prev.id
                      FROM smtp_acl AS prev
                      JOIN smtp_acl ON CONCAT(prev.acl, prev.address) < CONCAT(smtp_acl.acl, smtp_acl.address)
                        AND smtp_acl.id=%id%
                      ORDER BY prev.acl DESC, prev.address DESC
                      LIMIT 1",
                     "SELECT next.id
                      FROM smtp_acl AS next
                      JOIN smtp_acl ON CONCAT(next.acl, next.address) > CONCAT(smtp_acl.acl, smtp_acl.address)
                        AND smtp_acl.id=%id%
                      ORDER BY next.acl, next.address
                      LIMIT 1",
                     "SELECT id,
                             acl,
                             address,
                             description
                      FROM smtp_acl
                      WHERE id=%id%");
}

?>
