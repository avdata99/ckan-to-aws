#!/bin/bash
# Load secrets from AWS Secrets Manager for CKAN extensions
# Each extension can define required secrets in extension.secrets.txt

echo "================================================"
echo "Loading extension secrets..."
echo "================================================"

EXTENSIONS_LIST_FILE="${APP_DIR}/extensions/extensions.list.txt"

# Export common variables that extensions might reference in their secrets files
export SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"

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
        SECRET_REF=$(eval echo "$SECRET_REF")
        
        # Check if it contains a JSON key reference
        if [[ "$SECRET_REF" == *":"* ]]; then
            SECRET_ID=$(echo "$SECRET_REF" | cut -d':' -f1)
            JSON_KEY=$(echo "$SECRET_REF" | cut -d':' -f2-)
            
            echo "  Fetching $ENV_VAR from $SECRET_ID (key: $JSON_KEY)"
            
            # Fetch the secret and extract the JSON key
            SECRET_VALUE=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_ID" \
                --region "${AWS_REGION:-us-east-2}" \
                --query 'SecretString' \
                --output text 2>/dev/null | jq -r ".$JSON_KEY // empty")
        else
            # No JSON key - treat as plain text secret
            SECRET_ID="$SECRET_REF"
            
            echo "  Fetching $ENV_VAR from $SECRET_ID (plain text)"
            
            SECRET_VALUE=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_ID" \
                --region "${AWS_REGION:-us-east-2}" \
                --query 'SecretString' \
                --output text 2>/dev/null)
        fi
        
        if [ -z "$SECRET_VALUE" ]; then
            echo "  Warning: Could not fetch secret for $ENV_VAR"
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
