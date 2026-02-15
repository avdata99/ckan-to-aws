#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
TARGET="ckan"
DESIRED_COUNT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --desired-count)
      DESIRED_COUNT="$2"
      shift 2
      ;;
    ckan|solr|redis|all)
      TARGET="$1"
      shift
      ;;
    *)
      echo "Usage: $0 [ckan|solr|redis|all] [--desired-count N]"
      echo ""
      echo "Arguments:"
      echo "  ckan|solr|redis|all   Which image(s) to build and push (default: ckan)"
      echo "  --desired-count N     Set desired task count (use 1 for first deployment)"
      exit 1
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
echo "========================================"
echo "Pre-flight Checks"
echo "========================================"

CLUSTER="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster"
SERVICE="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan"

# Check ECR repositories exist
echo "Checking ECR repositories..."
for repo_name in ckan solr redis; do
  REPO="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-${repo_name}"
  if ! aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" $AWS_PROFILE_OPTION >/dev/null 2>&1; then
    echo "Error: ECR repository '$REPO' not found."
    echo "Infrastructure must be created first (by an admin with full permissions)."
    exit 1
  fi
done
echo "  ECR repositories exist."

# Check ECS cluster and service exist
echo "Checking ECS service..."
SERVICE_JSON=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$AWS_REGION" \
  $AWS_PROFILE_OPTION \
  --query 'services[0].{status:status,desiredCount:desiredCount,runningCount:runningCount}' \
  --output json 2>/dev/null || echo "{}")

SERVICE_STATUS=$(echo "$SERVICE_JSON" | jq -r '.status // empty')
if [ -z "$SERVICE_STATUS" ] || [ "$SERVICE_STATUS" = "null" ]; then
  echo "Error: ECS service '$SERVICE' not found in cluster '$CLUSTER'."
  echo "Infrastructure must be created first (by an admin with full permissions)."
  exit 1
fi
echo "  ECS service exists (status: $SERVICE_STATUS)."

# Warn if desired count is 0 and no --desired-count flag provided
CURRENT_DESIRED=$(echo "$SERVICE_JSON" | jq -r '.desiredCount // 0')
if [ "$CURRENT_DESIRED" = "0" ] && [ -z "$DESIRED_COUNT" ]; then
  echo ""
  echo "WARNING: ECS service desired count is 0 (no tasks running)."
  echo "The deployment will push images but no tasks will start."
  echo ""
  echo "To start the service, re-run with:"
  echo "  $0 $TARGET --desired-count 1"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

echo "  Pre-flight checks passed."
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Login to ECR
# -----------------------------------------------------------------------------
aws ecr get-login-password --region "$AWS_REGION" $AWS_PROFILE_OPTION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# -----------------------------------------------------------------------------
# Build and push images
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Update ECS service
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "Forcing new deployment..."
echo "========================================"

UPDATE_CMD="aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION"

if [ -n "$DESIRED_COUNT" ]; then
  echo "Setting desired count to $DESIRED_COUNT"
  UPDATE_CMD="$UPDATE_CMD --desired-count $DESIRED_COUNT"
fi

eval $UPDATE_CMD

echo ""
echo "========================================"
echo "Done!"
echo "========================================"
echo ""
echo "Watch deployment status:"
echo "  aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region ${AWS_REGION} ${AWS_PROFILE_OPTION} --query 'services[0].deployments'"
echo ""
echo "Watch logs:"
echo "  aws logs tail /ecs/${UNIQUE_PROJECT_ID}-${ENVIRONMENT} --follow --region ${AWS_REGION} ${AWS_PROFILE_OPTION}"
