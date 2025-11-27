#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment variables from .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "No .env file found at $PROJECT_ROOT/.env"
    exit 1
fi

# Set AWS profile option if specified
AWS_PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_OPTION="--profile $AWS_PROFILE"
fi

SECRET_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-secrets"
OUTPUT_ENV_FILE="${1:-$PROJECT_ROOT/.env.generated}"

echo "Fetching secret: $SECRET_NAME from AWS Secrets Manager..."

SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    $AWS_PROFILE_OPTION \
    --query 'SecretString' \
    --output text 2>/dev/null)

if [ -z "$SECRET_JSON" ]; then
    echo "Error: Could not fetch secret $SECRET_NAME"
    exit 1
fi

echo "Writing secrets to $OUTPUT_ENV_FILE"

# Convert JSON to key=value pairs
echo "# Generated from AWS Secrets Manager ($SECRET_NAME)" > "$OUTPUT_ENV_FILE"
echo "$SECRET_JSON" | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' >> "$OUTPUT_ENV_FILE"

echo "Done. Secrets written to $OUTPUT_ENV_FILE"
