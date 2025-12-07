#!/bin/bash -e
echo "Installing s3filestore extension"
TEMP_DIR=$(mktemp -d)
git clone --branch redirect_to_s3_headers --depth 1 https://github.com/avdata99/ckanext-s3filestore.git "$TEMP_DIR"
pip install "$TEMP_DIR"
pip install -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"