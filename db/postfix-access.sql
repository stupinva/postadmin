USE mysql;

INSERT INTO user(host, user, password) VALUES('localhost', 'postfix', PASSWORD('postfix_password'));

INSERT INTO tables_priv(host, db, user, table_name, table_priv, column_priv)
VALUES ('localhost', 'mail', 'postfix', 'subscription', '', 'Select'),
       ('localhost', 'mail', 'postfix', 'domain', '', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', '', 'Select'),
       ('localhost', 'mail', 'postfix', 'smtp_acl', '', 'Select');

INSERT INTO columns_priv(host, db, user, table_name, column_name, column_priv)
VALUES ('localhost', 'mail', 'postfix', 'domain', 'domain', 'Select'),
       ('localhost', 'mail', 'postfix', 'domain', 'transport', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'active', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'email', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'password', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'bytes', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'max_bytes', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'messages', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'max_messages', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'lasttime', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'lastip', 'Select'),
       ('localhost', 'mail', 'postfix', 'user', 'smtp_acl', 'Select'),
       ('localhost', 'mail', 'postfix', 'smtp_acl', 'acl', 'Select'),
       ('localhost', 'mail', 'postfix', 'smtp_acl', 'address', 'Select'),
       ('localhost', 'mail', 'postfix', 'subscription', 'direction', 'Select'),
       ('localhost', 'mail', 'postfix', 'subscription', 'email', 'Select'),
       ('localhost', 'mail', 'postfix', 'subscription', 'recipient', 'Select');

FLUSH PRIVILEGES;
