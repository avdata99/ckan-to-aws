# Ensure adding geo_view to default views
# ckan config-tool ${CKAN_INI} "ckan.views.default_views = ... geo_view geojson_view wmts_view shp_view ..."
# the best place to do this so far is a place like the file
# docker/ckan/files/scripts/private/private-entrypoint.sh
