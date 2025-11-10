#!/bin/bash
set -e

echo "========================================"
echo "Deploying Backend Services (Solr + Redis)"
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

echo "Planning Backend Services deployment (targeting module.ecs_services_backend)..."
terraform plan -out=tfplan -target=module.ecs_services_backend

echo "Applying Backend Services deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "Backend Services Deployment Complete!"
echo "========================================"
echo ""
echo "Solr + Redis are now running!"
echo ""
echo "Service Discovery DNS Names:"
echo "  Solr:  solr.${UNIQUE_PROJECT_ID}-${ENVIRONMENT}.local:8983"
echo "  Redis: redis.${UNIQUE_PROJECT_ID}-${ENVIRONMENT}.local:6379"
echo ""
echo "Wait 2-3 minutes for the services to become healthy..."
echo ""
echo "Next step: Deploy CKAN service"
echo "Run: ./scripts/083-deploy-ckan-service.sh"
echo "========================================"
