#!/bin/bash -e
# Configure push-errors extension
if [ -z "${SLACK_WEBHOOK_URL}" ]; then
  echo "SLACK_WEBHOOK_URL is not set. push-errors will not be configured."
else
  echo "Configuring push-errors with SLACK_WEBHOOK_URL"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.url = ${SLACK_WEBHOOK_URL}"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.method = POST"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.headers={}"
  ckan config-tool ${CKAN_INI} "ckanext.push_errors.data={\"text\": \"{message}\", \"username\": \"CKAN AWS LOGS\", \"icon_url\": \"https://github.com/unckan/ckanext-push-errors/raw/main/icons/server-error.png\"}"
fi
