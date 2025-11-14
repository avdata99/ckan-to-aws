# ECS Service for All-in-One (CKAN + Solr + Redis)
resource "aws_ecs_service" "all_in_one" {
  name            = "${var.project_id}-${var.environment}-ckan"
  cluster         = var.cluster_id
  task_definition = var.task_definition_arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ckan_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "ckan"
    container_port   = 5000
  }

  # Circuit breaker configuration
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Deployment configuration
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 0
  }

  # Give CKAN plenty of time to start up before checking health
  health_check_grace_period_seconds = 300

  tags = {
    Name = "${var.project_id}-${var.environment}-ckan-service"
  }

  # Allow external changes to desired_count (for manual scaling/stopping)
  lifecycle {
    ignore_changes = [desired_count]
  }
}
