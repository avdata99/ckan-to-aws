#!/bin/bash -e
echo "Installing Announcements extension"
pip install -q git+https://github.com/okfn/ckanext-announcements.git@0.1.4#egg=ckanext-announcements
pip install -q -r https://raw.githubusercontent.com/okfn/ckanext-announcements/0.1.4/requirements.txt
