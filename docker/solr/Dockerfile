FROM ckan/ckan-solr:2.11-solr9

# Install curl for health checks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Test that curl was installed
RUN which curl && curl --version

USER solr

# Configure JVM memory - set to ~50-60% of container memory (for 7GB container)
ENV SOLR_JAVA_MEM="-Xms3g -Xmx4g"

# Disable JVM GC logging to reduce overhead (optional)
ENV GC_LOG_OPTS=""
