#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "CKAN to AWS Deployment"
echo "========================================"

# Step 1: Setup environment
source "$SCRIPT_DIR/deploy/100-env-setup.sh"

# Step 2: Build and push Docker images
source "$SCRIPT_DIR/deploy/200-docker-build.sh"

# Step 3: Deploy CDK stacks
source "$SCRIPT_DIR/deploy/300-cdk-deploy.sh"

echo "========================================"
echo "Deployment Complete!"
echo "Environment: ${ENVIRONMENT}"
echo "========================================"
echo "Next steps:"
echo "  - Check the AWS Console for ALB DNS name to access CKAN"
echo "  - Review CloudWatch logs for application status"
