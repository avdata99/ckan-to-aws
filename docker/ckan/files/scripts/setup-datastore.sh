#!/bin/bash
set -e

# DB_USERNAME and DB_PASSWORD are the root PSQL users
# Environment variables are already set by setup-runtime-env.sh
# DO NOT load .env here as it would overwrite AWS Secrets Manager values
echo "Starting Datastore Setup"
cd $APP_DIR

# Activate venv for ckan CLI
source ${APP_DIR}/venv/bin/activate

export PGPASSWORD=$DB_PASSWORD
# Create the CKAN DB, there is no psql_user
echo "Creating CKAN database if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database 'ckan' already exists"

echo "Creating/updating datastore read user"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "DO \$\$ BEGIN CREATE USER $DATASTORE_READ_USERNAME WITH PASSWORD '$DATASTORE_READ_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE; EXCEPTION WHEN duplicate_object THEN ALTER USER $DATASTORE_READ_USERNAME WITH PASSWORD '$DATASTORE_READ_PASSWORD'; END \$\$;"

echo "Creating/updating datastore write user"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "DO \$\$ BEGIN CREATE USER $DATASTORE_WRITE_USERNAME WITH PASSWORD '$DATASTORE_WRITE_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE; EXCEPTION WHEN duplicate_object THEN ALTER USER $DATASTORE_WRITE_USERNAME WITH PASSWORD '$DATASTORE_WRITE_PASSWORD'; END \$\$;"


echo "Creating datastore db if not exists"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "CREATE DATABASE $DATASTORE_DB_NAME;" 2>/dev/null || echo "Database '$DATASTORE_DB_NAME' already exists"
echo "Granting ownership of datastore database to write user"
psql -h $DB_HOST -U $DB_USERNAME -d postgres -c "ALTER DATABASE $DATASTORE_DB_NAME OWNER TO $DATASTORE_WRITE_USERNAME;"

echo "Datastore set-permissions for $DATASTORE_WRITE_URL"
ckan datastore set-permissions 2>/dev/null | psql -q $DATASTORE_WRITE_URL --set ON_ERROR_STOP=1

echo "Datastore Setup Complete"