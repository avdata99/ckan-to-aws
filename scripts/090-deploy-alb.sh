#!/bin/bash
set -e

echo "========================================"
echo "Deploying Application Load Balancer (ALB)"
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

echo "Planning ALB deployment (targeting module.alb)..."
terraform plan -out=tfplan -target=module.alb

echo "Applying ALB deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "ALB Deployment Complete!"
echo "========================================"
echo ""
echo "Your Application Load Balancer is ready!"
echo ""
echo "ALB DNS Name:"
terraform output -raw alb_dns_name
echo ""
echo ""
echo "Access URL (once CKAN is deployed):"
terraform output -raw alb_url
echo ""
echo ""
echo "Note: The ALB is ready but has no healthy targets yet."
echo "Next steps:"
echo "1. Deploy Task Definitions: ./scripts/081-deploy-task-definitions.sh"
echo "2. Deploy Solr + Redis services: ./scripts/082-deploy-services.sh"
echo "3. Deploy CKAN service: ./scripts/083-deploy-ckan.sh"
echo "========================================"
