variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group for CKAN"
  type        = string
}

variable "ckan_security_group_id" {
  description = "Security group ID for CKAN tasks"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "db_host" {
  description = "Database host endpoint"
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

variable "ckan_site_url" {
  description = "CKAN site URL"
  type        = string
}

variable "ckan_site_id" {
  description = "CKAN site ID"
  type        = string
  default     = "default"
}

variable "datastore_write_username" {
  description = "Datastore write user username"
  type        = string
}

variable "datastore_write_password" {
  description = "Datastore write user password"
  type        = string
  sensitive   = true
}

variable "datastore_read_username" {
  description = "Datastore read user username"
  type        = string
}

variable "datastore_read_password" {
  description = "Datastore read user password"
  type        = string
  sensitive   = true
}
