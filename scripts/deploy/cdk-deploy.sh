#!/bin/bash
set -e

echo "Starting CDK deployment..."

# Validate required variables
if [ -z "$ENVIRONMENT" ] || [ -z "$CDK_CONTEXT_region" ] || [ -z "$CDK_CONTEXT_account" ]; then
    echo "Error: Required environment variables not set. Run env-setup.sh first."
    exit 1
fi

# Deploy all stacks
echo "Deploying infrastructure stacks..."
cd ../cdk

cdk deploy --all --require-approval ${CDK_REQUIRE_APPROVAL:-never} \
  ${AWS_PROFILE:+--profile $AWS_PROFILE} \
  --context environment=$ENVIRONMENT \
  --context account=$CDK_CONTEXT_account \
  --context region=$CDK_CONTEXT_region

echo "CDK deployment complete!"
echo "Check the AWS Console for ALB DNS name to access CKAN"
