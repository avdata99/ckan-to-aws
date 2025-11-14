output "service_name" {
  description = "Name of the CKAN ECS service"
  value       = aws_ecs_service.all_in_one.name
}

output "service_arn" {
  description = "ARN of the CKAN ECS service"
  value       = aws_ecs_service.all_in_one.id
}
