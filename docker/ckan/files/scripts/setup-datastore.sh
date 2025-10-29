#!/bin/bash
set -e

# DB_USERNAME and DB_PASSWORD are the root PSQL users
echo "Starting Datastore Setup"
cd $APP_DIR

# load env vars from ${APP_DIR}/.env
set -o allexport
. ${APP_DIR}/.env
set +o allexport

export PGPASSWORD=$DB_PASSWORD
# Create the CKAN DB, there is no psql_user
echo "Creating CKAN database if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database 'ckan' already exists"

echo "Creating datastore read user if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE USER $DATASTORE_READ_USERNAME WITH PASSWORD '$DATASTORE_READ_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE;" || echo "User '$DATASTORE_READ_USERNAME' already exists"
echo "Creating datastore write user if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE USER $DATASTORE_WRITE_USERNAME WITH PASSWORD '$DATASTORE_WRITE_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE;" || echo "User '$DATASTORE_WRITE_USERNAME' already exists"

echo "Creating datastore db if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE DATABASE $DATASTORE_DB_NAME;" 2>/dev/null || echo "Database '$DATASTORE_DB_NAME' already exists"
echo "Granting ownership of datastore database to write user"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "ALTER DATABASE $DATASTORE_DB_NAME OWNER TO $DATASTORE_WRITE_USERNAME;"

echo "Datastore set-permissions"
ckan datastore set-permissions 2>/dev/null | psql -q -d $DATASTORE_WRITE_URL --set ON_ERROR_STOP=1

echo "Datastore Setup Complete"