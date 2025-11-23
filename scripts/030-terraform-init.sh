#!/bin/bash
set -e

echo "========================================"
echo "Terraform Initialization"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Navigate to the terraform directory
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

echo "Initializing Terraform with S3 backend..."
if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS Profile: $AWS_PROFILE"
else
    echo "Using default AWS profile."
fi

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
