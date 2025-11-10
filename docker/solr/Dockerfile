FROM ckan/ckan-solr:2.11-solr9

# Install curl for health checks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Test that curl was installed
RUN which curl && curl --version

USER solr
