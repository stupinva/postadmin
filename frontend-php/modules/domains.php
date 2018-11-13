<?

function act_domain_new($link)
{
  $domain = isset($_POST['domain']) ? $_POST['domain'] : '';
  $transport = isset($_POST['transport']) ? $_POST['transport'] : '';

  domain_new($link, $domain, $transport);

  return '?view=domains';
}

function act_domain_edit($link)
{
  $id = isset($_POST['id']) ? $_POST['id'] : -1;
  $domain = isset($_POST['domain']) ? $_POST['domain'] : '';
  $transport = isset($_POST['transport']) ? $_POST['transport'] : '';

  domain_edit($link, $id, $domain, $transport);

  return "?view=domain_edit&domain_id=$id";
}

function act_domains_remove($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  domains_remove($link, $ids);

  return '?view=domains';
}

function act_domains_change_transport($link)
{
  $ids = isset($_POST['ids']) ? $_POST['ids'] :
    (isset($_POST['id']) ? array($_POST['id']) : array());

  $transport = isset($_POST['transport']) ? $_POST['transport'] : '';

  domains_change_transport($link, $ids, $transport);

  return '?view=domains';
}

function html_domains($link, $namespace, $template)
{
  return widget_table($link, $namespace, template_load($template),
                      'SELECT COUNT(*) FROM domain',
                      'SELECT id,
                              domain,
                              transport
                       FROM domain
                       ORDER BY domain');
}

function html_domain($link, $namespace, $template)
{
  return widget_form($link, $namespace, template_load($template),
                     'SELECT COUNT(*) FROM domain WHERE id=%id%',
                     "SELECT prev.id
                      FROM domain AS prev
                      JOIN domain ON prev.domain < domain.domain
                        AND domain.id=%id%
                      ORDER BY prev.domain DESC
                      LIMIT 1",
                     "SELECT next.id
                      FROM domain AS next
                      JOIN domain ON next.domain > domain.domain
                        AND domain.id=%id%
                      ORDER BY next.domain
                      LIMIT 1",
                     "SELECT id,
                             domain,
                             transport
                      FROM domain
                      WHERE id=%id%");
}

?>
