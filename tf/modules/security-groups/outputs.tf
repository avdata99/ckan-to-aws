output "alb_sg_id" {
  description = "Security Group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ckan_ecs_sg_id" {
  description = "Security Group ID for CKAN ECS tasks"
  value       = aws_security_group.ckan_ecs.id
}

output "solr_ecs_sg_id" {
  description = "Security Group ID for Solr ECS tasks"
  value       = aws_security_group.solr_ecs.id
}

output "rds_sg_id" {
  description = "Security Group ID for RDS"
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Security Group ID for Redis"
  value       = aws_security_group.redis.id
}
