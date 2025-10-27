resource "aws_ecs_cluster" "main" {
  name = "ckan-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "ckan-ecs-cluster-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/ckan-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "ckan-ecs-logs-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
