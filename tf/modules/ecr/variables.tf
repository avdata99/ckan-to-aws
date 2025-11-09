variable "project_id" {
  description = "Unique project identifier"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "ckan_repo_name" {
  description = "ECR repository name for CKAN"
  type        = string
  default     = "ckan"
}

variable "solr_repo_name" {
  description = "ECR repository name for Solr"
  type        = string
  default     = "solr"
}

variable "redis_repo_name" {
  description = "ECR repository name for Redis"
  type        = string
  default     = "redis"
}

variable "image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "image_retention_count" {
  description = "Number of images to retain"
  type        = number
  default     = 10
}
