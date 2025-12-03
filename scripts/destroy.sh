#!/bin/bash
set -e

echo "========================================"
echo "CKAN to AWS: Destroy Infrastructure"
echo "========================================"
echo ""
echo "⚠️  WARNING: This will PERMANENTLY DELETE all resources!"
echo "   - ECS Services and Tasks"
echo "   - Application Load Balancer"
echo "   - RDS Database (ALL DATA WILL BE LOST)"
echo "   - ECR Repositories (all images)"
echo "   - Security Groups"
echo "   - VPC (if created by this project)"
echo "   - Secrets Manager secrets"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
source "$SCRIPT_DIR/tools/env-setup.sh"

# Navigate to terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Error: Terraform is not initialized. Run deploy.sh first or run:"
    echo "  ./scripts/030-terraform-init.sh"
    exit 1
fi

# Parse command line arguments
DRY_RUN=false
FORCE=false
KEEP_STATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --keep-state)
            KEEP_STATE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Show what would be destroyed without actually destroying"
            echo "  --force       Skip confirmation prompts (dangerous!)"
            echo "  --keep-state  Keep the S3 state bucket and DynamoDB table"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Show current state
echo "========================================"
echo "Current Infrastructure State"
echo "========================================"
echo "Project ID: ${UNIQUE_PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo ""

# List resources that will be destroyed
echo "Resources to be destroyed:"
terraform state list 2>/dev/null | head -50 || echo "  (unable to list state)"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "========================================"
    echo "DRY RUN: Showing destruction plan"
    echo "========================================"
    terraform plan -destroy
    echo ""
    echo "========================================"
    echo "This was a dry run. No resources were destroyed."
    echo "Remove --dry-run flag to actually destroy resources."
    echo "========================================"
    exit 0
fi

# Confirmation prompt
if [ "$FORCE" = false ]; then
    echo "========================================"
    echo "CONFIRMATION REQUIRED"
    echo "========================================"
    echo ""
    echo "Type the project ID to confirm destruction: ${UNIQUE_PROJECT_ID}"
    read -p "> " CONFIRM_PROJECT_ID
    
    if [ "$CONFIRM_PROJECT_ID" != "$UNIQUE_PROJECT_ID" ]; then
        echo ""
        echo "Confirmation failed. Aborting."
        exit 1
    fi
    
    echo ""
    echo "Are you absolutely sure? This action cannot be undone."
    read -p "Type 'yes' to proceed: " CONFIRM_YES
    
    if [ "$CONFIRM_YES" != "yes" ]; then
        echo ""
        echo "Aborting destruction."
        exit 1
    fi
fi

echo ""
echo "========================================"
echo "Starting Infrastructure Destruction"
echo "========================================"

# Step 1: Scale down ECS services first (graceful shutdown)
echo ""
echo "Step 1: Scaling down ECS services..."
SERVICE_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan"
CLUSTER_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster"

aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 0 \
    --region "$AWS_REGION" \
    $AWS_PROFILE_OPTION 2>/dev/null || echo "  Service not found or already scaled down"

echo "Waiting for tasks to stop (max 60 seconds)..."
sleep 10

# Step 2: Delete ECR images (required before deleting repos)
echo ""
echo "Step 2: Cleaning up ECR repositories..."
for REPO_NAME in "${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan" "${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-solr" "${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-redis"; do
    echo "  Deleting images from $REPO_NAME..."
    # Get all image digests and delete them
    IMAGE_IDS=$(aws ecr list-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        $AWS_PROFILE_OPTION \
        --query 'imageIds[*]' \
        --output json 2>/dev/null || echo "[]")
    
    if [ "$IMAGE_IDS" != "[]" ] && [ -n "$IMAGE_IDS" ]; then
        aws ecr batch-delete-image \
            --repository-name "$REPO_NAME" \
            --image-ids "$IMAGE_IDS" \
            --region "$AWS_REGION" \
            $AWS_PROFILE_OPTION 2>/dev/null || true
    fi
done

