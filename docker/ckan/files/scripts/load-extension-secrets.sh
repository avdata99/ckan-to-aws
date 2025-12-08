#!/bin/bash
# Load secrets from AWS Secrets Manager for CKAN extensions
# Each extension can define required secrets in extension.secrets.txt

echo "================================================"
echo "Loading extension secrets..."
echo "================================================"

EXTENSIONS_LIST_FILE="${APP_DIR}/extensions/extensions.list.txt"

# Source the environment file if variables are not set
# This handles cases where env vars weren't passed to the container
if [ -z "$UNIQUE_PROJECT_ID" ] || [ -z "$ENVIRONMENT" ]; then
    if [ -f "${APP_DIR}/.env" ]; then
        echo "Sourcing ${APP_DIR}/.env for missing variables..."
        source "${APP_DIR}/.env"
    fi
fi

# Debug: Show relevant environment variables
echo "Debug: APP_DIR=$APP_DIR"
echo "Debug: UNIQUE_PROJECT_ID=$UNIQUE_PROJECT_ID"
echo "Debug: ENVIRONMENT=$ENVIRONMENT"
echo "Debug: AWS_REGION=$AWS_REGION"

# Validate required variables before constructing SECRET_NAME
if [ -z "$UNIQUE_PROJECT_ID" ]; then
    echo "ERROR: UNIQUE_PROJECT_ID is not set"
    echo "Please ensure UNIQUE_PROJECT_ID is defined in your ECS task definition or .env file"
    exit 1
fi
if [ -z "$ENVIRONMENT" ]; then
    echo "ERROR: ENVIRONMENT is not set"
    echo "Please ensure ENVIRONMENT is defined in your ECS task definition or .env file"
    exit 1
fi

# Export common variables that extensions might reference in their secrets files
export SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
echo "Using SECRET_NAME: $SECRET_NAME"

if [ ! -f "$EXTENSIONS_LIST_FILE" ]; then
    echo "No extensions list found, skipping extension secrets"
    exit 0
fi

# Check if we're running in AWS
if [ -z "$AWS_EXECUTION_ENV" ] && [ -z "$ECS_CONTAINER_METADATA_URI" ]; then
    echo "Not running in AWS ECS - skipping AWS Secrets Manager lookups"
    echo "Extensions should handle local secrets via .env file"
    exit 0
fi

# Process each extension
while IFS= read -r extension || [ -n "$extension" ]; do
    # Skip comments and empty lines
    [[ "$extension" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${extension// }" ]] && continue
    
    extension=$(echo "$extension" | xargs)  # trim whitespace
    
    EXTENSION_DIR="${APP_DIR}/extensions/$extension"
    SECRETS_FILE="$EXTENSION_DIR/extension.secrets.txt"
    
    if [ ! -f "$SECRETS_FILE" ]; then
        continue
    fi
    
    echo "Loading secrets for extension: $extension"
    
    # Read each secret definition
    # Format: ENV_VAR_NAME=secret-name:json-key
    # Example: S3_AWS_ACCESS_KEY_ID=myproject-dev-s3-secrets:access_key_id
    # Supports variable substitution: S3_BUCKET_NAME=${SECRET_NAME}:bucket_name
    while IFS= read -r secret_line || [ -n "$secret_line" ]; do
        # Skip comments and empty lines
        [[ "$secret_line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${secret_line// }" ]] && continue
        
        secret_line=$(echo "$secret_line" | xargs)  # trim whitespace
        
        # Parse the line: ENV_VAR=secret-name:json-key
        ENV_VAR=$(echo "$secret_line" | cut -d'=' -f1)
        SECRET_REF=$(echo "$secret_line" | cut -d'=' -f2-)
        
        if [ -z "$ENV_VAR" ] || [ -z "$SECRET_REF" ]; then
            echo "  Warning: Invalid secret definition: $secret_line"
            continue
        fi
        
        # Expand environment variables in SECRET_REF (e.g., ${SECRET_NAME} -> actual value)
        SECRET_REF_EXPANDED=$(eval echo "$SECRET_REF")
        
        # Check if it contains a JSON key reference
        if [[ "$SECRET_REF_EXPANDED" == *":"* ]]; then
            SECRET_ID=$(echo "$SECRET_REF_EXPANDED" | cut -d':' -f1)
            JSON_KEY=$(echo "$SECRET_REF_EXPANDED" | cut -d':' -f2-)
            
            echo "  Fetching $ENV_VAR from '$SECRET_ID' (key: $JSON_KEY)"
            
            # Fetch the secret and extract the JSON key
            AWS_ERROR=$(mktemp)
            SECRET_JSON=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_ID" \
                --region "${AWS_REGION:-us-east-2}" \
                --query 'SecretString' \
                --output text 2>"$AWS_ERROR")
            AWS_EXIT_CODE=$?
            
            if [ $AWS_EXIT_CODE -ne 0 ]; then
                echo "  ERROR: AWS CLI failed for $ENV_VAR (exit code: $AWS_EXIT_CODE)"
                echo "  Secret ID: '$SECRET_ID'"
                echo "  Original reference: '$SECRET_REF'"
                echo "  AWS Error: $(cat "$AWS_ERROR")"
                rm -f "$AWS_ERROR"
                continue
            fi
            rm -f "$AWS_ERROR"
            
            SECRET_VALUE=$(echo "$SECRET_JSON" | jq -r ".$JSON_KEY // empty")
            
            if [ -z "$SECRET_VALUE" ]; then
                echo "  ERROR: Key '$JSON_KEY' not found or empty in secret '$SECRET_ID'"
                echo "  Available keys: $(echo "$SECRET_JSON" | jq -r 'keys | join(", ")')"
                continue
            fi
        else
            # No JSON key - treat as plain text secret
            SECRET_ID="$SECRET_REF_EXPANDED"
            
            echo "  Fetching $ENV_VAR from '$SECRET_ID' (plain text)"
            
            AWS_ERROR=$(mktemp)
            SECRET_VALUE=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_ID" \
                --region "${AWS_REGION:-us-east-2}" \
                --query 'SecretString' \
                --output text 2>"$AWS_ERROR")
            AWS_EXIT_CODE=$?
            
            if [ $AWS_EXIT_CODE -ne 0 ]; then
                echo "  ERROR: AWS CLI failed for $ENV_VAR (exit code: $AWS_EXIT_CODE)"
                echo "  Secret ID: '$SECRET_ID'"
                echo "  Original reference: '$SECRET_REF'"
                echo "  AWS Error: $(cat "$AWS_ERROR")"
                rm -f "$AWS_ERROR"
                continue
            fi
            rm -f "$AWS_ERROR"
        fi
        
        if [ -z "$SECRET_VALUE" ]; then
            echo "  Warning: Could not fetch secret for $ENV_VAR (empty value returned)"
            continue
        fi
        
        # Export the environment variable
        export "$ENV_VAR=$SECRET_VALUE"
        echo "  ✓ $ENV_VAR loaded"
        
    done < "$SECRETS_FILE"
    
done < "$EXTENSIONS_LIST_FILE"

echo "================================================"
echo "Extension secrets loaded"
echo "================================================"
