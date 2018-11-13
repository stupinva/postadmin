#!/bin/sh

echo "UPDATE user SET lasttime=NOW(), lastip='$IP' WHERE email='$USER';" | mysql -udovecot -pdovecot_password -h127.0.0.1 mail
exec /usr/lib/dovecot/imap "$@"

