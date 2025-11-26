#!/bin/bash
set -e

echo "========================================"
echo "CKAN to AWS: Full Deployment Workflow"
echo "========================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Load environment variables from the main setup script
source "$SCRIPT_DIR/tools/env-setup.sh"

# 1. Setup Terraform backend (S3 + DynamoDB)
echo "========================================"
echo "Terraform Backend Setup"
echo "========================================"

# --- Validate Backend Variables ---
if [ -z "$TF_STATE_BUCKET" ] || [ -z "$TF_STATE_DYNAMODB_TABLE" ]; then
    echo "Error: TF_STATE_BUCKET and TF_STATE_DYNAMODB_TABLE must be set in your .env file."
    exit 1
fi

# --- 1. S3 Bucket for Terraform State ---
echo "Checking for S3 bucket: $TF_STATE_BUCKET..."
if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" $AWS_PROFILE_OPTION 2>/dev/null; then
    echo "S3 bucket already exists. Checking if you have access..."
    if aws s3api get-bucket-acl --bucket "$TF_STATE_BUCKET" $AWS_PROFILE_OPTION >/dev/null 2>&1; then
        echo "Access to S3 bucket confirmed."
    else
        echo "Error: You do not have access to the S3 bucket '$TF_STATE_BUCKET'."
        exit 1
    fi

else
    echo "S3 bucket not found. Creating it..."
    aws s3api create-bucket \
        --bucket "$TF_STATE_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" \
        $AWS_PROFILE_OPTION
    echo "S3 bucket created."
fi

# --- 2. S3 Bucket Versioning ---
if [ "$TF_STATE_BUCKET_VERSIONING" = "true" ]; then
    echo "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "$TF_STATE_BUCKET" \
        --versioning-configuration Status=Enabled \
        $AWS_PROFILE_OPTION
    echo "Versioning enabled."
else
    echo "Skipping S3 bucket versioning."
fi

# --- 3. DynamoDB Table for State Locking ---
if [ "$TF_STATE_USE_DYNAMODB" = "true" ]; then
    echo "Checking for DynamoDB table: $TF_STATE_DYNAMODB_TABLE..."
    if aws dynamodb describe-table --table-name "$TF_STATE_DYNAMODB_TABLE" $AWS_PROFILE_OPTION --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "DynamoDB table already exists."
    else
        echo "DynamoDB table not found. Creating it..."
        aws dynamodb create-table \
            --table-name "$TF_STATE_DYNAMODB_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --region "$AWS_REGION" \
            $AWS_PROFILE_OPTION
        echo "Waiting for DynamoDB table to become active..."
        aws dynamodb wait table-exists --table-name "$TF_STATE_DYNAMODB_TABLE" --region "$AWS_REGION" $AWS_PROFILE_OPTION
        echo "DynamoDB table created."
    fi
else
    echo "Skipping DynamoDB table setup for state locking as per TF_STATE_USE_DYNAMODB setting."
fi

echo "========================================"
echo "Backend setup complete!"
echo "========================================"


# 2. Initialize Terraform
echo "========================================"
echo "Terraform Initialization"
echo "========================================"

# Navigate to the terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

echo "Initializing Terraform with S3 backend..."
# Base init command
# NOTE: If you get a "Backend configuration changed" error, you need to manually run:
#   terraform init -migrate-state -backend-config=... (to migrate existing state)
#   OR terraform init -reconfigure -backend-config=... (to start fresh, loses state!)
INIT_CMD="terraform init -backend-config=\"bucket=$TF_STATE_BUCKET\" -backend-config=\"key=$TF_STATE_KEY\" -backend-config=\"region=$AWS_REGION\" -backend-config=\"encrypt=true\""

# Conditionally add DynamoDB table for state locking
if [ "$TF_STATE_USE_DYNAMODB" = "true" ]; then
    echo "Enabling DynamoDB for state locking."
    INIT_CMD="$INIT_CMD -backend-config=\"dynamodb_table=$TF_STATE_DYNAMODB_TABLE\""
else
    echo "WARNING: State locking with DynamoDB is disabled."
fi

# Execute the terraform init command
eval $INIT_CMD

echo "========================================"
echo "Terraform initialized successfully!"
echo "========================================"

# 3. Deploy VPC and generate tfvars
echo "========================================"
echo "Deploying Network (VPC)"
echo "========================================"

