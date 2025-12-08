#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Which image to build (ckan, solr, redis, or all)
TARGET="${1:-ckan}"

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" $AWS_PROFILE_OPTION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

ROOT_DIR="$SCRIPT_DIR/.."
DOCKER_DIR="$ROOT_DIR/docker"
IMAGE_TAG="${IMAGE_TAG:-latest}"

build_and_push() {
  local name=$1
  local repo="$ECR_REGISTRY/${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-${name}"
  
  echo "========================================"
  echo "Building $name..."
  echo "  Repo: $repo:$IMAGE_TAG"
  echo "========================================"
  
  cd "$DOCKER_DIR/$name"
  
  if [ "$name" = "ckan" ]; then
    mkdir -p files/env
    cp "$ROOT_DIR/.env" files/env/AWS.env
    docker build \
      --build-arg TZ=America/Argentina/Buenos_Aires \
      --build-arg ENV_NAME=AWS \
      -t "$repo:$IMAGE_TAG" .
  else
    docker build -t "$repo:$IMAGE_TAG" .
  fi
  
  echo "Pushing $name..."
  docker push "$repo:$IMAGE_TAG"
  echo "$name pushed successfully!"
}

if [ "$TARGET" = "all" ]; then
  build_and_push ckan
  build_and_push solr
  build_and_push redis
else
  build_and_push "$TARGET"
fi

echo ""
echo "========================================"
echo "Forcing new deployment..."
echo "========================================"
aws ecs update-service \
  --cluster "${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster" \
  --service "${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan" \
  --force-new-deployment \
  --region "$AWS_REGION" \
  $AWS_PROFILE_OPTION

echo ""
echo "========================================"
echo "Done!"
echo "========================================"
echo ""
echo "Watch deployment status:"
echo "  aws ecs describe-services --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --services ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan --region ${AWS_REGION} ${AWS_PROFILE_OPTION} --query 'services[0].deployments'"
echo ""
echo "Watch logs:"
echo "  aws logs tail /ecs/${UNIQUE_PROJECT_ID}-${ENVIRONMENT} --follow --region ${AWS_REGION} ${AWS_PROFILE_OPTION}"
