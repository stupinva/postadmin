package utils;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(join_ids
                 hr2bytes
                 bytes2hr
                 field_text_default
                 field_number_default
                 field_bytes_default
                 navigation
                 menu
                 error_page);
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Math::Round qw/round/;
use constant qw{num_default => 25};

# Принимает один идентификатор или ссылку на массив идентификаторов
# Возвращает строку с идентификаторами, разделёнными запятыми
sub join_ids($)
{
  my $ids = shift;

  if (ref($ids) eq "ARRAY")
  {
    $ids = join ',', map { int } @{$ids};
  }
  elsif (ref($ids) eq "")
  {
    $ids = field_text_default($ids, "");
    $ids = int($ids) if $ids;
  }
  else
  {
    $ids = "";
  }

  return $ids;
}

# Пересчёт байтов из человекочитаемой формы
sub hr2bytes($)
{
  my $hr_bytes = shift || 0;

  my %mults = ("k" => 1024,
               "m" => 1048576,
               "g" => 1073741824,
               "t" => 1099511627776,
               "к" => 1024,
               "м" => 1048576,
               "г" => 1073741824,
               "т" => 1099511627776);

  # Если строка похожа на человеко-читаемый объем, пытаемся его пересчитать
  if ($hr_bytes =~ m/^\s*(\d*[.,]?\d+)([TGMKТМГК]?)[BБ]?\s*$/i)
  {
    my $bytes = $1;
    my $mult = $2;
    $bytes =~ s/,/./;

    # Если нашёлся буквенный множитель, переводим его в численный
    if ($mult)
    {
      $mult = $mults{lc($mult)};
    }
    else
    {
      $mult = 1;
    }

    # Возвращаем целый результат умножения
    return round($bytes * $mult);
  }

  return 0;
}

# Пересчёт байтов в человекочитаемую форму
sub bytes2hr($)
{
  my $bytes = shift || 0;

  my @mults = ([1099511627776 , "T"],
               [1073741824 , "G"],
               [1048576 , "M"],
               [1024 , "k"]);

  # Перебираем множители и их буквы
  foreach my $row (@mults)
  {
    my ($mult, $char) = @{$row};

    # Если объём больше множителя, возвращаем объём
    if ($bytes >= $mult)
    {
      $bytes /= $mult;
      $bytes = round($bytes * 10) / 10;
      return $bytes . $char . "b";
    }
    # Иначе - пробуем меньший множитель
  }

  return round($bytes);
}

# Чистка текстового поля и, при необходимости, заполнение занчением по умолчанию
sub field_text_default($$)
{
  my $value = shift || "";
  my $default = shift || "";

  $value =~ s/^\s+//;
  $value =~ s/\s+$//;

  return $value || $default;
}

# Чистка числового поля и, при необходимости, заполнение занчением по умолчанию
sub field_number_default($$)
{
  my $value = shift;
  my $default = shift;

  if (defined $default)
  {
    $default =~ s/^\s+//;
    $default =~ s/\s+$//;
  }
  else
  {
    $default = 0;
  }

  return $default unless defined $value;

  $value =~ s/^\s+//;
  $value =~ s/\s+$//;

  return $default if $value eq "";

  return $value;
}

# Чистка поля объёма памяти и, при необходимости, заполнение занчением по умолчанию
sub field_bytes_default($$)
{
  my $value = shift;
  my $default = shift;

  return hr2bytes(field_number_default($value, $default));
}


# Пересчёт номера первой строки на странице
sub navigation_norm($$$)
{
  my $base = field_number_default(shift, 0);
  my $num = field_number_default(shift, config->{navigation}->{num});
  my $total = field_number_default(shift, 0);

  # Корректируем количество строк на странице
  if ($num <= 0)
  {
    $num = field_number_default(config->{navigation}->{num}, num_default);
  }
  
  # Вычисляем первую страницу
  if (($base < 0) || ($total == 0))
  {
    $base = 0;
  }
  # Вычисляем последнюю страницу
  elsif ($base + $num >= $total)
  {
    my $last = $total % $num;
    $last = $num if $last == 0;
    $base = $total - $last;
  }

  return ($base, $num, $total); 
}

