#!/bin/bash
set -e

echo "========================================"
echo "Push Secrets to AWS Secrets Manager"
echo "========================================"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Single secret name for all application secrets
SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"

echo "Creating/Updating secret: $SECRET_NAME"
echo ""

# Get RDS endpoint from Terraform if available
echo "Checking if RDS exists to get endpoint..."
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"

RDS_ENDPOINT=$(terraform output -raw db_endpoint 2>/dev/null || echo "")
if [ -n "$RDS_ENDPOINT" ]; then
    DB_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    echo "Found RDS endpoint: $DB_HOST"
else
    DB_HOST="will-be-set-by-terraform"
    echo "⚠ RDS not yet deployed, using placeholder"
fi

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
  "datastore_read_password": "$(openssl rand -hex 16)",
  "datastore_write_user": "datastore_write",
  "datastore_write_password": "$(openssl rand -hex 16)",
  "secret_key": "$(openssl rand -hex 32)",
  "beaker_session_secret": "$(openssl rand -hex 32)",
  "beaker_session_validate_key": "$(openssl rand -hex 32)"
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
echo "  - All access is logged in CloudTrail"
echo "  - Random secrets (SECRET_KEY, etc.) were generated if this was first run"
echo ""
echo "Next steps:"
echo "1. Task definitions will automatically read from this secret"
echo "2. Run deployment: ./scripts/085-update-and-deploy.sh"
echo "========================================"
