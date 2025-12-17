#!/bin/bash -e
echo "Installing DBQuery extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch 0.2.3 https://github.com/unckan/ckanext-dbquery.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
