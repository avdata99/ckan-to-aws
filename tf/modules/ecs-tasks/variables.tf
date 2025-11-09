variable "project_id" {
  description = "Unique project identifier"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_ckan_repository_url" {
  description = "ECR repository URL for CKAN"
  type        = string
}

variable "ecr_solr_repository_url" {
  description = "ECR repository URL for Solr"
  type        = string
}

variable "ecr_redis_repository_url" {
  description = "ECR repository URL for Redis"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

# Database connection info
variable "db_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Task resources
variable "ckan_task_cpu" {
  description = "CPU units for CKAN task"
  type        = number
}

variable "ckan_task_memory" {
  description = "Memory (MB) for CKAN task"
  type        = number
}

variable "solr_task_cpu" {
  description = "CPU units for Solr task"
  type        = number
}

variable "solr_task_memory" {
  description = "Memory (MB) for Solr task"
  type        = number
}

variable "redis_task_cpu" {
  description = "CPU units for Redis task"
  type        = number
}

variable "redis_task_memory" {
  description = "Memory (MB) for Redis task"
  type        = number
}

variable "alb_dns_name" {
  description = "ALB DNS name for CKAN_SITE_URL"
  type        = string
  default     = ""
}