# Step 3: Run terraform destroy
echo ""
echo "Step 3: Destroying Terraform-managed resources..."
echo "This may take 10-15 minutes (RDS deletion is slow)..."
echo ""

if [ "$FORCE" = true ]; then
    terraform destroy -auto-approve
else
    terraform destroy
fi

# Step 4: Delete Secrets Manager secret (force delete without recovery)
echo ""
echo "Step 4: Deleting Secrets Manager secret..."
SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
aws secretsmanager delete-secret \
    --secret-id "$SECRET_NAME" \
    --force-delete-without-recovery \
    --region "$AWS_REGION" \
    $AWS_PROFILE_OPTION 2>/dev/null || echo "  Secret not found or already deleted"

# Step 5: Optionally delete state backend
if [ "$KEEP_STATE" = false ]; then
    echo ""
    echo "Step 5: Cleaning up Terraform state backend..."
    
    if [ "$FORCE" = false ]; then
        echo "Do you want to delete the Terraform state bucket and DynamoDB table?"
        echo "This will make it impossible to recover the state."
        read -p "Type 'yes' to delete state backend: " CONFIRM_STATE
    else
        CONFIRM_STATE="yes"
    fi
    
    if [ "$CONFIRM_STATE" = "yes" ]; then
        # Empty and delete S3 bucket
        echo "  Emptying S3 bucket: $TF_STATE_BUCKET..."
        aws s3 rm "s3://$TF_STATE_BUCKET" --recursive $AWS_PROFILE_OPTION 2>/dev/null || true
        
        # Delete bucket versioned objects
        echo "  Deleting versioned objects..."
        aws s3api list-object-versions \
            --bucket "$TF_STATE_BUCKET" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json $AWS_PROFILE_OPTION 2>/dev/null | \
        jq -c '.[]' | while read -r obj; do
            KEY=$(echo "$obj" | jq -r '.Key')
            VERSION_ID=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object \
                --bucket "$TF_STATE_BUCKET" \
                --key "$KEY" \
                --version-id "$VERSION_ID" \
                $AWS_PROFILE_OPTION 2>/dev/null || true
        done
        
        # Delete delete markers
        aws s3api list-object-versions \
            --bucket "$TF_STATE_BUCKET" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output json $AWS_PROFILE_OPTION 2>/dev/null | \
        jq -c '.[]' | while read -r obj; do
            KEY=$(echo "$obj" | jq -r '.Key')
            VERSION_ID=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object \
                --bucket "$TF_STATE_BUCKET" \
                --key "$KEY" \
                --version-id "$VERSION_ID" \
                $AWS_PROFILE_OPTION 2>/dev/null || true
        done
        
        echo "  Deleting S3 bucket..."
        aws s3api delete-bucket \
            --bucket "$TF_STATE_BUCKET" \
            --region "$AWS_REGION" \
            $AWS_PROFILE_OPTION 2>/dev/null || echo "  Bucket not found or already deleted"
        
        # Delete DynamoDB table
        if [ "$TF_STATE_USE_DYNAMODB" = "true" ]; then
            echo "  Deleting DynamoDB table: $TF_STATE_DYNAMODB_TABLE..."
            aws dynamodb delete-table \
                --table-name "$TF_STATE_DYNAMODB_TABLE" \
                --region "$AWS_REGION" \
                $AWS_PROFILE_OPTION 2>/dev/null || echo "  Table not found or already deleted"
        fi
        
        echo "  State backend deleted."
    else
        echo "  Keeping state backend."
    fi
else
    echo ""
    echo "Step 5: Skipping state backend deletion (--keep-state flag)"
fi

# Clean up local files
echo ""
echo "Step 6: Cleaning up local files..."
rm -f terraform.tfvars tfplan .terraform.lock.hcl 2>/dev/null || true
rm -rf .terraform 2>/dev/null || true

echo ""
echo "========================================"
echo "Infrastructure Destruction Complete!"
echo "========================================"
echo ""
echo "All resources have been destroyed."
if [ "$KEEP_STATE" = true ]; then
    echo "Note: State bucket ($TF_STATE_BUCKET) was preserved."
fi
echo ""
