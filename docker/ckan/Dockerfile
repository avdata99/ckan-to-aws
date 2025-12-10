FROM debian:12-slim

# Args
ARG TZ
ARG ENV_NAME

# Internals, you probably don't need to change these
ENV APP_DIR=/app/ckan_aws
ENV CKAN_INI=${APP_DIR}/ckan.ini
ENV ENV_NAME=${ENV_NAME}

WORKDIR ${APP_DIR}
RUN apt update

# Install locales early to prevent locale errors
RUN apt-get install -y locales && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Set locale environment variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Copy files one by one to ensure Dockerfile is caching layers
# and the change in one file does not invalidate the cache of the others

# Copy all scripts at once
COPY files/scripts ${APP_DIR}/files/scripts

# Prepare the environment vars
RUN echo "Building for ENV_NAME=${ENV_NAME} TZ=${TZ}"
COPY files/env/base.env ${APP_DIR}/files/env/base.env
COPY files/env/${ENV_NAME}.env ${APP_DIR}/files/env/${ENV_NAME}.env
RUN ${APP_DIR}/files/scripts/build-env-vars.sh

# Install OS dependencies
RUN ${APP_DIR}/files/scripts/install-python.sh
RUN ${APP_DIR}/files/scripts/install-os-deps.sh

# Install curl for health checks
RUN apt install -y curl vim screen jq postgresql-client

# Add config files and substitute env vars
COPY files/etc/supervisord.base ${APP_DIR}/files/etc/supervisord.conf
COPY files/etc/ckan*.conf ${APP_DIR}/files/etc/
RUN ${APP_DIR}/files/scripts/prepare-supervisor.sh

COPY files/patches ${APP_DIR}/files/patches
COPY files/ckan.ini ${CKAN_INI}
COPY extensions ${APP_DIR}/extensions

# Create the ckan user
RUN useradd -m -s /bin/bash ckan
RUN chown ckan -R ${APP_DIR}
RUN mkdir -p /var/log/supervisor && chown ckan -R /var/log/supervisor
# TODO ensure we use ckan_storage setting
RUN mkdir -p /var/lib/ckan/storage && chown -R ckan:ckan /var/lib/ckan
USER ckan

# Install CKAN
RUN ${APP_DIR}/files/scripts/install-ckan.sh
RUN ${APP_DIR}/files/scripts/install-extensions.sh
RUN cp $APP_DIR/ckan/wsgi.py .
RUN chmod u+x wsgi.py

HEALTHCHECK --interval=60s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1
EXPOSE 5000

COPY files/scripts/entrypoint.sh ${APP_DIR}/entrypoint.sh 
ENTRYPOINT [ "./entrypoint.sh" ]
