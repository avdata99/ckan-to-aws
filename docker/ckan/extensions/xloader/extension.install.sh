#!/bin/bash -e
echo "Installing xloader extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch 2.2.0 https://github.com/ckan/ckanext-xloader.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -q -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
