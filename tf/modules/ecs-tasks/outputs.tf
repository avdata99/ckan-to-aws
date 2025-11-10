output "all_in_one_task_definition_arn" {
  description = "ARN of all-in-one task definition (CKAN + Solr + Redis)"
  value       = aws_ecs_task_definition.all_in_one.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}
