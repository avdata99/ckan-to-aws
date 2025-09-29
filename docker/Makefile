.PHONY: build

build-ckan:
	$(eval TZ ?= America/Argentina/Cordoba)
	$(eval ENV_NAME ?= dev)
	cd ckan && \
	BUILDKIT_PROGRESS=plain docker build \
		--file Dockerfile \
		--build-arg ENV_NAME=${ENV_NAME} \
		--build-arg TZ=${TZ} \
		-t ckan_aws:${ENV_NAME} .
	echo "Build done ckan_aws:${ENV_NAME}"
	cd ..

build-solr:
	cd solr && \
	docker build \
		--file Dockerfile \
		-t solr_aws:latest .
	echo "Build done solr_aws:latest"
	cd ..

build-redis:
	cd redis && \
	docker build \
		--file Dockerfile \
		-t redis_aws:latest .
	echo "Build done [Valkey] redis_aws:latest"
	cd ..
