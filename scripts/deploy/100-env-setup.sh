#!/bin/bash
set -e

echo "Setting up environment..."

# Determine project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load environment variables from .env file in project root
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading environment variables from $PROJECT_ROOT/.env"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "No .env file found at $PROJECT_ROOT/.env"
    echo "Please copy .env.sample to .env and configure it"
    exit 1
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

echo "Checking requirements..."
# awscli
if ! command -v aws &> /dev/null; then
    echo "Error: awscli is not installed. Please install it to proceed. E.g sudo apt install awscli"
    exit 1
fi

# Set AWS profile option if specified
export AWS_PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS profile: $AWS_PROFILE"
    export AWS_PROFILE_OPTION="--profile $AWS_PROFILE"
else
    echo "No AWS profile specified, using default profile. Are you sure?"
    read -p "Press enter to continue or Ctrl+C to cancel"
fi

# Get AWS Account ID
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity $AWS_PROFILE_OPTION --query Account --output text)}
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Set ECR registry
export ECR_REGISTRY=${ECR_REGISTRY:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com}
echo "ECR Registry: $ECR_REGISTRY"

echo "Environment setup complete!"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo "  Account: $AWS_ACCOUNT_ID"
echo "  ECR Registry: $ECR_REGISTRY"
