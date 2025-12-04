variable "project_id" {
  description = "Unique project identifier"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_id" {
  description = "ECS Cluster ID"
  type        = string
}

variable "task_definition_arn" {
  description = "Task definition ARN for all-in-one (CKAN + Solr + Redis)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ckan_security_group_id" {
  description = "Security group ID for CKAN"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ALB target group ARN for CKAN"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks (set to 0 initially)"
  type        = number
  default     = 0
}

variable "health_check_grace_period" {
  description = "Seconds to wait before starting health checks on a new task"
  type        = number
  default     = 600
}
