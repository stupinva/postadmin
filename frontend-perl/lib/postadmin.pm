package postadmin;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use utils;
use domains;
use users;
use subscriptions;
use smtp_acls;

our $VERSION = '0.1';

# Портирование PostAdmin на Perl, Dancer и HTML::Template начато 13-10-2012
# 13-10-2012 Портирован get domain
# 14-10-2012 Портирован get user, частично - user_new
# 20-10-2012 Узнал о Dancer::Plugin::Database и Dancer::Plugin::ValidateTiny
# 21-10-2012 Полностью портирован get/post user_new
# 03-11-2012 Добавлены и задействованы функции bytes2hr и hr2bytes
# 04-11-2012 Полностью портирован get smtp_acl
# 08-11-2012 Добавлен модуль widgets, реализованы и отлажены функции
#            widget_nums, widget_pages, widget_prev_next.
# 09-11-2012 Добавлена функция norm в widget_nums, widget_pages, widget_prev_next.
#            Полностью портированы get domains и get users
# 10-11-2012 Полностью портированы get subscriptions и get smtp_acls
#            Начато отделение представления от модели
# 16/17-11-2012 Создан модуль domains.pm, реализованы функции domain_new,
#               domain_edit, domains_remove, domains_change_transport.
#               Функции page_domains и page_domain переименованы в domains_page и
#               domain_page и внесены в модуль domains.pm
#               В модуле test.pm реализованы обработчики get и post для доменов
#               Таким образом, функции по работе с доменами готовы полностью
# 18-11-2012 Создан модуль users.pm, реализованы функции user_remove, users_remove,
#            users_change_max_bytes, users_change_max_messages, users_enable,
#            users_disable.
#            Функции page_user и page_users переименованы в user_page и users_page
#            и внесены в модуль users.pm
#            Создан модуль utils.pm, в который перенесены функции validate_domain,
#            validate_transport, join_ids, hr2bytes, bytes2hr
#            Добавлены обработчики post для страницы пользователей, за исключением
#            массовой подписки
#            Создан модуль subsriptions.pm, реализованы функции is_loop_subscription,
#            validate_subscription_on_loop, validate_email
# 26-11-2012 Доделана операция users_subscribe на странице users, сделана user_edit
#            на странице user_edit
# 01-12-2012 Доделана операция user_subscriptions_edit на странице user_edit
#            Сделана опреация users_remove на странице user_edit
# 02-12-2012 Все функции из navigation перенесены в utils, модуль navigation удалён
#            Функции валидации перенесены в соответствующие модули, модуль validation
#            удалён
#            В модуль utils добавлены функции field_text_default,
#            field_number_default, field_bytes_default
#            Во всех функциях к сообщению об ошибке добавлен символ новой строки,
#            а в случае успеха вместо undef возвращается пустая строка
#            Полностью готова страница user_new
# 06-12-2012 Полностью готова страница subscriptions
# 08-12-2012 Полностью готовы страницы smtp_acls и smtp_acl
#            Функции валидации данных вынесены в отдельный модуль
# 09-12-2012 Добавлены меню и сохранение-загрузка настроек страницы в cookies
#            Добавлена функция генерации страницы с сообщением об ошибке

# TODO:
# Добавить функции field_bool_default, field_inumber_default, field_unumber_default

hook 'before_template_render' => sub {
        my $params = shift;
        $params->{uri_base} = request->base->path;
    };

# С корневой страницы переадресуем на страницу со списком пользователей
get "/" => sub {
  redirect "/users";
};

# Загрузка настроек страницы, сохранённых в Cookie, если они не указаны
# Сохранение получившихся настроек в Cookie
sub prepare_settings($;$$$)
{
  my $page = shift;
  my $all = shift;
  my $base = shift;
  my $num = shift;

  $all = cookie($page . "_all") unless defined $all;
  $base = cookie($page . "_base") unless defined $base;
  $num = cookie($page . "_num") unless defined $num;
  
  cookie($page . "_all", field_number_default($all, 0));
  cookie($page . "_base", field_number_default($base, 0));
  cookie($page . "_num", field_number_default($num, 0));

  return ($all, $base, $num);
}

# ====== ДОМЕНЫ ======

# Страница редактирования домена
get "/domain/:id" => sub {
  my $id = param("id");

  my $params = domain_page($id);

  unless (defined $params)
  {
    status 404;
    return error_page("Объект не существует!");
  } 

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "");

  template "domain", $params;
};

