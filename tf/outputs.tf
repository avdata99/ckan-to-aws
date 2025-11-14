# VPC Information
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# Database Information
output "database" {
  description = "Database connection information"
  value = {
    endpoint = module.rds.db_endpoint
    address  = module.rds.db_address
    port     = module.rds.db_port
    name     = module.rds.db_name
  }
  sensitive = false
}

output "database_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.db_username}:PASSWORD@${module.rds.db_address}:${module.rds.db_port}/${module.rds.db_name}"
  sensitive   = false
}

# ALB Information
output "alb_dns_name" {
  description = "ALB DNS name - use this to access your CKAN application"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Full URL to access CKAN"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ckan_target_group_arn" {
  description = "Target group ARN for CKAN service"
  value       = module.alb.ckan_target_group_arn
}

# ECR Repository URLs
output "ecr_ckan_repository_url" {
  description = "ECR repository URL for CKAN"
  value       = module.ecr.ckan_repository_url
}

output "ecr_solr_repository_url" {
  description = "ECR repository URL for Solr"
  value       = module.ecr.solr_repository_url
}

output "ecr_redis_repository_url" {
  description = "ECR repository URL for Redis"
  value       = module.ecr.redis_repository_url
}

# ECS Task Definition
output "all_in_one_task_definition_arn" {
  description = "ARN of all-in-one task definition (CKAN + Solr + Redis)"
  value       = module.ecs_tasks.all_in_one_task_definition_arn
}

# ECS Service
output "ckan_service_name" {
  description = "Name of CKAN ECS service"
  value       = module.ecs_service_all_in_one.service_name
}
