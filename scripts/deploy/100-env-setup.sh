#!/bin/bash
set -e

echo "Setting up environment..."

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "No .env file found. Reading environment variables from the shell environment..."
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
# Allow reusing this env vars in following scripts
export ENVIRONMENT
export AWS_REGION

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

# Set CDK context variables
export CDK_CONTEXT_environment=$ENVIRONMENT
export CDK_CONTEXT_account=${AWS_ACCOUNT_ID}
export CDK_CONTEXT_region=$AWS_REGION

echo "Environment setup complete!"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo "  Account: $AWS_ACCOUNT_ID"
