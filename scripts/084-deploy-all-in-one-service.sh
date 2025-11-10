#!/bin/bash
set -e

echo "========================================"
echo "Deploying All-in-One Service (CKAN + Solr + Redis)"
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

echo "Planning All-in-One Service deployment (targeting module.ecs_service_all_in_one)..."
terraform plan -out=tfplan -target=module.ecs_service_all_in_one

echo "Applying All-in-One Service deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "All-in-One Service Deployed!"
echo "========================================"
echo ""
echo "Service created with desired_count = 0 (no tasks running yet)"
echo ""
echo "To start the service, run:"
echo "  aws ecs update-service \\"
echo "    --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster \\"
echo "    --service ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan \\"
echo "    --desired-count 1 \\"
echo "    --region ${AWS_REGION} \\"
echo "    ${AWS_PROFILE:+--profile ${AWS_PROFILE}}"
echo ""
echo "To watch logs:"
echo "  aws logs tail /ecs/${UNIQUE_PROJECT_ID}-${ENVIRONMENT} --follow --region ${AWS_REGION} ${AWS_PROFILE:+--profile ${AWS_PROFILE}}"
echo ""
echo "Access your CKAN at:"
terraform output -raw alb_url
echo ""
echo "========================================"
