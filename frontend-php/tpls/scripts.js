function showhide(form_name)
{
  form = document.getElementsByName(form_name);
  for(i = 0; i < form[0].action.length; i++)
  {
    if (form[0].action[i].checked == true)
    {
      display = '';
    }
    else
    {
      display = 'none';
    }
    if (document.getElementById(form[0].action[i].value + '_input'))
    {
      document.getElementById(form[0].action[i].value + '_input').style.display = display;
    }
  }
}

function all_checkboxes(name, value)
{
  cbs = document.getElementsByName(name);
  for(i = 0; i < cbs.length; i++)
  {
    cbs[i].checked = value;
  }
}

function unhide_if_js_enabled(id)
{
  obj = document.getElementById(id);
  if (obj)
  {
    obj.style.display = '';
  }
}

function parse_get()
{
  var tmp = new Array();
  var tmp2 = new Array();
  var param = new Array();
 
  var get = location.search;
  if (get != '')
  {
    tmp = (get.substr(1)).split('&');
    for(var i = 0; i < tmp.length; i++)
    {
      tmp2 = tmp[i].split('=');
      param[tmp2[0]] = unescape(tmp2[1]);
    }
  }
  return param;
}

function department_select_window(form_name)
{
  var win = window.open('?view=department_select&js_form=' + form_name,
                        'department_select',
                        'height=600,width=600,menubar=no,toolbar=no,location=no,directories=no,status=no,resizable=yes,scrollbars=yes');
  win.focus();
}

function department_select(id, department)
{
  var param = parse_get();
  forms = this.window.opener.document.getElementsByName(param['js_form']);
  forms[0].department_id.value = id;
  forms[0].department.value = department;
  this.window.close();
}

function domain_select_window(form_name)
{
  var win = window.open('?view=domain_select&js_form=' + form_name,
                        'domain_select',
                        'height=600,width=600,menubar=no,toolbar=no,location=no,directories=no,status=no,resizable=yes,scrollbars=yes');
  win.focus();
}

function domain_select(id, department)
{
  var param = parse_get();
  forms = this.window.opener.document.getElementsByName(param['js_form']);
  forms[0].domain_id.value = id;
  forms[0].domain.value = department;
  this.window.close();
}

function user_select_window(form_name)
{
  var win = window.open('?view=user_select&js_form=' + form_name,
                        'user_select',
                        'height=900,width=1000,menubar=no,toolbar=no,location=no,directories=no,status=no,resizable=yes,scrollbars=yes');
  win.focus();
}

function user_select(id, surname, name, patronym)
{
  var param = parse_get();
  forms = this.window.opener.document.getElementsByName(param['js_form']);
  forms[0].user_id.value = id;
  forms[0].surname.value = surname;
  forms[0].name.value = name;
  forms[0].patronym.value = patronym;
  this.window.close();
}

function login_select_window(form_name, user_id, domain_id)
{
  var query = '';
  if (domain_id == '')
  {
    query = '?view=login_select&js_form=' + form_name + '&login_user_id=' + user_id;
  }
  else
  {
    query = '?view=login_select&js_form=' + form_name + '&login_user_id=' + user_id + '&login_domain_id=' + domain_id;
  }
  var win = window.open(query,
                        'login_select',
                        'height=320,width=320,menubar=no,toolbar=no,location=no,directories=no,status=no,resizable=yes,scrollbars=yes');
  win.focus();
}

function login_select(login)
{
  var param = parse_get();
  forms = this.window.opener.document.getElementsByName(param['js_form']);
  forms[0].email.value = login;
  this.window.close();
}

function password_select_window(form_name)
{
  var win = window.open('?view=password_select&js_form=' + form_name,
                        'password_select',
                        'height=320,width=320,menubar=no,toolbar=no,location=no,directories=no,status=no,resizable=yes,scrollbars=yes');
  win.focus();
}

function password_select(password)
{
  var param = parse_get();
  forms = this.window.opener.document.getElementsByName(param['js_form']);
  forms[0].password.value = password;
  forms[0].password2.value = password;
  this.window.close();
}
