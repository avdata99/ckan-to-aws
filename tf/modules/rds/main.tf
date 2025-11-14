# DB Subnet Group - defines which subnets RDS can use
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_id}-${var.environment}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.project_id}-${var.environment}-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_id}-${var.environment}-db"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = var.storage_encrypted

  # Database configuration
  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = 5432

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  # High availability and backup
  multi_az               = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC

  # Protection and monitoring
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.environment != "prod"  # Allow skip for non-prod
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_id}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Performance and tuning
  auto_minor_version_upgrade = true
  apply_immediately         = var.environment != "prod"

  tags = {
    Name = "${var.project_id}-${var.environment}-db"
  }
}
