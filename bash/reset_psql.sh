#!/bin/bash

exedir="/usr/local/bin/"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba"
info="resetdb"

echo "[ $info ] restarting sql server"
$exedir/pg_ctl -D /usr/local/var/postgres restart

echo "[ $info ] reassessing whole db"
echo "[ $info ] disconnecting ev users..."

$RUN_ON_EV <<SQL
    SELECT pg_terminate_backend(pg_stat_activity.pid)
    FROM pg_stat_activity
    WHERE pg_stat_activity.datname = 'ev'
      AND pid <> pg_backend_pid();
SQL



