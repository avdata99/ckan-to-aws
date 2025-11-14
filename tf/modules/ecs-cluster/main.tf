# ECS Cluster - The platform for running containers
resource "aws_ecs_cluster" "main" {
  name = "${var.project_id}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-cluster"
  }
}

# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_id}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_id}-${var.environment}-ecs-logs"
  }
}
