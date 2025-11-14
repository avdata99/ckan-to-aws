#!/bin/bash
set -e

echo "========================================"
echo "Terraform Backend Setup"
echo "========================================"

# Load environment variables from the main setup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

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
echo "Next steps:"
echo "1. Run './scripts/030-terraform-init.sh' to initialize Terraform with the new backend."
echo "========================================"
