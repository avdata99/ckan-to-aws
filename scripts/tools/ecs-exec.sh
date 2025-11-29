#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env-setup.sh"

CLUSTER_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan"
CONTAINER_NAME="ckan"
REGION="${AWS_REGION}"
PROFILE_OPTION="${AWS_PROFILE:+--profile ${AWS_PROFILE}}"

# Get the running task ID for the CKAN service
TASK_ID=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --region "$REGION" \
  $PROFILE_OPTION \
  --query 'taskArns[0]' \
  --output text)

if [ "$TASK_ID" == "None" ] || [ -z "$TASK_ID" ]; then
  echo "No running CKAN task found in service $SERVICE_NAME."
  # exit 0
fi

# Default command is /bin/bash, but allow override
CMD="${1:-/bin/bash}"

echo "Running ECS Exec into container '$CONTAINER_NAME' in task '$TASK_ID'..."
aws ecs execute-command \
  --cluster "$CLUSTER_NAME" \
  --task "$TASK_ID" \
  --container "$CONTAINER_NAME" \
  --command "$CMD" \
  --interactive \
  --region "$REGION" \
  $PROFILE_OPTION
