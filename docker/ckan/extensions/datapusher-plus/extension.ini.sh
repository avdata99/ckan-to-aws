ckan config-tool ${CKAN_INI} "ckan.datapusher.formats=csv xls xlsx xlsm xlsb tsv ssv tab application/csv application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet ods application/vnd.oasis.opendocument.spreadsheet"
ckan config-tool ${CKAN_INI} "ckanext.datapusher_plus.qsv_bin=/usr/local/bin/qsvdp"