# Страница обработки действий по редактированию домена
post "/domain/:id" => sub {
  my $id = param("id");

  my $error = "";

  # Редактирование домена
  if (defined param("domain_edit"))
  {
    $error = domain_edit($id, param("domain"), param("transport"));
  }
  # Удаление домена
  elsif (defined param("domains_remove"))
  {
    $error = domains_remove($id);
  }
  else
  {
    $error = "Неизвестное действие!";
  }

  return error_page($error) if $error;

  redirect "/domains";
};

# Страница со списком доменов
# Используются сохранённые настройки страницы или настройки по умолчанию
get "/domains" => sub {
  my ($all, $base, $num) = prepare_settings("domains");
  my $params = domains_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/domains");

  template "domains", $params;
};

# Страница со списком всех доменов
get "/domains/all" => sub {
  my ($all, $base, $num) = prepare_settings("domains", 1);
  my $params = domains_page($all, $base, $num);

  $params->{menu} = menu(config->{postadmin}->{menu}, "/domains");
  template "domains", $params;
};

# Страница со списком доменов, используются явно заданные настройки
get "/domains/:num/:base" => sub {
  my ($all, $base, $num) = prepare_settings("domains", 0, param("base"), param("num"));
  my $params = domains_page($all, $base, $num);

  $params->{menu} = menu(config->{postadmin}->{menu}, "/domains");
  template "domains", $params;
};

# Обработка действий страницы с таблицей доменов
sub domains_action($)
{
  my $url = shift;

  my $action = param("action");

  my $error = "";

  if (defined $action)
  {
    # Заводим новый домен
    if ($action eq "domain_new")
    {
      $error = domain_new(param("domain_new_domain"), param("domain_new_transport"));
    }
    # Удаляем отмеченные домены
    elsif ($action eq "domains_remove")
    {
      $error = domains_remove(param("ids[]"));
    }
    # Меняем транспорт отмеченных доменов
    elsif ($action eq "domains_change_transport")
    {
      $error = domains_change_transport(param("ids[]"), param("domains_change_transport_transport"));
    }
    else
    {
      $error = "Неизвестное действие!";
    }
  }
  else
  {
    $error = "Действие не указано!";
  }

  return error_page($error) if $error;

  redirect $url;
}

# Обработка действий на странице со списком всех доменов
post "/domains/all" => sub {
  domains_action("/domains/all");
};

# Обработка действий на странице со списком доменов 
post "/domains/:num/:base" => sub {
  my $num = param("num");
  my $base = param("base");

  domains_action("/domains/$num/$base");
};

# ====== ПОЛЬЗОВАТЕЛИ ======

# Страница редактирования пользователя
get "/user/:id" => sub {
  my $id = param("id");

  my $params = user_page($id);

  unless (defined $params)
  {
    status 404;
    return error_page("Объект не существует!");
  }

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "");

  template "user", $params;
};

# Обработка действий на странице редактирования пользователя
post "/user/:id" => sub {
  my $id = param("id");

  my $error = "";
  # Запрошено редактирование пользователя
  if (param("user_edit"))
  {
    # Редактируем данные самого пользователя
    $error = user_edit($id,
                       defined(param("active")) ? 1 : 0,
                       param("password"),
                       param("password2"),
                       param("surname"),
                       param("name"),
                       param("patronym"),
                       param("department"),
                       param("position"),
                       param("phones"),
                       param("ad_login"),
                       param("max_bytes"),
                       param("max_messages"),
                       param("smtp_acl"));

    # Редактируем подписки пользователя
    $error .= user_subscriptions_edit(param("unsubscribe_ids[]"),
                                      param("email"),
                                      param("incoming_subscription"),
                                      param("outgoing_subscription"),
                                      param("incoming_recipient"),
                                      param("outgoing_recipient"));
  }
  # Запрошено удаление пользователя
  elsif (param("users_remove"))
  {
    $error = users_remove($id);
  }
  else
  {
    $error = "Неизвестное действие!";
  }

  return error_page($error) if $error;

  redirect "/users";
};

