#!/bin/bash -e

# load env vars from ${APP_DIR}/.env
set -o allexport
. ${APP_DIR}/.env
set +o allexport

echo "Installing Extensions"

python -m venv ${APP_DIR}/venv
source ${APP_DIR}/venv/bin/activate

# Si estamos en el entorno de desarrollo ya esta montada la carpeta de la extension CBA-CKAN

echo "Installing ckanext-pdfview"
pip install -q git+https://github.com/ckan/ckanext-pdfview.git#egg=ckanext-pdfview

echo "Installing Datapusher+extension"
pip install -q git+https://github.com/okfn/datapusher-plus.git@okfn_tmp#egg=datapusher_plus
pip install -q -r https://raw.githubusercontent.com/okfn/datapusher-plus/okfn_tmp/requirements.txt

echo "Installing API-tracking extension"
pip install -q git+https://github.com/NorwegianRefugeeCouncil/ckanext-api-tracking.git@0.5.2#egg=ckanext-api-tracking
pip install -q -r https://raw.githubusercontent.com/NorwegianRefugeeCouncil/ckanext-api-tracking/refs/tags/0.5.2/requirements.txt

echo "Installing Announcements extension"
pip install -q git+https://github.com/okfn/ckanext-announcements.git@0.1.4#egg=ckanext-announcements
pip install -q -r https://raw.githubusercontent.com/okfn/ckanext-announcements/0.1.4/requirements.txt

echo "Installing Push Errors extension"
pip install -q git+https://github.com/unckan/ckanext-push-errors.git@0.1.5#egg=ckanext-push-errors
pip install -r https://raw.githubusercontent.com/unckan/ckanext-push-errors/refs/tags/0.1.5/requirements.txt

echo "Installing ckanext-scheming extension"
# Esperando release 3.1.0
pip install -q git+https://github.com/ckan/ckanext-scheming.git@49527ec191254a2f457b44daf870ca08e9c1a1ea#egg=ckanext-scheming

echo "Installing ckanext-geoview extension"
pip install -q git+https://github.com/ckan/ckanext-geoview.git@v0.2.2#egg=ckanext-geoview

echo "Installing ckanext-selfinfo extension"
pip install -q git+https://github.com/DataShades/ckanext-selfinfo.git@v1.2.0#egg=ckanext-selfinfo
pip install -q pip

echo "CKAN extensions installed"
