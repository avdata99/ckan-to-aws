#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "CKAN to AWS - Initial Deployment"
echo "========================================"
echo ""
echo "This script will perform a complete initial deployment including:"
echo "  1. Environment setup and validation"
echo "  2. Docker image builds and ECR pushes"
echo "  3. Infrastructure provisioning via CDK"
echo ""
echo "Make sure you have:"
echo "  - AWS credentials configured"
echo "  - Docker installed and running"
echo "  - CDK CLI installed"
echo "  - .env file configured (or environment variables set)"
echo ""
read -p "Press enter to continue or Ctrl+C to cancel..."

# Step 1: Setup environment
echo ""
echo "Step 1/3: Setting up environment..."
source "$SCRIPT_DIR/env-setup.sh"

# Step 2: Build and push Docker images
echo ""
echo "Step 2/3: Building and pushing Docker images..."
source "$SCRIPT_DIR/docker-build.sh"

# Step 3: Deploy CDK stacks
echo ""
echo "Step 3/3: Deploying infrastructure..."
source "$SCRIPT_DIR/cdk-deploy.sh"

echo ""
echo "========================================"
echo "Initial Deployment Complete!"
echo "========================================"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "Account: ${AWS_ACCOUNT_ID}"
echo ""
echo "Next steps:"
echo "  1. Check the AWS Console for ALB DNS name"
echo "  2. Verify CKAN is accessible"
echo "  3. Review CloudWatch logs"
echo "  4. Configure domain and SSL if needed"
