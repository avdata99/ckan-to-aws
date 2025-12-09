#!/bin/bash -e
echo "Installing Push Errors extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch 0.1.6 https://github.com/unckan/ckanext-push-errors.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
