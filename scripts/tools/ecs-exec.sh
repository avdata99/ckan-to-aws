#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source env-setup but don't exit on error
source "$SCRIPT_DIR/env-setup.sh" || {
  echo "Failed to load environment. Make sure .env is configured."
  exit 1
}

CLUSTER_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan"
CONTAINER_NAME="${2:-ckan}"
REGION="${AWS_REGION}"

# Build profile option
PROFILE_OPT=""
if [ -n "$AWS_PROFILE" ]; then
  PROFILE_OPT="--profile $AWS_PROFILE"
fi

# Get the running task ID for the CKAN service
echo "Finding running task in cluster $CLUSTER_NAME..."
TASK_ARN=$(aws ecs list-tasks \
  $PROFILE_OPT \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text)

if [ "$TASK_ARN" == "None" ] || [ -z "$TASK_ARN" ]; then
  echo "No running task found in service $SERVICE_NAME."
  exit 1
fi

# Extract task ID from ARN
TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
echo "Found task: $TASK_ID"

# Default command is /bin/sh (more compatible than /bin/bash)
CMD="${1:-/bin/sh}"

echo "Connecting to container '$CONTAINER_NAME'..."
echo ""

# aws ecs execute-command --profile gob-cba-pre-1 --region us-east-2 
aws ecs execute-command \
  $PROFILE_OPT \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --task "$TASK_ID" \
  --container "$CONTAINER_NAME" \
  --interactive \
  --command "$CMD"
