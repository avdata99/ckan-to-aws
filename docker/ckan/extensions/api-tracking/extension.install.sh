#!/bin/bash -e
echo "Installing API-tracking extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch 0.5.2 https://github.com/NorwegianRefugeeCouncil/ckanext-api-tracking.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -q -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
