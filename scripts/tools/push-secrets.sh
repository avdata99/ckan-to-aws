#!/bin/bash
set -e

echo "========================================"
echo "Push Secrets to AWS Secrets Manager"
echo "========================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment variables from .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Error: No .env file found at $PROJECT_ROOT/.env"
    exit 1
fi

# Set AWS profile option if specified
AWS_PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_OPTION="--profile $AWS_PROFILE"
fi

# Parse command line arguments
FORCE_UPDATE=false
UPDATE_RDS_ENDPOINT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --update-rds-endpoint)
            UPDATE_RDS_ENDPOINT=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force              Force update all secrets (WARNING: overwrites existing values)"
            echo "  --update-rds-endpoint  Only update the RDS endpoint in existing secret"
            echo "  --help               Show this help message"
            echo ""
            echo "This script creates or updates secrets in AWS Secrets Manager."
            echo "By default, it will NOT overwrite existing secrets unless --force is used."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
echo "Secret name: $SECRET_NAME"
echo ""

# Check if secret already exists
SECRET_EXISTS=false
EXISTING_SECRET_JSON=""
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region $AWS_REGION $AWS_PROFILE_OPTION >/dev/null 2>&1; then
    SECRET_EXISTS=true
    EXISTING_SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "")
fi

# Handle --update-rds-endpoint mode
if [ "$UPDATE_RDS_ENDPOINT" = true ]; then
    if [ "$SECRET_EXISTS" = false ]; then
        echo "Error: Secret does not exist. Cannot update RDS endpoint."
        echo "Run this script without --update-rds-endpoint first to create the secret."
        exit 1
    fi
    
    echo "Fetching RDS endpoint..."
    RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-db \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" = "None" ]; then
        echo "Error: Could not fetch RDS endpoint. Is the RDS instance deployed?"
        exit 1
    fi
    
    DB_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    echo "Found RDS endpoint: $DB_HOST"
    
    # Update only the db_host in existing secret
    UPDATED_SECRET_JSON=$(echo "$EXISTING_SECRET_JSON" | jq --arg host "$DB_HOST" '.db_host = $host')
    
    aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$UPDATED_SECRET_JSON" \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION
    
    echo ""
    echo "========================================"
    echo "RDS endpoint updated in secret!"
    echo "========================================"
    exit 0
fi

# Check if we should proceed with creating/updating secrets
if [ "$SECRET_EXISTS" = true ] && [ "$FORCE_UPDATE" = false ]; then
    echo "========================================"
    echo "WARNING: Secret already exists!"
    echo "========================================"
    echo ""
    echo "The secret '$SECRET_NAME' already exists in AWS Secrets Manager."
    echo ""
    echo "Options:"
    echo "  1. Use --force to overwrite all values (DANGEROUS)"
    echo "  2. Use --update-rds-endpoint to only update the RDS endpoint"
    echo "  3. Manually edit the secret in AWS Console"
    echo ""
    echo "Current secret contains keys:"
    echo "$EXISTING_SECRET_JSON" | jq -r 'keys[]' | sed 's/^/  - /'
    echo ""
    exit 0
fi

if [ "$FORCE_UPDATE" = true ]; then
    echo "========================================"
    echo "WARNING: Force update enabled!"
    echo "========================================"
    echo "This will OVERWRITE existing secret values."
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# Validate required variables from .env
if [ -z "$DB_PASSWORD" ]; then
    echo "Error: DB_PASSWORD must be set in your .env file."
    exit 1
fi

if [ -z "$DB_USERNAME" ]; then
    echo "Error: DB_USERNAME must be set in your .env file."
    exit 1
fi

# Get RDS endpoint if available
echo "Checking if RDS is deployed to get endpoint..."
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-db \
    --region $AWS_REGION \
    $AWS_PROFILE_OPTION \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text 2>/dev/null || echo "")

if [ -n "$RDS_ENDPOINT" ] && [ "$RDS_ENDPOINT" != "None" ]; then
    DB_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
    echo "Found RDS endpoint: $DB_HOST"
else
    DB_HOST=""
    echo "RDS not yet deployed. DB_HOST will be empty."
    echo "After deploying RDS, run: $0 --update-rds-endpoint"
fi

# Helper to extract a value from the existing secret JSON or generate a new one
get_or_generate_secret() {
    local key="$1"
    local gen_cmd="$2"
    if [ -n "$EXISTING_SECRET_JSON" ] && [ "$FORCE_UPDATE" = false ]; then
        local val=$(echo "$EXISTING_SECRET_JSON" | jq -r --arg k "$key" '.[$k]')
        if [ "$val" != "null" ] && [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi
    eval "$gen_cmd"
}

echo "Generating secret values..."
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
  "db_name": "${DB_NAME:-ckan}",
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

if [ "$SECRET_EXISTS" = true ]; then
    echo "Updating existing secret..."
    aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_JSON" \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION
    echo "Secret updated."
else
    echo "Creating new secret..."
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "All secrets for CKAN ${ENVIRONMENT} environment" \
        --secret-string "$SECRET_JSON" \
        --region $AWS_REGION \
        $AWS_PROFILE_OPTION
    echo "Secret created."
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
echo "  $SECRET_ARN"
echo ""
echo "This secret contains:"
echo "  - Main database credentials (username, password)"
echo "  - Database connection info (host, port, db name)"
echo "  - Datastore database credentials (read and write users)"
echo "  - CKAN secrets (SECRET_KEY, BEAKER_SESSION_SECRET, etc.)"
echo ""
if [ -z "$DB_HOST" ]; then
    echo "========================================"
    echo "IMPORTANT: RDS endpoint not set!"
    echo "========================================"
    echo "After deploying RDS, run:"
    echo "  $0 --update-rds-endpoint"
    echo ""
fi
echo "Security Notes:"
echo "  - Secrets are encrypted at rest with AWS KMS"
echo "  - Access is controlled via IAM policies"
echo "  - Never commit secrets to version control"
echo "========================================"
