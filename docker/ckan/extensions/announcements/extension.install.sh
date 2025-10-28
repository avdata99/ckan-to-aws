#!/bin/bash -e
echo "Installing Announcements extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch 0.1.4 https://github.com/okfn/ckanext-announcements.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -q -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
