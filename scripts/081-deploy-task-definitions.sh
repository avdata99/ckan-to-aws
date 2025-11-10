#!/bin/bash
set -e

echo "========================================"
echo "Deploying ECS Task Definitions"
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

echo "Planning ECS Task Definitions deployment (targeting module.ecs_tasks)..."
terraform plan -out=tfplan -target=module.ecs_tasks

echo "Applying ECS Task Definitions deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "ECS Task Definitions Deployment Complete!"
echo "========================================"
echo ""
echo "Task Definitions created:"
echo "  - CKAN Task (with runtime env vars for RDS, Solr, Redis)"
echo "  - Services Task (Solr + Redis running together)"
echo ""
echo "IMPORTANT: Deploy services in this order:"
echo "1. Backend services first: ./scripts/082-deploy-services-backend.sh"
echo "   (Solr + Redis must be running before CKAN)"
echo "2. CKAN service after: ./scripts/083-deploy-ckan-service.sh"
echo "   (CKAN will connect to already-running Solr + Redis)"
echo "========================================"
