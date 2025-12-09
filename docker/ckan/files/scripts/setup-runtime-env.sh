#!/bin/bash
# Unified environment setup script
# Priority: AWS Secrets Manager (highest) > ECS Task Environment > .env file (lowest)

echo "================================================"
echo "Setting up runtime environment..."
echo "================================================"

# -----------------------------------------------------------------------------
# Step 1: Load local .env as base defaults
# -----------------------------------------------------------------------------
if [ -f "${APP_DIR}/.env" ]; then
    echo "Loading base defaults from ${APP_DIR}/.env"
    set -o allexport
    source "${APP_DIR}/.env"
    set +o allexport
else
    echo "WARNING: No .env file found at ${APP_DIR}/.env"
fi

# -----------------------------------------------------------------------------
# Step 2: Check if running in AWS
# -----------------------------------------------------------------------------
IN_AWS=false
if [ -n "$AWS_EXECUTION_ENV" ] || [ -n "$ECS_CONTAINER_METADATA_URI" ]; then
    IN_AWS=true
    echo "Running in AWS ECS"
    
    # IMPORTANT: Unset AWS_PROFILE - ECS uses task IAM role for authentication
    # The profile from .env is for local development only
    unset AWS_PROFILE
    echo "Cleared AWS_PROFILE (using ECS task role for authentication)"
    
    # Clear placeholder URLs from .env - they will be rebuilt from secrets
    unset SQLALCHEMY_URL
    unset DATASTORE_READ_URL
    unset DATASTORE_WRITE_URL
    echo "Cleared placeholder URLs (will rebuild from secrets)"
else
    echo "Running locally (not in ECS)"
fi

# -----------------------------------------------------------------------------
# Step 3: If in AWS, fetch secrets and override local values
# -----------------------------------------------------------------------------
if [ "$IN_AWS" = true ]; then
    # Activate venv for AWS CLI
    if [ -f "${APP_DIR}/venv/bin/activate" ]; then
        source "${APP_DIR}/venv/bin/activate"
    fi

    # Verify AWS CLI
    if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI not found"
        exit 1
    fi

    # Validate required variables
    if [ -z "$UNIQUE_PROJECT_ID" ] || [ -z "$ENVIRONMENT" ]; then
        echo "ERROR: UNIQUE_PROJECT_ID and ENVIRONMENT must be set"
        exit 1
    fi

    SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
    echo "Fetching secrets from: $SECRET_NAME"

    # Fetch the main secret
    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --region "${AWS_REGION:-us-east-2}" \
        --query 'SecretString' \
        --output text 2>&1)

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to fetch secrets from AWS Secrets Manager"
        echo "$SECRET_JSON"
        exit 1
    fi

    # Export each key from the secret as an environment variable (UPPERCASE)
    # This automatically overrides any values from .env
    echo "Exporting secrets as environment variables..."
    
    for key in $(echo "$SECRET_JSON" | jq -r 'keys[]'); do
        value=$(echo "$SECRET_JSON" | jq -r ".[\"$key\"]")
        # Convert to uppercase for env var name
        upper_key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
        export "$upper_key=$value"
        echo "  ✓ $upper_key"
    done

    # -----------------------------------------------------------------------------
    # Step 4: Load extension-specific secrets
    # -----------------------------------------------------------------------------
    EXTENSIONS_LIST_FILE="${APP_DIR}/extensions/extensions.list.txt"
    
    if [ -f "$EXTENSIONS_LIST_FILE" ]; then
        echo ""
        echo "Loading extension secrets..."
        
        while IFS= read -r extension || [ -n "$extension" ]; do
            # Skip comments and empty lines
            [[ "$extension" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${extension// }" ]] && continue
            
            extension=$(echo "$extension" | xargs)
            SECRETS_FILE="${APP_DIR}/extensions/$extension/extension.secrets.txt"
            
            [ ! -f "$SECRETS_FILE" ] && continue
            
            echo "  Extension: $extension"
            
            while IFS= read -r secret_line || [ -n "$secret_line" ]; do
                # Skip comments and empty lines
                [[ "$secret_line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${secret_line// }" ]] && continue
                
                secret_line=$(echo "$secret_line" | xargs)
                
                # Parse: ENV_VAR=json_key (secrets come from main secret)
                ENV_VAR=$(echo "$secret_line" | cut -d'=' -f1)
                JSON_KEY=$(echo "$secret_line" | cut -d'=' -f2- | sed 's/.*://')  # Get key after colon
                
                if [ -z "$ENV_VAR" ] || [ -z "$JSON_KEY" ]; then
                    continue
                fi
                
                # Extract value from the already-fetched secret
                SECRET_VALUE=$(echo "$SECRET_JSON" | jq -r ".[\"$JSON_KEY\"] // empty")
                
                if [ -n "$SECRET_VALUE" ]; then
                    export "$ENV_VAR=$SECRET_VALUE"
                    echo "    ✓ $ENV_VAR"
                else
                    echo "    ⚠ $ENV_VAR (key '$JSON_KEY' not found)"
                fi
                
            done < "$SECRETS_FILE"
            
        done < "$EXTENSIONS_LIST_FILE"
    fi
fi

# -----------------------------------------------------------------------------
# Step 5: Build derived URLs (if components are available)
# -----------------------------------------------------------------------------
echo ""
echo "Building database URLs..."
echo "  DB_HOST=$DB_HOST"
echo "  DB_USERNAME=$DB_USERNAME"
echo "  DB_NAME=$DB_NAME"
echo "  DATASTORE_READ_USER=$DATASTORE_READ_USER"
echo "  DATASTORE_WRITE_USER=$DATASTORE_WRITE_USER"

if [ -n "$DB_HOST" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    export SQLALCHEMY_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DB_NAME:-ckan}"
    echo "✓ SQLALCHEMY_URL configured: ${DB_USERNAME}@${DB_HOST}/${DB_NAME:-ckan}"
else
    echo "⚠ SQLALCHEMY_URL not configured (missing DB_HOST, DB_USERNAME, or DB_PASSWORD)"
fi

if [ -n "$DB_HOST" ] && [ -n "$DATASTORE_WRITE_USER" ] && [ -n "$DATASTORE_WRITE_PASSWORD" ]; then
    export DATASTORE_WRITE_URL="postgresql://${DATASTORE_WRITE_USER}:${DATASTORE_WRITE_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DATASTORE_DB:-datastore}"
    export DATASTORE_WRITE_USERNAME="${DATASTORE_WRITE_USER}"
    echo "✓ DATASTORE_WRITE_URL configured"
else
    echo "⚠ DATASTORE_WRITE_URL not configured (missing DB_HOST, DATASTORE_WRITE_USER, or DATASTORE_WRITE_PASSWORD)"
fi

if [ -n "$DB_HOST" ] && [ -n "$DATASTORE_READ_USER" ] && [ -n "$DATASTORE_READ_PASSWORD" ]; then
    export DATASTORE_READ_URL="postgresql://${DATASTORE_READ_USER}:${DATASTORE_READ_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DATASTORE_DB:-datastore}"
    export DATASTORE_READ_USERNAME="${DATASTORE_READ_USER}"
    echo "✓ DATASTORE_READ_URL configured"
else
    echo "⚠ DATASTORE_READ_URL not configured (missing DB_HOST, DATASTORE_READ_USER, or DATASTORE_READ_PASSWORD)"
fi

export DATASTORE_DB_NAME="${DATASTORE_DB:-datastore}"

echo ""
echo "================================================"
echo "Environment setup complete"
echo "================================================"