# --- Validate Inputs for Shared VPC ---
if [ "${CREATE_VPC}" = "false" ]; then
  if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_IDS" ] || [ -z "$PRIVATE_SUBNET_IDS" ]; then
    echo "Error: When CREATE_VPC is false, you must provide VPC_ID, PUBLIC_SUBNET_IDS, and PRIVATE_SUBNET_IDS in your .env file."
    exit 1
  fi
fi

# Create a terraform.tfvars file to pass variables from .env
# This is how we connect shell variables to Terraform variables
echo "Generating terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_id  = "$UNIQUE_PROJECT_ID"
environment = "$ENVIRONMENT"
aws_region  = "$AWS_REGION"
create_vpc  = ${CREATE_VPC:-true}
allowed_cidr_blocks = ${ALLOWED_CIDR_BLOCKS:-'["0.0.0.0/0"]'}

# Database configuration
db_instance_class         = "${DB_INSTANCE_CLASS:-db.t3.micro}"
db_allocated_storage      = ${DB_ALLOCATED_STORAGE:-20}
db_engine_version         = "${DB_ENGINE_VERSION:-15}"
db_name                   = "${DB_NAME:-ckan}"
db_username               = "${DB_USERNAME:-ckan_admin}"
db_password               = "${DB_PASSWORD}"
db_multi_az               = ${DB_MULTI_AZ:-false}
db_backup_retention_days  = ${DB_BACKUP_RETENTION_DAYS:-7}
db_deletion_protection    = ${DB_DELETION_PROTECTION:-false}
db_encryption_enabled     = ${DB_ENCRYPTION_ENABLED:-true}

# ECS configuration
ecs_launch_type     = "${ECS_LAUNCH_TYPE:-FARGATE}"
ckan_task_cpu       = ${CKAN_TASK_CPU:-512}
ckan_task_memory    = ${CKAN_TASK_MEMORY:-1024}
solr_task_cpu       = ${SOLR_TASK_CPU:-256}
solr_task_memory    = ${SOLR_TASK_MEMORY:-512}
redis_task_cpu      = ${REDIS_TASK_CPU:-256}
redis_task_memory   = ${REDIS_TASK_MEMORY:-512}

# ECR configuration
ecr_ckan_repo_name  = "${ECR_CKAN_REPO_NAME:-ckan}"
ecr_solr_repo_name  = "${ECR_SOLR_REPO_NAME:-solr}"
ecr_redis_repo_name = "${ECR_REDIS_REPO_NAME:-redis}"
image_tag           = "${IMAGE_TAG:-latest}"
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
if [[ -n "$DB_SUBNET_IDS" ]]; then
  echo "db_subnet_ids = $DB_SUBNET_IDS" >> terraform.tfvars
fi

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

# 4. Deploy Security Groups
echo "========================================"
echo "Deploying Security Groups"
echo "========================================"

echo "Planning Security Groups deployment (targeting module.security_groups)..."
terraform plan -out=tfplan -target=module.security_groups

echo "Applying Security Groups deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "Security Groups Deployment Complete!"
echo "========================================"

# 5. Deploy RDS (PostgreSQL)
echo "========================================"
echo "Deploying RDS (PostgreSQL Database)"
echo "========================================"

# Validate required DB variables
if [ -z "$DB_PASSWORD" ]; then
  echo "Error: DB_PASSWORD must be set in your .env file."
  exit 1
fi

if [ -z "$DB_SUBNET_IDS" ]; then
  echo "Error: DB_SUBNET_IDS must be set in your .env file."
  exit 1
fi

echo "Planning RDS deployment (targeting module.rds)..."
echo "Note: RDS provisioning typically takes 10-15 minutes."
terraform plan -out=tfplan -target=module.rds

echo "Applying RDS deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "RDS Deployment Complete!"
echo "========================================"

# 6. Deploy ECR repositories
echo "========================================"
echo "Deploying ECR Repositories"
echo "========================================"

# Ensure terraform.tfvars is up to date
if [ ! -f terraform.tfvars ]; then
  echo "Error: terraform.tfvars not found. Please run 050-deploy-vpc.sh first."
  exit 1
fi

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
echo "========================================"

# 7. Build and push Docker images to ECR
echo "========================================"
echo "Building and Pushing Docker Images to ECR"
echo "========================================"

# Get ECR repository URLs from Terraform outputs
echo "Getting ECR repository URLs from Terraform..."

