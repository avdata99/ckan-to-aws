#!/bin/bash -e

# load env vars from ${APP_DIR}/.env
set -o allexport
. ${APP_DIR}/.env
set +o allexport

echo "Setting up configuration file for $ENV_NAME environment"
source ${APP_DIR}/venv/bin/activate
cd $APP_DIR

# Validate required env vars
VALIDATE_VARS="SECRET_KEY BEAKER_SESSION_SECRET BEAKER_SESSION_VALIDATE_KEY CKAN_SITE_URL CKAN_STORAGE_FOLDER SQLALCHEMY_URL SOLR_URL CKAN_REDIS_URL"
for VAR in $VALIDATE_VARS; do
  if [ -z "${!VAR}" ]; then
    echo "$VAR is not set. Exiting."
    exit 1
  fi
done

ckan config-tool ${CKAN_INI} "SECRET_KEY=${SECRET_KEY}"
ckan config-tool ${CKAN_INI} "beaker.session.secret=${BEAKER_SESSION_SECRET}"
ckan config-tool ${CKAN_INI} "beaker.session.validate_key = ${BEAKER_SESSION_VALIDATE_KEY}"

# debug
ckan config-tool ${CKAN_INI} "debug = ${CKAN_DEBUG}"

ckan config-tool ${CKAN_INI} "ckan.site_url = ${CKAN_SITE_URL}"
ckan config-tool ${CKAN_INI} "ckan.storage_path = $APP_DIR/${CKAN_STORAGE_FOLDER}"

# Example: postgresql://<user>:<pass>@<name>.postgres.database.azure.com/ckan?sslmode=require
ckan config-tool ${CKAN_INI} "sqlalchemy.url = ${SQLALCHEMY_URL}"
# Example: https://<name>.azurewebsites.net/solr/ckan
ckan config-tool ${CKAN_INI} "solr_url = ${SOLR_URL}"
# Example: 'rediss://default:<pass>@<name>.redis.cache.windows.net:6380'
ckan config-tool ${CKAN_INI} "ckan.redis.url = ${CKAN_REDIS_URL}"

# Build plugins list from extensions
PLUGINS_LIST=""
EXTENSIONS_LIST_FILE="${APP_DIR}/files/env/extensions.list.txt"
if [ -f "$EXTENSIONS_LIST_FILE" ]; then
    while IFS= read -r extension || [ -n "$extension" ]; do
        # Skip comments and empty lines
        [[ "$extension" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${extension// }" ]] && continue
        
        extension=$(echo "$extension" | xargs)  # trim whitespace
        
        EXTENSION_DIR="${APP_DIR}/extensions/$extension"
        PLUGINS_FILE="$EXTENSION_DIR/extension.plugins.txt"
        
        if [ -f "$PLUGINS_FILE" ]; then
            EXTENSION_PLUGINS=$(cat "$PLUGINS_FILE" | xargs)
            if [ -n "$EXTENSION_PLUGINS" ]; then
                if [ -z "$PLUGINS_LIST" ]; then
                    PLUGINS_LIST="$EXTENSION_PLUGINS"
                else
                    PLUGINS_LIST="$PLUGINS_LIST $EXTENSION_PLUGINS"
                fi
            fi
        fi
        
    done < "$EXTENSIONS_LIST_FILE"
fi

# Set the plugins configuration
if [ -n "$PLUGINS_LIST" ]; then
    echo "Configuring CKAN plugins: $PLUGINS_LIST"
    ckan config-tool ${CKAN_INI} "ckan.plugins = $PLUGINS_LIST datapusher"
fi

ckan config-tool ${CKAN_INI} -s logger_ckan "level = INFO"
ckan config-tool ${CKAN_INI} -s logger_ckanext "level = INFO"

# push-errors-settings
if [ -z "${SLACK_WEBHOOK_URL}" ]; then
  echo "SLACK_WEBHOOK_URL is not set. push-errors will not be configured."
else
  echo "Configuring push-errors with SLACK_WEBHOOK_URL"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.url = ${SLACK_WEBHOOK_URL}"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.method = POST"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.headers={}"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.data={\"text\": \"{message}\", \"username\": \"CKAN AWS LOGS\", \"icon_url\": \"https://github.com/unckan/ckanext-push-errors/raw/main/icons/server-error.png\"}"
fi

# Run extension-specific ini configuration
EXTENSIONS_LIST_FILE="${APP_DIR}/files/env/extensions.list.txt"
if [ -f "$EXTENSIONS_LIST_FILE" ]; then
    while IFS= read -r extension || [ -n "$extension" ]; do
        # Skip comments and empty lines
        [[ "$extension" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${extension// }" ]] && continue
        
        extension=$(echo "$extension" | xargs)  # trim whitespace
        
        EXTENSION_DIR="${APP_DIR}/extensions/$extension"
        INI_SCRIPT="$EXTENSION_DIR/extension.ini.sh"
        
        if [ -f "$INI_SCRIPT" ]; then
            echo "Running ini configuration script for $extension"
            chmod +x "$INI_SCRIPT"
            bash "$INI_SCRIPT"
        fi
        
    done < "$EXTENSIONS_LIST_FILE"
fi

echo "Configuration file setup complete"
