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

  health_check_grace_period_seconds = var.health_check_grace_period

  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = {
    Name = "${var.project_id}-${var.environment}-ckan-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