# Данные для шаблона виджета выбора количества отображаемых на одной странице строк таблицы
sub navigation_nums($$$$)
{
  my $all = shift;
  my $base = shift;
  my $num_cur = shift;
  my $total = shift;

  my @nums = ();

  my $config_nums = config->{navigation}->{nums};
  # Умолчальные значения на случай, если настройки модуля не заданы
  if ((!defined $config_nums) || (scalar(@{$config_nums}) == 0))
  {
    $config_nums = [25, 50, 75, 100, 200, 300, 400, 500, 750, 1000];
  }

  # Перебираем возможное количество строк для отображения на одной странице
  foreach my $num (@{$config_nums})
  {
    # Если количество в выборе превышает общее количество строк в таблице,
    # то этот выбор не показываем
    next if $num >= $total;

    push(@nums, {num => $num,
                 cur => ($num == $num_cur),
                 base => ($base - $base % $num)});
  }
  return \@nums;
}

# Данные для шаблона виджета выбора номера страницы отображаемых строк таблицы
sub navigation_pages($$$$)
{
  my $all = shift;
  my $base_cur = shift;
  my $num = shift;
  my $total = shift;

  my @pages = ();

  # На странице показывается часть строк
  if (!$all)
  {
    # Перебираем номера начальных строк таблицы на каждой странице
    # и номера страниц
    for(my $base = 0, my $page = 1; $base < $total; $base += $num, $page++)
    {
      push(@pages, {page => $page,
                    cur => (($base_cur >= $base) && ($base_cur < $base + $num)),
                    base => $base});
    }
  }
  return \@pages;
}

# Данные для шаблона виджета листания страниц вперёд и назад
sub navigation_prev_next($$$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;
  my $total = shift;

  # Вычисляем номер начальной строки для предыдущей страницы
  my $prev = $base - $num;

  # Если номер начальной строки оказался отрицательным, обнуляем его
  $prev = 0 if $prev < 0;

  # Если отображаются все строки таблицы
  # или сейчас и так отображается первая страница,
  # то предыдущей страницы нет
  my $no_prev = 0;
  $no_prev = 1 if $prev == $base;
  $no_prev = 1 if $all;

  # Вычисляем номер начальной строки для следующей страницы
  my $next = $base + $num;

  # Если номер начальной строки ушёл за пределы таблицы
  if ($next > $total)
  {
    $next = $total - $total % $num;
  }
  elsif ($next == $total)
  {
    $next = $total - $num;
  }

  # Если отображаются все строки таблицы
  # или сейчас и так отображается последняя страница,
  # то следующей страницы нет
  my $no_next = 0;
  $no_next = 1 if $next == $base;
  $no_next = 1 if $all;

  return {no_prev => $no_prev,
          prev => $prev,
          no_next => $no_next,
          next => $next};
}

# Данные для виджетов навигации по страницам таблицы
sub navigation($$$$)
{
  my $all = shift;
  my $base = shift;
  my $num = shift;
  my $total = shift;
  
  ($base, $num, $total) = navigation_norm($base, $num, $total);

  my $nums = navigation_nums($all, $base, $num, $total);
  my $pages = navigation_pages($all, $base, $num, $total);
  my $prev_next = navigation_prev_next($all, $base, $num, $total);

  # Вычисляем количество действительно показанных на странице строк
  my $onpage = $num;
  if ($all)
  {
    $onpage = $total;
  }
  elsif ($base + $num > $total)
  {
    $onpage = $total - $base;
  }

  return {all => $all,
          num => $num,
          onpage => $onpage,
          total => $total,
          nums => $nums,
          pages => $pages,
          base => $base,
          %{$prev_next}};
}

# Возращает данные для виджета меню
sub menu($$)
{
  my $menu = shift;
  my $current_url = shift;

  my @params = ();

  if ((defined $menu) && (scalar @{$menu}))
  {
    foreach my $point (@{$menu})
    {
      push(@params, {url => $point->{url},
                     text => $point->{text},
                     current => ($point->{url} eq $current_url ? 1 : 0)})
    }
  }

  return \@params;
}

# Функция вывода сообщения об ошибке по шаблону
sub error_page($)
{
  my $error = shift;

  $error = "Произошла не описанная ошибка." unless $error;

  # Разбивка строк ошибки с многострочным описанием
  my @errors = ();
  foreach my $error_line (split('\n', $error))
  {
    push(@errors, { error => $error_line });
  }

  template "error", { errors => \@errors };
}

1;
