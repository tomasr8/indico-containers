#!/bin/bash

. /opt/indico/.venv/bin/activate

connect_to_db() {
    psql -lqt | cut -d \| -f 1 | grep -qw $PGDATABASE
}

# Wait until the DB becomes available
connect_to_db
until [ $? -eq 0 ]; do
    echo "Waiting for DB to become available..."
    sleep 1
    connect_to_db
done

# Check whether the DB is already setup
psql -c 'SELECT COUNT(*) FROM events.events'

if [ $? -eq 1 ]; then
    echo 'Preparing DB...'
    echo 'CREATE EXTENSION unaccent;' | psql
    echo 'CREATE EXTENSION pg_trgm;' | psql
    indico db prepare
    echo 'Running initial setup...'
    python /opt/indico/run_initial_setup.py
fi

echo "Pulling translations..."
/opt/indico/pull_translations.sh

echo 'Compiling translations...'
indico i18n compile-catalog
indico i18n compile-catalog-react

echo 'Starting maildump...'
/root/.local/bin/maildump -n --http-ip 0.0.0.0 --http-port 60000 --db /tmp/maildump.sqlite --smtp-ip 127.0.0.1 --smtp-port 25 &

echo 'Starting Indico...'
uwsgi /etc/uwsgi.ini