# Страница заведения нового пользователя
any ["get", "post"] => "/user_new" => sub {
  my $password = param("password");
  my $email = param("email");

  # Если нужно сгенерировать новый пароль
  if (param("get_password"))
  {
    $password = get_password();
  }
  # Если нужно сгенерировать почтовый ящик
  elsif (param("get_email"))
  {
    $email = get_free_login(param("domain"),
                            param("surname"),
                            param("name"),
                            param("patronym"));
  }
  # Если нужно создать пользователя
  elsif (param("user_new"))
  {
    my $error = user_new(defined(param("active")) ? 1 : 0,
                         param("surname"),
                         param("name"),
                         param("patronym"),
                         param("department"),
                         param("position"),
                         param("phones"),
                         param("domain"),
                         param("email"),
                         param("ad_login"),
                         param("password"),
                         param("max_bytes"),
                         param("max_messages"),
                         param("smtp_acl"));

    return error_page($error) if $error;

    redirect "/users";
  }

  # Генерируем данные для отрисовки страницы с новым пользователем
  my $params = user_new_page(param("active"),
                             param("surname"),
                             param("name"),
                             param("patronym"),
                             param("department"),
                             param("position"),
                             param("phones"),
                             param("domain"),
                             $email,
                             param("ad_login"),
                             $password,
                             param("max_bytes"),
                             param("max_messages"),
                             param("smtp_acl"));

  # Добавляем данные для отрисовки меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/user_new");

  template "user_new", $params;
};

# Страница просмотра списка пользователей
# Используются настройки страницы по умолчанию или сохранённые настройки
get "/users" => sub {
  my ($all, $base, $num) = prepare_settings("users");
  my $params = users_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/users");
  template "users", $params;
};

# Страница просмотра списка всех пользователей
get "/users/all" => sub {
  my ($all, $base, $num) = prepare_settings("users", 1);
  my $params = users_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/users");
  template "users", $params;
};

# Страница просмотра списка пользователей с явно заданными настройками страницы
get "/users/:num/:base" => sub {
  my ($all, $base, $num) = prepare_settings("users", 0, param("base"), param("num"));
  my $params = users_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/users");
  template "users", $params;
};

# Обработка действий на странице со списком пользователей
sub users_action($)
{
  my $url = shift;

  my $action = param("action");

  my $error = "";

  if (defined $action)
  {
    # Выбрано заведение нового пользователя
    if ($action eq "go_user_new")
    {
      return redirect "/user_new";
    }
    # Запрошено удаление отмеченных пользователей
    elsif ($action eq "users_remove")
    {
      $error = users_remove(param("ids[]"));
    }
    # Запрошено изменение квоты объёма почтового ящика отмеченных пользователей
    elsif ($action eq "users_change_max_bytes")
    {
      $error = users_change_max_bytes(param("ids[]"),
                                      param("users_change_max_bytes_max_bytes"));
    }
    # Запрошено изменение квоты количества сообщений в почтовом ящике у отмеченных пользователей
    elsif ($action eq "users_change_max_messages")
    {
      $error = users_change_max_messages(param("ids[]"),
                                         param("users_change_max_messages_max_messages"));
    }
    # Запрошено включение почтового ящика пользователя
    elsif ($action eq "users_enable")
    {
      $error = users_enable(param("ids[]"));
    }
    # Запрошено отключение почтового ящика пользователя
    elsif ($action eq "users_disable")
    {
      $error = users_disable(param("ids[]"));
    }
    # Запрошено добавление подписки отмеченных пользователей на указанный источник сообщений
    elsif ($action eq "users_subscribe")
    {
      $error = users_subscribe(param("users_subscribe_email"),
                               param("ids[]"),
                               defined(param("users_subscribe_outgoing")) ? 0 : 1);
    }
    else
    {
      $error = "Неизвестное действие!";
    }
  }
  else
  {
    $error = "Действие не указано!";
  }

  return error_page($error) if $error;

  redirect $url;
}

# Обработка действий на странице со списком пользователей
post "/users" => sub {
  users_action("/users");
};

# Обработка действий на странице со списком всех пользователей
post "/users/all" => sub {
  users_action("/users/all");
};

# Обработка действий на странице со списком пользователей, когда указаны явные настройки страницы
post "/users/:num/:base" => sub {
  my $num = param("num");
  my $base = param("base");

  users_action("/users/$num/$base");
};

# ====== ПОДПИСКИ ======

# Страница со списком подписок
# Используются настройки страницы по умолчанию или запомненные настройки страницы
get "/subscriptions" => sub {
  my ($all, $base, $num) = prepare_settings("subscriptions");
  my $params = subscriptions_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/subscriptions");
  template "subscriptions", $params;
};

# Страница со списком всех подписок
get "/subscriptions/all" => sub {
  my ($all, $base, $num) = prepare_settings("subscriptions", 1);
  my $params = subscriptions_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/subscriptions");
  template "subscriptions", $params;
};

# Страница со списком подписок с явно заданными настройками страницы
get "/subscriptions/:num/:base" => sub {
  my ($all, $base, $num) = prepare_settings("subscriptions", 0, param("base"), param("num"));
  my $params = subscriptions_page($all, $base, $num);

  $params->{menu} = menu(config->{postadmin}->{menu}, "/subscriptions");
  template "subscriptions", $params;
};

