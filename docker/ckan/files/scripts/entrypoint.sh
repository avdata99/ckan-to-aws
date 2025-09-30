#!/bin/bash -e

# load env vars from ${APP_DIR}/.env
set -o allexport
. ${APP_DIR}/.env
set +o allexport

echo "Executing entrypoint.sh"

# The CKAN PostgreSQL image creates the database and user
# https://github.com/ckan/ckan-postgres-dev/blob/main/Dockerfile
# Wait for the database to be ready

until psql -d $SQLALCHEMY_URL -c '\q'; do
  echo "Postgres is unavailable - sleeping. Response: $?"
  sleep 3
done

source ${APP_DIR}/venv/bin/activate

echo "CKAN db upgrade"
ckan db upgrade

# Rebuild search index
ckan search-index rebuild

EXTENSIONS_LIST_FILE="${APP_DIR}/files/env/extensions.list.txt"
# At this point, this file exists.
# iterate all folders like EXTENSION_DIR="${APP_DIR}/extensions/$extension"
# and if the file extension.entrypoint.sh exists, run it
if [ -f "$EXTENSIONS_LIST_FILE" ]; then
    while IFS= read -r extension || [ -n "$extension" ]; do
        # Skip comments and empty lines
        [[ "$extension" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${extension// }" ]] && continue
        
        extension=$(echo "$extension" | xargs)  # trim whitespace
        
        EXTENSION_DIR="${APP_DIR}/extensions/$extension"
        ENTRYPOINT_SCRIPT="$EXTENSION_DIR/extension.entrypoint.sh"
        
        if [ -f "$ENTRYPOINT_SCRIPT" ]; then
            echo "Running entrypoint script for $extension"
            chmod +x "$ENTRYPOINT_SCRIPT"
            bash "$ENTRYPOINT_SCRIPT"
        else
            echo "No entrypoint script found for $extension"
        fi
        
    done < "$EXTENSIONS_LIST_FILE"
fi

ckan config-tool ckan.ini "ckanext.ckan_aws.version=${CKAN_APP_VERSION}"

# For all environments, check if the sysadmin user exists and create it if not
echo "Checking if sysadmin user '$CKAN_SYSADMIN_USER' exists"
OUT=$(ckan user show $CKAN_SYSADMIN_USER)

if [[ $OUT == *"User: None"* ]]; then
    echo "Creating sysadmin user"
    ckan user add $CKAN_SYSADMIN_USER password=$CKAN_SYSADMIN_PASS email=$CKAN_SYSADMIN_MAIL
    ckan sysadmin add $CKAN_SYSADMIN_USER
else
    echo "Sysadmin user already exists"
fi

# Rebuild webassets in case they were patched
echo "Rebuilding CKAN webassets"
ckan asset build

echo "Setting permissions for datastore"
ckan datastore set-permissions | psql $(grep ckan.datastore.write_url ckan.ini | awk -F= '{print $2}')

# Start supervisor
echo "Supervisor start"
service supervisor start

echo "Finished entrypoint.sh"
sleep 3
echo "************************************************"
echo "************************************************"
echo "************************************************"
echo "************************************************"
echo "*********** CKAN is ready to use ***************"
echo "************ at $CKAN_SITE_URL *****************"
echo "***************CKAN-AWS $CKAN_APP_VERSION ********"
echo "************************************************"
echo "************************************************"
echo "************************************************"

# Any other command to continue running and allow to stop CKAN
# This avoid cloud providers to panic thinking CKAN is not running and they need
# to restart it.
# You can stop/restart CKAN without any cloud provider intervention
tail -f /var/log/supervisor/*.log
