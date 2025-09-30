#!/bin/bash -e
echo "Installing Datapusher+ extension"
pip install -q git+https://github.com/okfn/datapusher-plus.git@okfn_tmp#egg=datapusher_plus
pip install -q -r https://raw.githubusercontent.com/okfn/datapusher-plus/okfn_tmp/requirements.txt