CKAN_REPO=$(terraform output -raw ecr_ckan_repository_url 2>/dev/null || echo "")
SOLR_REPO=$(terraform output -raw ecr_solr_repository_url 2>/dev/null || echo "")
REDIS_REPO=$(terraform output -raw ecr_redis_repository_url 2>/dev/null || echo "")

if [ -z "$CKAN_REPO" ] || [ -z "$SOLR_REPO" ] || [ -z "$REDIS_REPO" ]; then
  echo "Error: Could not get ECR repository URLs."
  echo "Please run './scripts/075-deploy-ecr.sh' first to create ECR repositories."
  exit 1
fi

echo "ECR Repositories:"
echo "  CKAN:  $CKAN_REPO"
echo "  Solr:  $SOLR_REPO"
echo "  Redis: $REDIS_REPO"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" $AWS_PROFILE_OPTION | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Navigate to docker directory
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "Using image tag: $IMAGE_TAG"
echo ""

# ============================================================================
# Build and Push CKAN
# ============================================================================
echo "========================================"
echo "Building CKAN Image"
echo "========================================"
cd "$DOCKER_DIR/ckan"

# Copy .env file to the location expected by Dockerfile
echo "Copying .env to ckan/files/env/AWS.env..."
mkdir -p files/env
cp "$ROOT_DIR/.env" files/env/AWS.env

# Build CKAN image with proper build args
echo "Building CKAN image..."
docker build \
  --build-arg TZ=America/Argentina/Buenos_Aires \
  --build-arg ENV_NAME=AWS \
  -t "ckan_aws:$IMAGE_TAG" \
  -t "$CKAN_REPO:$IMAGE_TAG" \
  .

echo "Pushing CKAN image to ECR..."
docker push "$CKAN_REPO:$IMAGE_TAG"
echo "CKAN image pushed successfully"
echo ""

# ============================================================================
# Build and Push Solr
# ============================================================================
echo "========================================"
echo "Building Solr Image"
echo "========================================"
cd "$DOCKER_DIR/solr"

echo "Building Solr image..."
docker build \
  -t "solr_aws:$IMAGE_TAG" \
  -t "$SOLR_REPO:$IMAGE_TAG" \
  .

echo "Pushing Solr image to ECR..."
docker push "$SOLR_REPO:$IMAGE_TAG"
echo "Solr image pushed successfully"
echo ""

# ============================================================================
# Build and Push Redis
# ============================================================================
echo "========================================"
echo "Building Redis Image"
echo "========================================"
cd "$DOCKER_DIR/redis"

echo "Building Redis image..."
docker build \
  -t "redis_aws:$IMAGE_TAG" \
  -t "$REDIS_REPO:$IMAGE_TAG" \
  .

echo "Pushing Redis image to ECR..."
docker push "$REDIS_REPO:$IMAGE_TAG"
echo "Redis image pushed successfully"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "========================================"
echo "All Images Built and Pushed Successfully!"
echo "========================================"
echo ""
echo "Images in ECR:"
echo "  $CKAN_REPO:$IMAGE_TAG"
echo "  $SOLR_REPO:$IMAGE_TAG"
echo "  $REDIS_REPO:$IMAGE_TAG"
echo "========================================"


# 8. Push secrets to AWS Secrets Manager
echo "========================================"
echo "Push Secrets to AWS Secrets Manager"
echo "========================================"

SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
echo "Creating/Updating secret: $SECRET_NAME"
echo ""

# Get RDS endpoint from Terraform if available
echo "Checking if RDS exists to get endpoint..."
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-db \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text 2>/dev/null || echo "")

if [ -n "$RDS_ENDPOINT" ]; then
    DB_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    echo "Found RDS endpoint: $DB_HOST"
else
    DB_HOST="will-be-set-by-terraform"
    echo "RDS not yet deployed, using placeholder"
fi

# Try to get existing secret values if the secret exists
EXISTING_SECRET_JSON=""
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region $AWS_REGION $AWS_PROFILE_OPTION >/dev/null 2>&1; then
  EXISTING_SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region $AWS_REGION \
    $AWS_PROFILE_OPTION \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")
fi

