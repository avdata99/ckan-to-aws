#!/bin/bash
set -e

echo "========================================"
echo "Deploying ECR Repositories"
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

echo "Planning ECR deployment (targeting module.ecr)..."
terraform plan -out=tfplan -target=module.ecr

echo "Applying ECR deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo ""
echo "========================================"
echo "ECR Repositories Deployed Successfully!"
echo "========================================"
echo ""
echo "Repository URLs:"
terraform output -json | jq -r '.ecr_ckan_repository_url.value // empty' | xargs -I {} echo "  CKAN:  {}"
terraform output -json | jq -r '.ecr_solr_repository_url.value // empty' | xargs -I {} echo "  Solr:  {}"
terraform output -json | jq -r '.ecr_redis_repository_url.value // empty' | xargs -I {} echo "  Redis: {}"
echo ""
echo "Next steps:"
echo "1. Build and push your Docker images:"
echo "   ./scripts/076-build-and-push-images.sh"
echo "2. Or set up CodeBuild for automated builds"
echo "========================================"
