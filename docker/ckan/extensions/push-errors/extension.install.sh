#!/bin/bash -e
echo "Installing Push Errors extension"
pip install -q git+https://github.com/unckan/ckanext-push-errors.git@0.1.5#egg=ckanext-push-errors
pip install -r https://raw.githubusercontent.com/unckan/ckanext-push-errors/refs/tags/0.1.5/requirements.txt
