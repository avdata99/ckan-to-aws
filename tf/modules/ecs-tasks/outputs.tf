output "ckan_task_definition_arn" {
  description = "ARN of CKAN task definition"
  value       = aws_ecs_task_definition.ckan.arn
}

output "services_task_definition_arn" {
  description = "ARN of services task definition (Solr + Redis)"
  value       = aws_ecs_task_definition.services.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}
