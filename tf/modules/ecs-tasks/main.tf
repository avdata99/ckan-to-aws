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
  db_host = split(":", var.db_endpoint)[0]
  db_port = "5432"
  
  # Build connection strings
  sqlalchemy_url = "postgresql://${var.db_username}:${var.db_password}@${local.db_host}:${local.db_port}/${var.db_name}"
  datastore_write_url = "postgresql://${var.db_username}:${var.db_password}@${local.db_host}:${local.db_port}/datastore"
  datastore_read_url = "postgresql://${var.db_username}:${var.db_password}@${local.db_host}:${local.db_port}/datastore"
  
  # Service discovery DNS names (we'll use these after services are created)
  solr_url = "http://solr.${var.project_id}-${var.environment}.local:8983/solr/ckan"
  redis_url = "redis://redis.${var.project_id}-${var.environment}.local:6379/0"
  
  ckan_site_url = var.alb_dns_name != "" ? "http://${var.alb_dns_name}" : "http://localhost:5000"
}

# ============================================================================
# CKAN Task Definition
# ============================================================================
resource "aws_ecs_task_definition" "ckan" {
  family                   = "${var.project_id}-${var.environment}-ckan"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ckan_task_cpu
  memory                   = var.ckan_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "ckan"
    image = "${var.ecr_ckan_repository_url}:${var.image_tag}"
    
    essential = true
    
    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]
    
    # CRITICAL: Runtime environment variables override the baked-in values
    environment = [
      {
        name  = "SQLALCHEMY_URL"
        value = local.sqlalchemy_url
      },
      {
        name  = "DATASTORE_WRITE_URL"
        value = local.datastore_write_url
      },
      {
        name  = "DATASTORE_READ_URL"
        value = local.datastore_read_url
      },
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
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
  }])

  tags = {
    Name = "${var.project_id}-${var.environment}-ckan-task"
  }
}

# ============================================================================
# Services Task Definition (Solr + Redis in one task)
# ============================================================================
resource "aws_ecs_task_definition" "services" {
  family                   = "${var.project_id}-${var.environment}-services"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.solr_task_cpu + var.redis_task_cpu
  memory                   = var.solr_task_memory + var.redis_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
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
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8983/solr/admin/ping || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name  = "redis"
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
    }
  ])

  tags = {
    Name = "${var.project_id}-${var.environment}-services-task"
  }
}
