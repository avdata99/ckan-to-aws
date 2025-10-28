#!/bin/bash -e
echo "Installing Datapusher+ extension"
TEMP_DIR=$(mktemp -d)
git clone --depth 1 --branch okfn_tmp https://github.com/okfn/datapusher-plus.git "$TEMP_DIR"
pip install -q "$TEMP_DIR"
pip install -q -r "$TEMP_DIR/requirements.txt"
rm -rf "$TEMP_DIR"
