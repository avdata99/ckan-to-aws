#!/bin/bash -e
echo "Installing API-tracking extension"
pip install -q git+https://github.com/NorwegianRefugeeCouncil/ckanext-api-tracking.git@0.5.2#egg=ckanext-api-tracking
pip install -q -r https://raw.githubusercontent.com/NorwegianRefugeeCouncil/ckanext-api-tracking/refs/tags/0.5.2/requirements.txt
