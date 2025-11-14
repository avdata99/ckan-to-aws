#!/bin/bash
set -e

echo "========================================"
echo "Update and Deploy Workflow"
echo "========================================"
echo ""
echo "This script will:"
echo "1. Push secrets to AWS Secrets Manager"
echo "2. Build and push Docker images to ECR"
echo "3. Create new task definitions with latest images"
echo "4. Update ECS service with force-new-deployment"
echo ""

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/env-setup.sh"

# Step 0: Push secrets to AWS Secrets Manager
echo "========================================"
echo "Step 0: Ensuring secrets are in AWS Secrets Manager"
echo "========================================"
"$SCRIPT_DIR/077-push-secrets.sh"

# Get current task definition revision BEFORE any changes
echo "========================================"
echo "Checking current deployment status..."
echo "========================================"

CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster \
  --services ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null || echo "")

if [ -n "$CURRENT_TASK_DEF" ]; then
  PREVIOUS_REVISION=$(echo "$CURRENT_TASK_DEF" | rev | cut -d':' -f1 | rev)
  echo "Current revision found: $PREVIOUS_REVISION"
  echo "  Full ARN: $CURRENT_TASK_DEF"
else
  PREVIOUS_REVISION="none"
  echo "⚠ No current deployment found (first deployment)"
fi

echo ""

# Step 1: Build and push images
echo "========================================"
echo "Step 1: Building and pushing Docker images"
echo "========================================"
# "$SCRIPT_DIR/076-build-and-push-images.sh"

# Step 2: Create new task definitions
echo ""
echo "========================================"
echo "Step 2: Creating new task definitions with latest images"
echo "========================================"
"$SCRIPT_DIR/081-deploy-task-definitions.sh"

# Get the NEW task definition revision after creation
NEW_REVISION=$(aws ecs describe-task-definition \
  --task-definition ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-all-in-one \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'taskDefinition.revision' \
  --output text)

echo ""
echo "========================================"
echo "Task Definition Comparison"
echo "========================================"
if [ "$PREVIOUS_REVISION" = "none" ]; then
  echo "📦 First deployment - New task definition created: revision $NEW_REVISION"
elif [ "$PREVIOUS_REVISION" = "$NEW_REVISION" ]; then
  echo "⚠️  WARNING: Task definition did not change!"
  echo "   Previous revision: $PREVIOUS_REVISION"
  echo "   Current revision:  $NEW_REVISION"
  echo ""
  echo "   This usually means:"
  echo "   - Docker images have the same digest (no code changes)"
  echo "   - Environment variables haven't changed"
  echo "   - Task configuration is identical"
  echo ""
  echo "   Continuing anyway to force new deployment..."
else
  echo "Task definition updated successfully!"
  echo "  Previous revision: $PREVIOUS_REVISION"
  echo "  New revision:      $NEW_REVISION"
  echo "  Change detected:   Yes (revision incremented)"
fi

# Step 3: Update service to use latest task definition
echo ""
echo "========================================"
echo "Step 3: Updating ECS service"
echo "========================================"

echo "Forcing new deployment with latest task definition..."
echo "ECS will:"
echo "  - Use the latest task definition revision: $NEW_REVISION"
echo "  - Pull latest images from ECR"
echo "  - Gracefully replace old tasks with new ones"
echo "  - Rollback automatically if circuit breaker detects failures"
echo ""

aws ecs update-service \
  --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster \
  --service ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan \
  --task-definition ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-all-in-one \
  --force-new-deployment \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'service.[serviceName,taskDefinition,desiredCount,runningCount]' \
  --output table

# Verify the deployed revision
DEPLOYED_REVISION=$(aws ecs describe-services \
  --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster \
  --services ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan \
  --region $AWS_REGION \
  $AWS_PROFILE_OPTION \
  --query 'services[0].taskDefinition' \
  --output text | rev | cut -d':' -f1 | rev)

echo ""
echo "========================================"
echo "Deployment Summary"
echo "========================================"
echo ""
echo "Deployment Changes:"
echo "   Previous task definition: revision $PREVIOUS_REVISION"
echo "   New task definition:      revision $NEW_REVISION"
if [ "$PREVIOUS_REVISION" != "$NEW_REVISION" ]; then
  echo "Task definition changed - new code/config deployed"
else
  echo "Task definition unchanged - forcing container restart"
fi
echo ""
echo "Service Update:"
echo "   Deployed revision: $DEPLOYED_REVISION"
echo "   Status: Deployment in progress"
echo ""
echo "Useful Commands:"
echo ""
echo "Monitor deployment progress:"
echo "  aws ecs describe-services --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --services ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan --region $AWS_REGION $AWS_PROFILE_OPTION --query 'services[0].events[0:5]'"
echo ""
echo "Watch logs:"
echo "  aws logs tail /ecs/${UNIQUE_PROJECT_ID}-${ENVIRONMENT} --follow --region $AWS_REGION $AWS_PROFILE_OPTION"
echo ""
echo "Check task health:"
echo "  aws ecs describe-tasks --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --tasks \$(aws ecs list-tasks --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --service-name ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan --region $AWS_REGION $AWS_PROFILE_OPTION --query 'taskArns[0]' --output text) --region $AWS_REGION $AWS_PROFILE_OPTION --query 'tasks[0].containers[*].[name,lastStatus,healthStatus]' --output table"
echo ""
echo "Access your application:"
TF_DIR="$(cd "$SCRIPT_DIR/../tf" && pwd)"
cd "$TF_DIR"
terraform output -raw alb_url 2>/dev/null || echo "http://${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-alb-*.elb.amazonaws.com"
echo ""
echo ""
echo "🔄 Rollback Options:"
if [ "$PREVIOUS_REVISION" != "none" ] && [ "$PREVIOUS_REVISION" != "$NEW_REVISION" ]; then
  echo "  Manual rollback to previous version:"
  echo "  aws ecs update-service --cluster ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-cluster --service ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-ckan --task-definition ${UNIQUE_PROJECT_ID}-${ENVIRONMENT}-all-in-one:$PREVIOUS_REVISION --region $AWS_REGION $AWS_PROFILE_OPTION"
else
  echo "  Circuit breaker will auto-rollback if deployment fails"
fi
echo ""
echo "========================================"
echo "✨ Deployment initiated successfully!"
echo "========================================"
