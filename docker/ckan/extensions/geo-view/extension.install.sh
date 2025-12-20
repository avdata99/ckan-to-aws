#!/bin/bash -e
echo "Installing Geo View extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch v0.3.0 https://github.com/ckan/ckanext-geoview.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
# pip install -q -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
