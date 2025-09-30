#!/bin/bash -e

# load env vars from ${APP_DIR}/.env
set -o allexport
. ${APP_DIR}/.env
set +o allexport

echo "Installing Extensions"

python -m venv ${APP_DIR}/venv
source ${APP_DIR}/venv/bin/activate

# Read extensions list and install each one
EXTENSIONS_LIST_FILE="${APP_DIR}/files/env/extensions.list.txt"
if [ ! -f "$EXTENSIONS_LIST_FILE" ]; then
    echo "Extensions list file not found: $EXTENSIONS_LIST_FILE"
    exit 1
fi

# Read extensions from list file (skip comments and empty lines)
while IFS= read -r extension || [ -n "$extension" ]; do
    # Skip comments and empty lines
    [[ "$extension" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${extension// }" ]] && continue
    
    extension=$(echo "$extension" | xargs)  # trim whitespace
    
    echo "Processing extension: $extension"
    
    EXTENSION_DIR="${APP_DIR}/extensions/$extension"
    
    if [ ! -d "$EXTENSION_DIR" ]; then
        echo "Extension directory not found: $EXTENSION_DIR"
        continue
    fi
    
    # Run extension installation script
    if [ -f "$EXTENSION_DIR/extension.install.sh" ]; then
        echo "Running installation script for $extension"
        chmod +x "$EXTENSION_DIR/extension.install.sh"
        bash "$EXTENSION_DIR/extension.install.sh"
    else
        echo "No installation script found for $extension"
    fi
    
done < "$EXTENSIONS_LIST_FILE"

echo "CKAN extensions installed"
