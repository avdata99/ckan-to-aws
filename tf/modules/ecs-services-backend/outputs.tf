output "service_name" {
  description = "Name of the backend services ECS service"
  value       = aws_ecs_service.services.name
}

output "service_arn" {
  description = "ARN of the backend services ECS service"
  value       = aws_ecs_service.services.id
}

output "solr_dns_name" {
  description = "Service discovery DNS name for Solr"
  value       = "solr.${aws_service_discovery_private_dns_namespace.main.name}"
}

output "redis_dns_name" {
  description = "Service discovery DNS name for Redis"
  value       = "redis.${aws_service_discovery_private_dns_namespace.main.name}"
}

output "namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}
