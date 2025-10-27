#!/bin/bash
set -e

echo "Starting Docker build and push process..."

# Validate required variables
if [ -z "$ENVIRONMENT" ] || [ -z "$CDK_CONTEXT_region" ] || [ -z "$CDK_CONTEXT_account" ]; then
    echo "Error: Required environment variables not set. Run env-setup.sh first."
    exit 1
fi

# ECR Configuration
echo "Configuring ECR..."
ECR_REGISTRY=${ECR_REGISTRY:-$CDK_CONTEXT_account.dkr.ecr.$CDK_CONTEXT_region.amazonaws.com}
echo "ECR Registry: $ECR_REGISTRY"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password $AWS_PROFILE_OPTION --region $CDK_CONTEXT_region | docker login --username AWS --password-stdin $ECR_REGISTRY

# Create ECR repositories if they don't exist
echo "Ensuring ECR repositories exist..."
for repo in ckan-app ckan-solr ckan-redis; do
    echo "Checking repository: $repo"
    aws ecr describe-repositories $AWS_PROFILE_OPTION --repository-names $repo --region $CDK_CONTEXT_region 2>/dev/null || \
    aws ecr create-repository $AWS_PROFILE_OPTION --repository-name $repo --region $CDK_CONTEXT_region
done

# Build and push Docker images to ECR
echo "Building and pushing Docker images to ECR..."
cd ../docker

# Build and push Solr image
echo "Building Solr image..."
make build-solr
docker tag solr_aws:latest $ECR_REGISTRY/ckan-solr:$ENVIRONMENT
docker push $ECR_REGISTRY/ckan-solr:$ENVIRONMENT

# Build and push Redis image
echo "Building Redis image..."
make build-redis
docker tag redis_aws:latest $ECR_REGISTRY/ckan-redis:$ENVIRONMENT
docker push $ECR_REGISTRY/ckan-redis:$ENVIRONMENT

# Build main CKAN application
echo "Building main CKAN application..."
set -o allexport; source ckan/files/env/base.env; source ckan/files/env/$ENVIRONMENT.env; set +o allexport
make build-ckan ENV_NAME=$ENVIRONMENT
docker tag ckan_aws:$ENVIRONMENT $ECR_REGISTRY/ckan-app:$ENVIRONMENT
docker push $ECR_REGISTRY/ckan-app:$ENVIRONMENT

echo "Docker build and push complete!"
