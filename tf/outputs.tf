output "vpc_id" {
  description = "ID of the VPC used for the deployment"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
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

# ECS Task Definitions
output "ckan_task_definition_arn" {
  description = "ARN of CKAN task definition"
  value       = module.ecs_tasks.ckan_task_definition_arn
}

output "services_task_definition_arn" {
  description = "ARN of services task definition (Solr + Redis)"
  value       = module.ecs_tasks.services_task_definition_arn
}

# Backend Services
output "backend_service_name" {
  description = "Name of backend services (Solr + Redis)"
  value       = module.ecs_services_backend.service_name
}

output "solr_dns_name" {
  description = "Service discovery DNS name for Solr"
  value       = module.ecs_services_backend.solr_dns_name
}

output "redis_dns_name" {
  description = "Service discovery DNS name for Redis"
  value       = module.ecs_services_backend.redis_dns_name
}
