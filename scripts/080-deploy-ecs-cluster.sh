#!/bin/bash
set -e

echo "========================================"
echo "Deploying ECS Cluster"
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

echo "Planning ECS Cluster deployment (targeting module.ecs_cluster)..."
terraform plan -out=tfplan -target=module.ecs_cluster

echo "Applying ECS Cluster deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "ECS Cluster Deployment Complete!"
echo "========================================"
echo "The cluster is ready to run containers."
echo "Next step: Deploy ECS Task Definitions"
echo "Run: ./scripts/081-deploy-task-definitions.sh"
echo "========================================"
