# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ckan-ecs-task-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "ckan-ecs-task-execution-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role for ECS tasks (application level)
resource "aws_iam_role" "ecs_task_role" {
  name = "ckan-ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "ckan-ecs-task-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Task Definition for Supporting Services (Solr + Redis)
resource "aws_ecs_task_definition" "support_services" {
  family                   = "ckan-support-services-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = "${var.ecr_registry}/ckan-solr:${var.environment}"
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [{
        containerPort = 8983
        protocol      = "tcp"
      }]

      environment = [
        {
          name  = "SOLR_HEAP"
          value = "512m"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ckan-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "solr"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8983/solr/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "redis"
      image     = "${var.ecr_registry}/ckan-redis:${var.environment}"
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [{
        containerPort = 6379
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ckan-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = {
    Name        = "ckan-support-services-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS Service for Supporting Services
resource "aws_ecs_service" "support_services" {
  name            = "ckan-support-services-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.support_services.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ckan_security_group_id]
    assign_public_ip = false
  }

  enable_execute_command = true

  tags = {
    Name        = "ckan-support-services-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Task Definition for CKAN
resource "aws_ecs_task_definition" "ckan" {
  family                   = "ckan-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "ckan"
      image     = "${var.ecr_registry}/ckan-app:${var.environment}"
      cpu       = 1024
      memory    = 2048
      essential = true

      portMappings = [{
        containerPort = 5000
        protocol      = "tcp"
      }]

      environment = [
        {
          name  = "CKAN_SITE_URL"
          value = var.ckan_site_url
        },
        {
          name  = "CKAN_SITE_ID"
          value = var.ckan_site_id
        },
        {
          name  = "CKAN_SQLALCHEMY_URL"
          value = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}/${var.db_name}"
        },
        {
          name  = "CKAN_SOLR_URL"
          value = var.solr_url
        },
        {
          name  = "CKAN_REDIS_URL"
          value = var.redis_url
        },
        {
          name  = "CKAN_DATASTORE_WRITE_URL"
          value = "postgresql://${var.datastore_write_username}:${var.datastore_write_password}@${var.db_host}/datastore"
        },
        {
          name  = "CKAN_DATASTORE_READ_URL"
          value = "postgresql://${var.datastore_read_username}:${var.datastore_read_password}@${var.db_host}/datastore"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ckan-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ckan"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      # dependsOn = [
      #   {
      #     containerName = "solr"
      #     condition     = "HEALTHY"
      #   },
      #   {
      #     containerName = "redis"
      #     condition     = "HEALTHY"
      #   }
      # ]
    }
  ])

  tags = {
    Name        = "ckan-task-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS Service for CKAN
resource "aws_ecs_service" "ckan" {
  name            = "ckan-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.ckan.arn
  desired_count   = 0
  # Fix and then re-enable
  # desired_count   = 1
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

  enable_execute_command = true
  force_new_deployment   = true

  depends_on = [aws_ecs_service.support_services]

  tags = {
    Name        = "ckan-service-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
