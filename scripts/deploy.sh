#!/bin/bash
set -e

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    # define env before running the script
fi

# Validate required environment variables
required_vars=("ENVIRONMENT" "AWS_REGION")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        echo "Please check your .env file or set the variable manually"
        exit 1
    fi
done

echo "Checking requirements ..."
# awscli
if ! command -v aws &> /dev/null; then
    echo "Error: awscli is not installed. Please install it to proceed. E.g sudo apt install awscli"
    exit 1
fi

# Set AWS profile option if specified
AWS_PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS profile: $AWS_PROFILE"
    AWS_PROFILE_OPTION="--profile $AWS_PROFILE"
else
    echo "No AWS profile specified, using default profile. Are you sure?"
    read -p "Press enter to continue or Ctrl+C to cancel"
fi

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity $AWS_PROFILE_OPTION --query Account --output text)}
echo "Deploying CKAN to AWS (${ENVIRONMENT} Environment)"

# Set CDK context variables
export CDK_CONTEXT_environment=$ENVIRONMENT
export CDK_CONTEXT_account=${AWS_ACCOUNT_ID}
export CDK_CONTEXT_region=$AWS_REGION

# ECR Configuration
echo "Configuring ECR..."
ECR_REGISTRY=${ECR_REGISTRY:-$CDK_CONTEXT_account.dkr.ecr.$CDK_CONTEXT_region.amazonaws.com}

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password $AWS_PROFILE_OPTION --region $CDK_CONTEXT_region | docker login --username AWS --password-stdin $ECR_REGISTRY

# Create ECR repositories if they don't exist
for repo in ckan-app ckan-solr ckan-redis; do
    aws ecr describe-repositories $AWS_PROFILE_OPTION --repository-names $repo --region $CDK_CONTEXT_region 2>/dev/null || \
    aws ecr create-repository $AWS_PROFILE_OPTION --repository-name $repo --region $CDK_CONTEXT_region
done

# Build main CKAN application using Makefile
echo "Building main CKAN application..."
cd ../docker/ckan
# Load container env from docker/ckan/files/env/base.env + docker/ckan/files/env/ENV_NAME.env
set -o allexport; source files/env/base.env; source files/env/$ENV_NAME.env; set +o allexport
make build ENV_NAME=$ENVIRONMENT
cd ..

# Tag and push CKAN app to ECR
echo "Tagging and pushing CKAN app to ECR..."
docker tag ckan_aws:$ENVIRONMENT $ECR_REGISTRY/ckan-app:$ENVIRONMENT
docker push $ECR_REGISTRY/ckan-app:$ENVIRONMENT

# Build and push other Docker images to ECR
echo "Building and pushing support images to ECR..."

# Build and push Solr image
docker build -t $ECR_REGISTRY/ckan-solr:$ENVIRONMENT ./docker/solr
docker push $ECR_REGISTRY/ckan-solr:$ENVIRONMENT

# Build and push Redis image
docker build -t $ECR_REGISTRY/ckan-redis:$ENVIRONMENT ./docker/redis
docker push $ECR_REGISTRY/ckan-redis:$ENVIRONMENT

echo "All Docker images pushed to ECR successfully!"

# Deploy all stacks
echo "Deploying infrastructure stacks..."
cdk deploy --all --require-approval ${CDK_REQUIRE_APPROVAL:-never} \
  ${AWS_PROFILE:+--profile $AWS_PROFILE} \
  --context environment=$ENVIRONMENT \
  --context account=$CDK_CONTEXT_account \
  --context region=$CDK_CONTEXT_region

echo "${ENVIRONMENT} environment deployed successfully!"
echo "Check the AWS Console for ALB DNS name to access CKAN"
