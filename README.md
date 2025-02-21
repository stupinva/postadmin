Postadmin - веб-приложение для управления почтовой системой
===========================================================

Вы можете спросить: "Чем оно лучше PostfixAdmin?" У этих программ разное назначение. Если вам нужно средство для управления почтовым хостингом, то PostfixAdmin для вас. Если же вам нужно средство управления корпоративным почтовым сервером, то я считаю свою программу более подходящей для этого.

Чего нет в моей программе, в отличие от PostfixAdmin:
Разделения привилегий различных пользователей. Пользователь имеет только одни привилегии - администратора, а ограничение доступа делается средствами веб-сервера.
* Нет квот на количество почтовых ящиков и нет квот на количество псевдонимов.
* Нет настроек для сбора почты со внешних почтовых ящиков (fetchmail).
* Нет настроек отсылки уведомлений об отсутствии пользователя (vacation).
* Нет псевдонимов для доменов.

Что есть в моей программе такого, чего нет в PostfixAdmin:
* Управление списками рассылок/псевдонимами/подписками (bcc) - в Postfixadmin есть только управление псевдонимами. Все эти функции совмещены в пределах одной таблицы и их удобно редактировать прямо со страницы почтового ящика.
* Управление "чёрным списком" отправителей, почта от которых не принимается.
* Управление "белым списком" адресатов, отправлять почту которым может пользователь с ограничениями на отправку. Отдельная категория доступа на отправку - это возможность отправлять на любые внешние адреса.
* Синхронизация справочной информации с MS SharePoint Services 3.0 (только в варианте на PHP).
* Управление произвольными списками ограничений (при изменении конфигурации самого Postfix).

Ну и кроме того:
* В моей программе шаблоны HTML-страниц лежат отдельно, поэтому дизайн программы не прибит к ней гвоздями и его можно менять.
* По идее, в мою программу проще добавить новую функциональность, т.к. для создания новых виджетов есть типовые функции.

