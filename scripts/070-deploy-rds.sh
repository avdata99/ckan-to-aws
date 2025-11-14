#!/bin/bash
set -e

echo "========================================"
echo "Deploying RDS (PostgreSQL Database)"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Validate required DB variables
if [ -z "$DB_PASSWORD" ]; then
  echo "Error: DB_PASSWORD must be set in your .env file."
  exit 1
fi

if [ -z "$DB_SUBNET_IDS" ]; then
  echo "Error: DB_SUBNET_IDS must be set in your .env file."
  exit 1
fi

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

echo "Planning RDS deployment (targeting module.rds)..."
echo "Note: RDS provisioning typically takes 10-15 minutes."
terraform plan -out=tfplan -target=module.rds

echo "Applying RDS deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "RDS Deployment Complete!"
echo "========================================"
echo "Database endpoint will be available in a few minutes."
echo "Next step: Deploy ElastiCache (Redis)"
echo "Run: ./scripts/080-deploy-redis.sh"
echo "========================================"
