#!/bin/bash
# This script sets up environment variables at container runtime
# Priority: AWS Secrets Manager > ECS Environment Variables > .env file

echo "================================================"
echo "Setting up runtime environment configuration..."
echo "================================================"

# Check if running in AWS (ECS sets this variable)
if [ -n "$AWS_EXECUTION_ENV" ] || [ -n "$ECS_CONTAINER_METADATA_URI" ]; then
    echo "Running in AWS ECS"
    echo "Using AWS Secrets Manager and ECS environment variables"
    
    # Secrets are automatically injected as environment variables by ECS
    # Validate required secrets exist
    REQUIRED_SECRETS="DB_USERNAME DB_PASSWORD DB_HOST SECRET_KEY DATASTORE_READ_USER DATASTORE_READ_PASSWORD DATASTORE_WRITE_USER DATASTORE_WRITE_PASSWORD"
    MISSING_SECRETS=""
    
    for SECRET in $REQUIRED_SECRETS; do
        if [ -z "${!SECRET}" ]; then
            MISSING_SECRETS="$MISSING_SECRETS $SECRET"
        fi
    done
    
    if [ -n "$MISSING_SECRETS" ]; then
        echo "ERROR: Missing required secrets:$MISSING_SECRETS"
        echo "   Check that ECS task definition is configured to read from Secrets Manager"
        exit 1
    fi
    
    echo "All required secrets loaded from AWS Secrets Manager"
    
    # Build connection URLs from individual components if not already set
    if [ -z "$SQLALCHEMY_URL" ]; then
        export SQLALCHEMY_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DB_NAME}"
    fi
    
    if [ -z "$DATASTORE_WRITE_URL" ]; then
        export DATASTORE_WRITE_URL="postgresql://${DATASTORE_WRITE_USER}:${DATASTORE_WRITE_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DATASTORE_DB:-datastore}"
    fi
    
    if [ -z "$DATASTORE_READ_URL" ]; then
        export DATASTORE_READ_URL="postgresql://${DATASTORE_READ_USER}:${DATASTORE_READ_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DATASTORE_DB:-datastore}"
    fi
    
    # Export variables needed by setup-datastore.sh script
    export DATASTORE_READ_USERNAME="${DATASTORE_READ_USER}"
    export DATASTORE_WRITE_USERNAME="${DATASTORE_WRITE_USER}"
    export DATASTORE_DB_NAME="${DATASTORE_DB:-datastore}"
    
    echo "Database connection URLs configured"
    echo "  Main DB: ${DB_USERNAME}@${DB_HOST}/${DB_NAME}"
    echo "  Datastore Write: ${DATASTORE_WRITE_USER}@${DB_HOST}/${DATASTORE_DB:-datastore}"
    echo "  Datastore Read: ${DATASTORE_READ_USER}@${DB_HOST}/${DATASTORE_DB:-datastore}"
    
else
    echo "⚠ Running locally (not in ECS)"
    echo "⚠ Loading environment from ${APP_DIR}/.env file"
    
    if [ ! -f "${APP_DIR}/.env" ]; then
        echo "ERROR: ${APP_DIR}/.env file not found"
        exit 1
    fi
    
    # Load .env file for local development
    set -o allexport
    source "${APP_DIR}/.env"
    set +o allexport
    
    echo "Environment loaded from .env file"
fi

echo "================================================"
echo "Runtime environment configured successfully"
echo "================================================"