Более наглядное представление о программе вы можете составить по снимкам веб-страниц приложения, которые можно найти по ссылке [Веб-интерфейс Postadmin для управления почтовым сервером](https://vladimir-stupin.blogspot.com/2012/03/postadmin.html)

Имеется вариант этой программы, переписанный на Perl с использованием шаблонизатора HTML::Template и фреймворка Dancer. Вариант на Perl называется Postadmin 2.

В примерах файлов конфигурации и скриптах используются следующие значения по умолчанию:
* 127.0.0.1 - компьютер с MySQL, где хранится вся информация,
* mail - имя базы данных MySQL, где хранится вся информация,
* dovecot - имя пользователя MySQL для Dovecot,
* dovecot_password - пароль пользователя MySQL для Dovecot,
* postfix - имя пользователя MySQL для Postfix,
* postfix_password - пароль пользователя MySQL для Postfix

Советую как минимум поменять пароли пользователей postfix, dovecot, от имени которых работают соответствующие приложения. В файлах конфигурации веб-приложений стоит также поменять пароль пользователя mail, от имени которого веб-приложение работает с базой данных.

Каталог frontend-php
--------------------

Здесь находится веб-приложение, написанное на PHP. Приложение можно поделить на ядро, модули и шаблоны HTML-страниц. Ядро приложения написано в обобщённом виде и представляет собой что-то вроде примитивного фреймворка, функциональность которого используется модулями. Специфичная функциональность приложения реализована в виде модулей, которые можно найти в каталоге modules. Наконец, шаблоны веб-страниц, используемых модулями, можно найти в каталоге tpls.

Настройки веб-приложения можно найти в следующих файлах:
* settings.php
* modules/libmail.php
* modules/sync.php

Каталог frontend-perl
---------------------

Здесь находится веб-приложение, переписанное на Perl с использованием веб-фреймворка Dancer и шаблонизатора HTML::Template. В отличие от варианта на PHP, у этого приложения отсутствует модуль синхронизации с порталом Microsoft SharePoint Services 3.0. Это приложение также было известно под именем Postadmin 2. Т.к. оба приложения используют одинаковую конфигурацию почтовой системы, я решил объединить оба приложения в один репозиторий.

Настройки приложения находятся в файле config.yml.

В корневом каталоге проекта можно найти файл lighttpd.conf для настройки веб-сервера Lighttpd для работы с этим приложением.

Каталог db
----------

Для создания структуры БД и раздачи прав пользователям postfix и dovecot, можно воспользоваться файлами из каталога db:
* scheme.sql - создание структуры БД для программы.
* scheme-optional.sql - создание таблицы сессий в БД для программы. Не обязательно, т. к. используется модулем libsession.php. Поскольку модуль не задействован, то и таблица не обязательна.
* postfix-access.sql - назначение прав доступа к таблицам пользователю postfix.
* dovecot-access.sql - назначение прав доступа к таблицам пользователю dovecot.

Два последних файла настраивают ограниченные права доступа к таблицам и колонкам базы данных. Выдаются только те права, которые нужны каждому из приложений для работы, но не более того. Столбец table_priv в таблице tables_priv содержит те привилегии, для которых не будет проверяться доступ к столбцам, привилегии действуют на всю таблицу. Столбец column_priv в таблице tables_priv содержит те привилегии, для которых будет проверяться доступ к столбцам по таблице columns_priv.

Каталог crontab
---------------

В этом каталоге находятся периодически выполняемые скрипты, вызов которых нужно поместить в файл конфигурации планировщика задач - /etc/crontab:
* remove_unused.pl - удаление неиспользуемых почтовых ящиков с копированием новой почты текущим подписчикам этого адреса
* recalc_quotas.pl - пересчёт квот почтовых ящиков (нужно запускать после remove_unused.pl)

Каталог dovecot 
---------------

В каталоге dovecot содержатся файлы конфигурации dovecot, которые нужно поместить в каталог /etc/dovecot:
* dovecot.conf - файл /etc/dovecot/dovecot.conf
* dovecot-mysql.conf - файл /etc/dovecot/dovecot-mysql.conf
* dovecot-dict-mysql.conf - файл /etc/dovecot/dovecot-dict-mysql.conf
* pop-update-lastlog.sh - отслеживание IP-адреса аутентифицированного POP3-клиента для реализации аутентификации POP3 before SMTP
* imap-update-lastlog.sh  - отслеживание IP-адреса аутентифицированного IMAP-клиента для реализации аутентификации IMAP before SMTP

Каталог postfix
---------------

В этом каталоге находятся файлы конфигурации postfix, которые нужно поместить в каталог /etc/postfix:
* main.cf - главный файл конфигурации,
* mysql/pop-before-smtp.cf - проверка, аутентифицировался ли клиент перед отправкой на POP3 или IMAP-сервере
* mysql/quota.cf - проверка квоты адресата
* mysql/sender_blacklist.cf - чёрный список отправителей, почта от которых не принимается
* mysql/transport.cf - транспорты для доменов
* mysql/user.cf - пользователи

Следующие три файла управляют подписками и списками рассылок:
* mysql/recipient_bcc.cf - список получателей копий входящей почты пользователя
* mysql/sender_bcc.cf - список получателей копий исходящей почты пользователя
* mysql/subscription.cf - список получателей рассылки или подписчиков почты отключенного пользователя

Следующие два файла определяют группу доступа пользователя на отправку и список разрешённых адресатов для тех пользователей, у которых имеется ограниченный доступ на отправку:
* mysql/user_acl.cf - группа доступа на отправку для пользователя
* mysql/recipient_whitelist.cf - белый список адресов, на которые могут отправлять пользователи с ограничениями на отправку

Таблица подписок управляет одновременно следующими функциями:
* Отправка теневых копий входящей почты одному или нескольким адресатам, в случае если в колонке direction='I' и пользователь, одноимённый с адресом рассылки активен
* Отправка теневых копий исходящей почты одному или нескольким адресатам, в случае если в колонке direction='O' и пользователь, одноимённый с адресом рассылки активен
* Подписка на входящую почту отключенного пользователя, в случае если в колонке direction='I' и пользователь, одноимённый с адресом рассылки существует, но отключен
* Списки рассылок, в случае если в колонке direction='I' и пользователь, одноимённый с адресом рассылки не существует
* Альтернативные адреса пользователя (частный случай предыдущего), в случае если в колонке direction='I' и пользователь, одноимённый с адресом рассылки не существует, подписчик только один

Ограничение доступа на отправку для пользователей осуществляется следующим образом:
* если у пользователя настроен smtp_acl='permit_auth', то он может отправлять почту кому угодно
* если у пользователя настроен smtp_acl='permit_whitelist_auth', то он может отправлять почту только на домены и адреса из списка permit_whitelist_auth

Есть также отдельный список доступа reject_blacklist_sender, почта от доменов и адресов из которого не принимается вообще.

Можно создавать дополнительные произвольные списки управления доступом, нужно лишь указать в конфигурации Postfix, как поступать с адресами из этого списка.

Лицензия
--------

Программа была написана в 2011 году, впервые опубликована в 2012 году. В том же 2012 году программа была переписана на Perl с использованием веб-фреймворка Dancer и шаблонизатора HTML::Template. Обе программы оформлены в виде репозитория git в 2018 году.

(C) 2011-2018 Владимир Ступин

Программа распространяется под лицензией GPL 3.