# Helper to extract a value from the existing secret JSON or generate a new one
get_or_generate_secret() {
  local key="$1"
  local gen_cmd="$2"
  if [ -n "$EXISTING_SECRET_JSON" ]; then
    local val=$(echo "$EXISTING_SECRET_JSON" | jq -r --arg k "$key" '.[$k]')
    if [ "$val" != "null" ] && [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  eval "$gen_cmd"
}

DATASTORE_READ_PASSWORD=$(get_or_generate_secret "datastore_read_password" "openssl rand -hex 16")
DATASTORE_WRITE_PASSWORD=$(get_or_generate_secret "datastore_write_password" "openssl rand -hex 16")
SECRET_KEY=$(get_or_generate_secret "secret_key" "openssl rand -hex 32")
BEAKER_SESSION_SECRET=$(get_or_generate_secret "beaker_session_secret" "openssl rand -hex 32")
BEAKER_SESSION_VALIDATE_KEY=$(get_or_generate_secret "beaker_session_validate_key" "openssl rand -hex 32")

# Build the secret JSON with ALL application secrets
SECRET_JSON=$(cat <<EOF
{
  "db_username": "${DB_USERNAME}",
  "db_password": "${DB_PASSWORD}",
  "db_host": "${DB_HOST}",
  "db_port": "5432",
  "db_name": "${DB_NAME}",
  "datastore_db": "datastore",
  "datastore_read_user": "datastore_read",
  "datastore_read_password": "${DATASTORE_READ_PASSWORD}",
  "datastore_write_user": "datastore_write",
  "datastore_write_password": "${DATASTORE_WRITE_PASSWORD}",
  "secret_key": "${SECRET_KEY}",
  "beaker_session_secret": "${BEAKER_SESSION_SECRET}",
  "beaker_session_validate_key": "${BEAKER_SESSION_VALIDATE_KEY}"
}
EOF
)

# Check if secret exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region $AWS_REGION $AWS_PROFILE_OPTION >/dev/null 2>&1; then
  echo "Secret already exists. Updating..."
  # Only update if we have real values (don't overwrite with placeholders)
  if [ "$DB_HOST" != "will-be-set-by-terraform" ]; then
      aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_JSON" \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION
      echo "Secret updated with current values"
  else
      echo "⚠ Skipping update (RDS not deployed yet, keeping existing secret)"
  fi
else
  echo "Secret does not exist. Creating..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "All secrets for CKAN ${ENVIRONMENT} environment" \
    --secret-string "$SECRET_JSON" \
    --region $AWS_REGION \
    $AWS_PROFILE_OPTION
  echo "Secret created"
fi

echo ""
echo "========================================"
echo "Secrets Successfully Stored in AWS!"
echo "========================================"
echo ""
echo "Secret ARN:"
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'ARN' \
  --output text)
echo "$SECRET_ARN"
echo ""
echo "This secret contains:"
echo "  - Main database credentials (username, password)"
echo "  - Database connection info (host, port, db name)"
echo "  - Datastore database credentials (read and write users)"
echo "  - CKAN secrets (SECRET_KEY, BEAKER_SESSION_SECRET, etc.)"
echo ""
echo "Important Security Notes:"
echo "  - Secrets are encrypted at rest with AWS KMS"
echo "  - Access is controlled via IAM policies"
echo "========================================"


# 9. Deploy ECS Cluster
echo "========================================"
echo "Deploying ECS Cluster"
echo "========================================"


echo "Planning ECS Cluster deployment (targeting module.ecs_cluster)..."
terraform plan -out=tfplan -target=module.ecs_cluster

echo "Applying ECS Cluster deployment..."
echo "Terraform will now ask for confirmation. Review the plan and type 'yes' to approve."
terraform apply tfplan

echo "========================================"
echo "ECS Cluster Deployment Complete!"
echo "========================================"

# 10. Deploy ECS Task Definitions
echo "========================================"
echo "Deploying ECS Task Definitions"
echo "========================================"

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
echo "Task Definition created:"
echo "  - All-in-One Task (CKAN + Solr + Redis using localhost)"
echo "========================================"


# 11. Deploy Application Load Balancer
echo "========================================"
echo "Deploying Application Load Balancer (ALB)"
echo "========================================"

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
echo "========================================"


# 12. Deploy All-in-One ECS Service (CKAN+Solr+Redis)
echo "========================================"
echo "Deploying All-in-One Service (CKAN + Solr + Redis)"
echo "========================================"

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


echo "========================================"
echo "Full deployment complete!"
echo "========================================"
echo "You can now start the ECS service if desired."
echo "See the output above for the ALB URL and next steps."
