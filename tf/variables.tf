variable "project_id" {
  description = "Unique identifier for the project, from UNIQUE_PROJECT_ID in .env"
  type        = string
}

variable "environment" {
  description = "Deployment environment, from ENVIRONMENT in .env"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

# --- VPC Variables ---
variable "create_vpc" {
  description = "Flag to create a new VPC, from CREATE_VPC in .env"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of an existing VPC, from VPC_ID in .env"
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs, from PUBLIC_SUBNET_IDS in .env"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs, from PRIVATE_SUBNET_IDS in .env"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC. Used only if create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

// --- RDS Variables ---
variable "db_subnet_ids" {
  description = "Subnet IDs for RDS database"
  type        = list(string)
  default     = []
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

// --- ECS Variables ---
variable "ecs_launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
}

variable "ckan_task_cpu" {
  description = "CPU units for CKAN task"
  type        = number
  default     = 512
}

variable "ckan_task_memory" {
  description = "Memory (MB) for CKAN task"
  type        = number
  default     = 1024
}

variable "solr_task_cpu" {
  description = "CPU units for Solr task"
  type        = number
  default     = 256
}

variable "solr_task_memory" {
  description = "Memory (MB) for Solr task"
  type        = number
  default     = 512
}

variable "redis_task_cpu" {
  description = "CPU units for Redis task"
  type        = number
  default     = 256
}

variable "redis_task_memory" {
  description = "Memory (MB) for Redis task"
  type        = number
  default     = 512
}

variable "ecr_ckan_repo_name" {
  description = "ECR repository name for CKAN"
  type        = string
  default     = "ckan"
}

variable "ecr_solr_repo_name" {
  description = "ECR repository name for Solr"
  type        = string
  default     = "solr"
}

variable "ecr_redis_repo_name" {
  description = "ECR repository name for Redis"
  type        = string
  default     = "redis"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
