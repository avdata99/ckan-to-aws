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
