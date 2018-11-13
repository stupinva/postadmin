USE mysql;

INSERT INTO user(host, user, password) VALUES('localhost', 'dovecot', PASSWORD('dovecot_password'));

INSERT INTO tables_priv(host, db, user, table_name, table_priv, column_priv)
VALUES ('localhost', 'mail', 'dovecot', 'user', '', 'Select,Update');

INSERT INTO columns_priv(host, db, user, table_name, column_name, column_priv)
VALUES ('localhost', 'mail', 'dovecot', 'user', 'active', 'Select'),
       ('localhost', 'mail', 'dovecot', 'user', 'email', 'Select'),
       ('localhost', 'mail', 'dovecot', 'user', 'password', 'Select'),
       ('localhost', 'mail', 'dovecot', 'user', 'bytes', 'Select,Update'),
       ('localhost', 'mail', 'dovecot', 'user', 'max_bytes', 'Select'),
       ('localhost', 'mail', 'dovecot', 'user', 'messages', 'Select,Update'),
       ('localhost', 'mail', 'dovecot', 'user', 'max_messages', 'Select'),
       ('localhost', 'mail', 'dovecot', 'user', 'lasttime', 'Update'),
       ('localhost', 'mail', 'dovecot', 'user', 'lastip', 'Update');

FLUSH PRIVILEGES;
