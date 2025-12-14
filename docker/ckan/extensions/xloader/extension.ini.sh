echo "Creating a valid API token for Datapusher+"
DATAPUSHER_TOKEN=$(ckan user token add default xloader_token | tail -n 1 | tr -d '\t')
echo "Setting xloader configuration in CKAN ini file"
ckan config-tool ${CKAN_INI} "ckanext.xloader.api_token = ${DATAPUSHER_TOKEN}"

echo "Setting for DB jobs"
ckan config-tool ${CKAN_INI} "ckanext.xloader.jobs_db.uri = ${SQLALCHEMY_URL}"
