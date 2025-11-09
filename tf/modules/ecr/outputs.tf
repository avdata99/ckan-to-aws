output "ckan_repository_url" {
  description = "ECR repository URL for CKAN"
  value       = aws_ecr_repository.ckan.repository_url
}

output "solr_repository_url" {
  description = "ECR repository URL for Solr"
  value       = aws_ecr_repository.solr.repository_url
}

output "redis_repository_url" {
  description = "ECR repository URL for Redis"
  value       = aws_ecr_repository.redis.repository_url
}

output "ckan_repository_arn" {
  description = "ECR repository ARN for CKAN"
  value       = aws_ecr_repository.ckan.arn
}

output "solr_repository_arn" {
  description = "ECR repository ARN for Solr"
  value       = aws_ecr_repository.solr.arn
}

output "redis_repository_arn" {
  description = "ECR repository ARN for Redis"
  value       = aws_ecr_repository.redis.arn
}
