#!/bin/bash -e

echo "Installing OS dependencies"

# CKAN OS dependencies
apt update
apt install -y gettext-base git libmagic1 libpq-dev postgresql-client supervisor vim

# git: to pull the CKAN source code from GitHub
# libmagic1: for the file upload functionality in CKAN
# libpq-dev: for PostgreSQL support in CKAN (psycopg2)
# postgresql-client: for the psql command-line tool
# supervisor: to run CKAN jobs in the background
# gettext-base: for envsubst command
# vim: because why not

EXTENSIONS_LIST_FILE="${APP_DIR}/extensions/extensions.list.txt"
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
        ENTRYPOINT_SCRIPT="$EXTENSION_DIR/extension.os.sh"
        
        if [ -f "$ENTRYPOINT_SCRIPT" ]; then
            echo "Running OS script for $extension"
            chmod +x "$ENTRYPOINT_SCRIPT"
            bash "$ENTRYPOINT_SCRIPT"
        else
            echo "No OS script found for $extension"
        fi
        
    done < "$EXTENSIONS_LIST_FILE"
fi
