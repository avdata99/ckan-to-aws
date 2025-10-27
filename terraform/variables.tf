variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use (optional)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC - determines IP address range for the network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ecr_registry" {
  description = "ECR registry URL for Docker images"
  type        = string
}

# Database variables
variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ckan"
}

variable "db_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "ckan"
}

variable "db_password" {
  description = "PostgreSQL password (required, stored securely)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class - determines database performance (e.g., db.t3.micro, db.t3.small)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB (minimum: 20)"
  type        = number
  default     = 20
}

# CKAN configuration
variable "ckan_site_url" {
  description = "CKAN site URL (typically the ALB DNS name)"
  type        = string
}

variable "ckan_site_id" {
  description = "CKAN site ID"
  type        = string
  default     = "default"
}
