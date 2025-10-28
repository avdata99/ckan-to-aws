output "ckan_service_name" {
  description = "Name of the CKAN ECS service"
  value       = aws_ecs_service.ckan.name
}

output "ckan_service_id" {
  description = "ID of the CKAN ECS service"
  value       = aws_ecs_service.ckan.id
}

output "support_services_service_name" {
  description = "Name of the support services ECS service"
  value       = aws_ecs_service.support_services.name
}

output "support_services_service_id" {
  description = "ID of the support services ECS service"
  value       = aws_ecs_service.support_services.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}
