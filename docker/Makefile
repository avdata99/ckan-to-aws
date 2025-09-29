.PHONY: build

build:
	@if [ ! -f ckan/files/env/local.env ]; then mkdir -p ckan/files/env && touch ckan/files/env/local.env; fi
	$(eval TZ ?= America/Argentina/Cordoba)
	$(eval ENV_NAME ?= local)
	cd ckan && \
	BUILDKIT_PROGRESS=plain docker build \
		--file Dockerfile \
		--build-arg ENV_NAME=${ENV_NAME} \
		--build-arg TZ=${TZ} \
		-t ckan_aws:${ENV_NAME} .
	echo "Build done ckan_aws:${ENV_NAME}"
	BUILDKIT_PROGRESS=plain docker compose build postgresql_cba
	echo "Build done postgresql_cba"
