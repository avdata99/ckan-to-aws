# Service Discovery Namespace (private DNS)
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.project_id}-${var.environment}.local"
  vpc  = var.vpc_id

  tags = {
    Name = "${var.project_id}-${var.environment}-service-discovery"
  }
}

# Service Discovery Service for Solr
resource "aws_service_discovery_service" "solr" {
  name = "solr"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-solr-discovery"
  }
}

# Service Discovery Service for Redis
resource "aws_service_discovery_service" "redis" {
  name = "redis"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-redis-discovery"
  }
}

# ECS Service for Backend (Solr + Redis)
resource "aws_ecs_service" "services" {
  name            = "${var.project_id}-${var.environment}-services"
  cluster         = var.cluster_id
  task_definition = var.services_task_definition_arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [
      var.solr_security_group_id,
      var.redis_security_group_id
    ]
    assign_public_ip = false
  }

  # Register with Solr service discovery
  service_registries {
    registry_arn = aws_service_discovery_service.solr.arn
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-services"
  }
}
