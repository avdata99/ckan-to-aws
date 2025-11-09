# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_id}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-alb-sg"
  }
}

# Security Group for CKAN ECS Tasks
resource "aws_security_group" "ckan_ecs" {
  name        = "${var.project_id}-${var.environment}-ckan-ecs-sg"
  description = "Security group for CKAN ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-ckan-ecs-sg"
  }
}

# Security Group for Solr ECS Tasks
resource "aws_security_group" "solr_ecs" {
  name        = "${var.project_id}-${var.environment}-solr-ecs-sg"
  description = "Security group for Solr ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Solr from CKAN"
    from_port       = 8983
    to_port         = 8983
    protocol        = "tcp"
    security_groups = [aws_security_group.ckan_ecs.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-solr-ecs-sg"
  }
}

# Security Group for RDS (PostgreSQL)
resource "aws_security_group" "rds" {
  name        = "${var.project_id}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from CKAN"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ckan_ecs.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-rds-sg"
  }
}

# Security Group for ElastiCache (Redis)
resource "aws_security_group" "redis" {
  name        = "${var.project_id}-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from CKAN"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ckan_ecs.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-redis-sg"
  }
}
