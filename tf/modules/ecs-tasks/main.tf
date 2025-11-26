# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_id}-${var.environment}-ecs-task-execution"

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
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy to allow reading secrets
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_id}-${var.environment}-*"
        ]
      }
    ]
  })
}

# IAM Role for ECS Tasks (runtime permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_id}-${var.environment}-ecs-task"

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
}

# Extract hostname from RDS endpoint (remove port)
locals {
  # Use localhost for Solr and Redis since they're in the same task
  solr_url = "http://localhost:8983/solr/ckan"
  redis_url = "redis://localhost:6379/0"
  
  ckan_site_url = var.alb_dns_name != "" ? "http://${var.alb_dns_name}" : "http://localhost:5000"
}

# ============================================================================
# All-in-One Task Definition (CKAN + Solr + Redis)
# ============================================================================
resource "aws_ecs_task_definition" "all_in_one" {
  family                   = "${var.project_id}-${var.environment}-all-in-one"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ckan_task_cpu + var.solr_task_cpu + var.redis_task_cpu
  memory                   = var.ckan_task_memory + var.solr_task_memory + var.redis_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    # Container 1: Redis (start first, it's the fastest)
    {
      name  = "redis"
      # Force pull latest image by not caching the digest
      image = "${var.ecr_redis_repository_url}:${var.image_tag}"
      
      essential = true
      
      portMappings = [{
        containerPort = 6379
        protocol      = "tcp"
      }]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "redis-cli ping || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    },
    # Container 2: Solr (start second)
    {
      name  = "solr"
      image = "${var.ecr_solr_repository_url}:${var.image_tag}"
      
      essential = true
      
      portMappings = [{
        containerPort = 8983
        protocol      = "tcp"
      }]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "solr"
        }
      }
      
      # More lenient health check - Solr takes time to fully start
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8983/solr/ || exit 1"
        ]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 120
      }
    },
    # Container 3: CKAN (start last, depends on Solr and Redis)
    {
      name  = "ckan"
      image = "${var.ecr_ckan_repository_url}:${var.image_tag}"
      
      essential = true
      
      portMappings = [{
        containerPort = 5000
        protocol      = "tcp"
      }]
      
      # NON-SENSITIVE environment variables (safe to be in plain text)
      environment = [
        # Services (localhost since they're in same task)
        {
          name  = "SOLR_URL"
          value = local.solr_url
        },
        {
          name  = "CKAN_REDIS_URL"
          value = local.redis_url
        },
        {
          name  = "CKAN_SITE_URL"
          value = local.ckan_site_url
        },
        {
          name  = "CKAN_STORAGE_PATH"
          value = "/var/lib/ckan/storage"
        },
        {
          name  = "CKAN_STORAGE_FOLDER"
          value = "storage"
        },
        {
          name  = "ENV_NAME"
          value = "AWS"
        },
        {
          name  = "CKAN_DEBUG"
          value = "false"
        },
        # To force new ECS update
        {
          name  = "ECS_VERSION"
          value = "9"
        },
        # Sysadmin TODO
        {
          name  = "CKAN_SYSADMIN_USER"
          value = "ckan_admin"
        },
        {
          name  = "CKAN_SYSADMIN_PASS"
          value = "testpass"
        },
        {
          name  = "CKAN_SYSADMIN_MAIL"
          value = "ckan_admin@localhost"
        },
        # Non-sensitive database info
        {
          name  = "DB_PORT"
          value = "5432"
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DATASTORE_DB"
          value = "datastore"
        }
      ]
      
      # ALL SENSITIVE values from Secrets Manager
      secrets = [
        # Main database credentials
        {
          name      = "DB_HOST"
          valueFrom = "${var.app_secret_arn}:db_host::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${var.app_secret_arn}:db_username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.app_secret_arn}:db_password::"
        },
        # Datastore write user
        {
          name      = "DATASTORE_WRITE_USER"
          valueFrom = "${var.app_secret_arn}:datastore_write_user::"
        },
        {
          name      = "DATASTORE_WRITE_PASSWORD"
          valueFrom = "${var.app_secret_arn}:datastore_write_password::"
        },
        # Datastore read user
        {
          name      = "DATASTORE_READ_USER"
          valueFrom = "${var.app_secret_arn}:datastore_read_user::"
        },
        {
          name      = "DATASTORE_READ_PASSWORD"
          valueFrom = "${var.app_secret_arn}:datastore_read_password::"
        },
        # CKAN application secrets
        {
          name      = "SECRET_KEY"
          valueFrom = "${var.app_secret_arn}:secret_key::"
        },
        {
          name      = "BEAKER_SESSION_SECRET"
          valueFrom = "${var.app_secret_arn}:beaker_session_secret::"
        },
        {
          name      = "BEAKER_SESSION_VALIDATE_KEY"
          valueFrom = "${var.app_secret_arn}:beaker_session_validate_key::"
        }
      ]
      
      # Depend on Redis and Solr being healthy first
      dependsOn = [
        {
          containerName = "redis"
          condition     = "HEALTHY"
        },
        {
          containerName = "solr"
          condition     = "HEALTHY"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ckan"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:5000/api/3/action/status_show || exit 1"
        ]
        interval    = 60
        timeout     = 10
        retries     = 5
        startPeriod = 180
      }
    }
  ])

  tags = {
    Name = "${var.project_id}-${var.environment}-all-in-one-task"
  }
}
