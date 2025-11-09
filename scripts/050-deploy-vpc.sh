#!/bin/bash
set -e

echo "========================================"
echo "Deploying Network (VPC)"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# --- Validate Inputs for Shared VPC ---
if [ "${CREATE_VPC}" = "false" ]; then
  if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_IDS" ] || [ -z "$PRIVATE_SUBNET_IDS" ]; then
    echo "Error: When CREATE_VPC is false, you must provide VPC_ID, PUBLIC_SUBNET_IDS, and PRIVATE_SUBNET_IDS in your .env file."
    exit 1
  fi
fi

# Navigate to the terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

# Create a terraform.tfvars file to pass variables from .env
# This is how we connect shell variables to Terraform variables
echo "Generating terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_id  = "$UNIQUE_PROJECT_ID"
environment = "$ENVIRONMENT"
aws_region  = "$AWS_REGION"
create_vpc  = ${CREATE_VPC:-true}
allowed_cidr_blocks = ${ALLOWED_CIDR_BLOCKS:-'["0.0.0.0/0"]'}
EOF

# Only add VPC IDs if they are defined (for using existing VPC)
if [[ -n "$VPC_ID" ]]; then
  echo "vpc_id = \"$VPC_ID\"" >> terraform.tfvars
fi
if [[ -n "$PUBLIC_SUBNET_IDS" ]]; then
  echo "public_subnet_ids = $PUBLIC_SUBNET_IDS" >> terraform.tfvars
fi
if [[ -n "$PRIVATE_SUBNET_IDS" ]]; then
  echo "private_subnet_ids = $PRIVATE_SUBNET_IDS" >> terraform.tfvars
fi

# Initialize Terraform. This is required to register the backend and any new modules.
# We run this in each script to ensure the environment is ready.
"$SCRIPT_DIR/030-terraform-init.sh"

echo "Planning VPC deployment (targeting module.vpc)..."
# The -target flag tells Terraform to only look at the 'vpc' module
terraform plan -out=tfplan -target=module.vpc

echo "Applying VPC deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
# The plan file already contains the targeted changes, so we just apply it
# We remove -auto-approve to allow for a final manual confirmation.
terraform apply tfplan

echo "========================================"
echo "VPC Deployment Complete!"
echo "========================================"
