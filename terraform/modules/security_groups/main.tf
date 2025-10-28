resource "aws_security_group" "alb" {
  name        = "ckan-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ckan-${var.environment}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "ckan" {
  name        = "ckan-${var.environment}-app-sg"
  description = "Security group for CKAN ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ckan-${var.environment}-app-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "ckan-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ckan.id]
  }

  tags = {
    Name        = "ckan-${var.environment}-rds-sg"
    Environment = var.environment
  }
}
