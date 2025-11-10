#!/bin/bash
set -e

echo "========================================"
echo "Deploying CKAN Service"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Navigate to the terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

# Ensure terraform.tfvars is up to date
if [ ! -f terraform.tfvars ]; then
  echo "Error: terraform.tfvars not found. Please run 050-deploy-vpc.sh first."
  exit 1
fi

# Initialize Terraform
"$SCRIPT_DIR/030-terraform-init.sh"

echo "Planning CKAN Service deployment (targeting module.ecs_services_ckan)..."
terraform plan -out=tfplan -target=module.ecs_services_ckan

echo "Applying CKAN Service deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "CKAN Service Deployment Complete!"
echo "========================================"
echo ""
echo "CKAN is now starting up..."
echo "This may take 3-5 minutes for the first deployment."
echo ""
echo "Access your CKAN application at:"
terraform output -raw alb_url
echo ""
echo ""
echo "To check service status:"
echo "  aws ecs describe-services --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --services ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan-service --region ${AWS_REGION} ${AWS_PROFILE:+--profile ${AWS_PROFILE}}"
echo ""
echo "To view logs:"
echo "  aws logs tail /ecs/${UNIQUE_PROJECT_ID}-${ENVIRONMENT} --follow --region ${AWS_REGION} ${AWS_PROFILE:+--profile ${AWS_PROFILE}}"
echo "========================================"
