echo "Enabling DataPusher extension settings..."
ckan config-tool ${CKAN_INI} "ckan.datapusher.url = http://127.0.0.1:8800/"
ckan config-tool ${CKAN_INI} "ckan.datapusher.enabled = true"
# ckan config-tool ${CKAN_INI} "ckan.datapusher.api_token = ${DATAPUSHER_TOKEN}"