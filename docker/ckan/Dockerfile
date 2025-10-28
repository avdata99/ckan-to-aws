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

# Prepare the environment vars
COPY files/scripts/build-env-vars.sh ${APP_DIR}/files/scripts/build-env-vars.sh

RUN echo "Building for ENV_NAME=${ENV_NAME} TZ=${TZ}"
COPY files/env/base.env ${APP_DIR}/files/env/base.env
COPY files/env/${ENV_NAME}.env ${APP_DIR}/files/env/${ENV_NAME}.env
# Also, include main .env file for default values
COPY files/env/AWS.env ${APP_DIR}/files/env/AWS.env
RUN ${APP_DIR}/files/scripts/build-env-vars.sh

# Install OS dependencies
COPY files/scripts/install-python.sh ${APP_DIR}/files/scripts/install-python.sh
RUN ${APP_DIR}/files/scripts/install-python.sh

COPY files/scripts/install-os-deps.sh ${APP_DIR}/files/scripts/install-os-deps.sh
RUN ${APP_DIR}/files/scripts/install-os-deps.sh

# Add config files and substitute env vars
COPY files/etc/supervisord.base ${APP_DIR}/files/etc/supervisord.conf
COPY files/etc/ckan*.conf ${APP_DIR}/files/etc/
COPY files/scripts/prepare-supervisor.sh ${APP_DIR}/files/scripts/prepare-supervisor.sh
RUN ${APP_DIR}/files/scripts/prepare-supervisor.sh

COPY files/patches ${APP_DIR}/files/patches
COPY files/ckan.ini ${CKAN_INI}
COPY files/scripts/install-ckan.sh ${APP_DIR}/files/scripts/install-ckan.sh
COPY files/scripts/install-extensions.sh ${APP_DIR}/files/scripts/install-extensions.sh
COPY files/scripts/setup-ckan-ini-file.sh ${APP_DIR}/files/scripts/setup-ckan-ini-file.sh
COPY extensions ${APP_DIR}/extensions

# Create the ckan user
RUN useradd -m -s /bin/bash ckan
RUN chown ckan -R ${APP_DIR}
RUN chown ckan -R /var/log/supervisor
USER ckan

# Install CKAN
RUN ${APP_DIR}/files/scripts/install-ckan.sh
RUN ${APP_DIR}/files/scripts/install-extensions.sh
RUN cp $APP_DIR/ckan/wsgi.py .
RUN chmod u+x wsgi.py
RUN ${APP_DIR}/files/scripts/setup-ckan-ini-file.sh

HEALTHCHECK --interval=60s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1
EXPOSE 5000

COPY files/scripts/entrypoint.sh ${APP_DIR}/entrypoint.sh 
ENTRYPOINT [ "./entrypoint.sh" ]