# Обработка действий по редакитрованию подписок
sub subscriptions_action($)
{
  my $url = shift;

  my $action = param("action");

  my $error = "";

  if (defined $action)
  {
    # Запрошено добалвение новой подписки
    if ($action eq "subscribe")
    {
      $error = subscribe(param("subscribe_email"),
                         param("subscribe_recipient"),
                         defined(param("subscribe_outgoing")) ? 0 : 1);
    }
    # Зарпошено удаление отмеченных подписок
    elsif ($action eq "unsubscribe")
    {
      $error = unsubscribe(param("ids[]"));
    }
    else
    {
      $error = "Неизвестное действие!";
    }
  }
  else
  {
    $error = "Действие не указано!";
  }

  return error_page($error) if $error;

  redirect $url;
}

# Обработка действий на странице с полным списком подписок
post "/subscriptions/all" => sub {
  subscriptions_action("/subscriptions/all");
};

# Обработка действий на странице со списком подписок, когда указаны явные настройки страницы
post "/subscriptions/:num/:base" => sub {
  my $num = param("num");
  my $base = param("base");

  subscriptions_action("/subscriptions/$num/$base");
};

# ====== СПИСКИ ДОСТУПА ======

# Страница редактирования правила доступа
get "/smtp_acl/:id" => sub {
  my $id = param("id");

  my $params = smtp_acl_page($id);

  unless (defined $params)
  {
    status 404;
    return error_page("Объект не существует!");
  } 

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "");

  template "smtp_acl", $params;
};

# Обработка действий на странице редактирования правил доступа
post "/smtp_acl/:id" => sub {
  my $id = param("id");

  my $error = "";
  # Запрошено редактирование правила
  if (param("smtp_acl_edit"))
  {
    $error = smtp_acl_edit($id,
                       param("acl"),
                       param("address"),
                       param("description"));
  }
  # Запрошено удаление правила
  elsif (param("smtp_acls_remove"))
  {
    $error = smtp_acls_remove($id);
  }
  else
  {
    $error = "Неизвестное действие!";
  }

  return error_page($error) if $error;

  redirect "/smtp_acls";
};

# Страница со списком правил доступа
# Используются настройки отображения страницы по умолчанию или сохранённые настройки
get "/smtp_acls" => sub {
  my ($all, $base, $num) = prepare_settings("smtp_acls");
  my $params = smtp_acls_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/smtp_acls");
  template "smtp_acls", $params;
};

# Страница со списком всех правил доступа
get "/smtp_acls/all" => sub {
  my ($all, $base, $num) = prepare_settings("smtp_acls", 1);
  my $params = smtp_acls_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/smtp_acls");
  template "smtp_acls", $params;
};

# Страница просмотра списка правил доступа, если настройки страницы указаны явно
get "/smtp_acls/:num/:base" => sub {
  my ($all, $base, $num) = prepare_settings("smtp_acls", 0, param("base"), param("num"));
  my $params = smtp_acls_page($all, $base, $num);

  # Добавляем меню
  $params->{menu} = menu(config->{postadmin}->{menu}, "/smtp_acls");
  template "smtp_acls", $params;
};

# Обработка действий со страницы со списком правил доступа
sub smtp_acls_action($)
{
  my $url = shift;

  my $action = param("action");

  my $error = "";

  if (defined $action)
  {
    # Запрошено создание нового правила
    if ($action eq "smtp_acl_new")
    {
      $error = smtp_acl_new(param("smtp_acl_new_acl"),
                            param("smtp_acl_new_address"),
                            param("smtp_acl_new_description"));
    }
    # Запрошено удаление отмеченных правил доступа
    elsif ($action eq "smtp_acls_remove")
    {
      $error = smtp_acls_remove(param("ids[]"));
    }
    else
    {
      $error = "Неизвестное действие!";
    }
  }
  else
  {
    $error = "Действие не указано!";
  }

  return error_page($error) if $error;

  redirect $url;
}

# Обработка действий по редактированию правил со страницы просмотра всех правил доступа
post "/smtp_acls/all" => sub {
  smtp_acls_action("/smtp_acls/all");
};

# Обработка действий по редактированию правил на странице просмотра правил доступа с явно указанными настройками
post "/smtp_acls/:num/:base" => sub {
  my $num = param("num");
  my $base = param("base");

  smtp_acls_action("/smtp_acls/:num/:base");
};

true;
