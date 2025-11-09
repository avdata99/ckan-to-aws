#!/bin/bash
set -e

echo "========================================"
echo "Deploying Security Groups"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Navigate to the terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

# Initialize Terraform
"$SCRIPT_DIR/030-terraform-init.sh"

echo "Planning Security Groups deployment (targeting module.security_groups)..."
terraform plan -out=tfplan -target=module.security_groups

echo "Applying Security Groups deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "Security Groups Deployment Complete!"
echo "========================================"
echo "Next step: Deploy RDS (PostgreSQL database)"
echo "Run: ./scripts/070-deploy-rds.sh"
echo "========================================"
