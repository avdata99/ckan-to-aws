#!/bin/bash
set -e

echo "========================================"
echo "Starting Terraform deployment..."
echo "========================================"

# Validate required variables
if [ -z "$ENVIRONMENT" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required environment variables not set."
    echo "Please check your .env file has: ENVIRONMENT, AWS_REGION, DB_PASSWORD"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"

cd "$TERRAFORM_DIR"

# Verify modules directory exists
if [ ! -d "modules" ]; then
    echo "Error: modules directory not found at $TERRAFORM_DIR/modules"
    echo "Please ensure the following directories exist:"
    echo "  - modules/vpc"
    echo "  - modules/security_groups"
    echo "  - modules/rds"
    echo "  - modules/ecs_cluster"
    echo "  - modules/alb"
    echo "  - modules/ecs_services"
    exit 1
fi

# Verify each required module exists
for module in vpc security_groups rds ecs_cluster alb ecs_services; do
    if [ ! -d "modules/$module" ]; then
        echo "Error: Module directory not found: modules/$module"
        exit 1
    fi
done

echo "Module directories verified"

# Create S3 bucket for Terraform state
STATE_BUCKET="ckan-terraform-state-${ENVIRONMENT}-${AWS_ACCOUNT_ID}"
echo ""
echo "Step 2: Setting up Terraform state bucket..."
echo "Bucket: $STATE_BUCKET"

if aws s3 ls "s3://$STATE_BUCKET" $AWS_PROFILE_OPTION 2>/dev/null; then
    echo "State bucket exists"
else
    echo "Creating state bucket..."
    aws s3 mb "s3://$STATE_BUCKET" $AWS_PROFILE_OPTION --region $AWS_REGION
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $STATE_BUCKET \
        --versioning-configuration Status=Enabled \
        $AWS_PROFILE_OPTION
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket $STATE_BUCKET \
        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
        $AWS_PROFILE_OPTION
    
    echo "State bucket created"
fi

echo ""
echo "Step 3: Initializing Terraform..."
echo "--------------------------------"

terraform init \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="key=terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    ${AWS_PROFILE:+-backend-config="profile=$AWS_PROFILE"}

echo ""
echo "Step 4: Validating configuration..."
echo "--------------------------------"

terraform validate
echo "Configuration valid"

# Plan with variables from .env
echo ""
echo "Step 5: Planning deployment..."
echo "--------------------------------"
echo "Terraform will now show you EXACTLY what it will create."
echo "Review this carefully before proceeding!"
echo ""

terraform plan \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION" \
  -var="aws_profile=${AWS_PROFILE:-}" \
  -var="ecr_registry=$ECR_REGISTRY" \
  -var="db_name=${DB_NAME:-ckan}" \
  -var="db_username=${DB_USERNAME:-ckan}" \
  -var="db_password=$DB_PASSWORD" \
  -var="db_instance_class=${DB_INSTANCE_CLASS:-db.t3.micro}" \
  -var="db_allocated_storage=${DB_ALLOCATED_STORAGE:-20}" \
  -var="ckan_site_url=$CKAN_SITE_URL" \
  -var="vpc_cidr=${VPC_CIDR:-10.0.0.0/16}" \
  -var="datastore_write_username=${DATASTORE_WRITE_USERNAME:-datastore_write}" \
  -var="datastore_write_password=${DATASTORE_WRITE_PASSWORD:-pass}" \
  -var="datastore_read_username=${DATASTORE_READ_USERNAME:-datastore_read}" \
  -var="datastore_read_password=${DATASTORE_READ_PASSWORD:-pass}" \
  -out=tfplan

echo ""
echo "========================================"
echo "Review the plan above!"
echo "========================================"
echo ""
echo "Things to check:"
echo "  - Lines with + will be CREATED"
echo "  - Lines with ~ will be MODIFIED"
echo "  - Lines with - will be DESTROYED"
echo "  - Look at the summary at the end"
echo ""
read -p "Does this look correct? Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "Step 6: Applying changes..."
echo "--------------------------------"
echo "Creating your infrastructure in AWS..."
echo "This will take 10-15 minutes (RDS database is slow to create)"
echo ""

terraform apply tfplan

# Get outputs
echo ""
echo "========================================"
echo "Terraform deployment complete!"
echo "========================================"
echo ""
echo "Your infrastructure outputs:"
echo "----------------------------"
terraform output

echo ""
echo "Important information:"
echo "  - ALB URL: $(terraform output -raw alb_url 2>/dev/null || echo 'N/A')"
echo "  - Wait 2-3 minutes for ECS tasks to start"
echo "  - Then access CKAN at the ALB URL above"
echo ""
echo "Next steps:"
echo "  1. Wait for ECS tasks to be running (check AWS Console)"
echo "  2. Initialize CKAN database (see main README.md)"
echo "  3. Access your CKAN instance!"
