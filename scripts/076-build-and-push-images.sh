#!/bin/bash
set -e

echo "========================================"
echo "Building and Pushing Docker Images to ECR"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Validate required variables
if [ -z "$ENVIRONMENT" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Required environment variables not set."
    exit 1
fi

# Get ECR repository URLs from Terraform outputs
echo "Getting ECR repository URLs from Terraform..."
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

CKAN_REPO=$(terraform output -raw ecr_ckan_repository_url 2>/dev/null || echo "")
SOLR_REPO=$(terraform output -raw ecr_solr_repository_url 2>/dev/null || echo "")
REDIS_REPO=$(terraform output -raw ecr_redis_repository_url 2>/dev/null || echo "")

if [ -z "$CKAN_REPO" ] || [ -z "$SOLR_REPO" ] || [ -z "$REDIS_REPO" ]; then
  echo "Error: Could not get ECR repository URLs."
  echo "Please run './scripts/075-deploy-ecr.sh' first to create ECR repositories."
  exit 1
fi

echo "ECR Repositories:"
echo "  CKAN:  $CKAN_REPO"
echo "  Solr:  $SOLR_REPO"
echo "  Redis: $REDIS_REPO"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" $AWS_PROFILE_OPTION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Navigate to docker directory
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "Using image tag: $IMAGE_TAG"
echo ""

# ============================================================================
# Build and Push CKAN
# ============================================================================
echo "========================================"
echo "Building CKAN Image"
echo "========================================"
cd "$DOCKER_DIR/ckan"

# Copy .env file to the location expected by Dockerfile
echo "Copying .env to ckan/files/env/AWS.env..."
mkdir -p files/env
cp "$ROOT_DIR/.env" files/env/AWS.env

# Build CKAN image with proper build args
echo "Building CKAN image..."
docker build \
  --build-arg TZ=America/Argentina/Buenos_Aires \
  --build-arg ENV_NAME=AWS \
  -t "ckan_aws:$IMAGE_TAG" \
  -t "$CKAN_REPO:$IMAGE_TAG" \
  .

echo "Pushing CKAN image to ECR..."
docker push "$CKAN_REPO:$IMAGE_TAG"
echo "CKAN image pushed successfully"
echo ""

# ============================================================================
# Build and Push Solr
# ============================================================================
echo "========================================"
echo "Building Solr Image"
echo "========================================"
cd "$DOCKER_DIR/solr"

echo "Building Solr image..."
docker build \
  -t "solr_aws:$IMAGE_TAG" \
  -t "$SOLR_REPO:$IMAGE_TAG" \
  .

echo "Pushing Solr image to ECR..."
docker push "$SOLR_REPO:$IMAGE_TAG"
echo "Solr image pushed successfully"
echo ""

# ============================================================================
# Build and Push Redis
# ============================================================================
echo "========================================"
echo "Building Redis Image"
echo "========================================"
cd "$DOCKER_DIR/redis"

echo "Building Redis image..."
docker build \
  -t "redis_aws:$IMAGE_TAG" \
  -t "$REDIS_REPO:$IMAGE_TAG" \
  .

echo "Pushing Redis image to ECR..."
docker push "$REDIS_REPO:$IMAGE_TAG"
echo "Redis image pushed successfully"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "========================================"
echo "All Images Built and Pushed Successfully!"
echo "========================================"
echo ""
echo "Images in ECR:"
echo "  $CKAN_REPO:$IMAGE_TAG"
echo "  $SOLR_REPO:$IMAGE_TAG"
echo "  $REDIS_REPO:$IMAGE_TAG"
echo ""
echo "Next steps:"
echo "1. Deploy ECS Cluster: ./scripts/080-deploy-ecs-cluster.sh"
echo "2. Deploy ALB: ./scripts/090-deploy-alb.sh"
echo "3. Deploy ECS Services: ./scripts/095-deploy-ecs-services.sh"
echo "========================================"
