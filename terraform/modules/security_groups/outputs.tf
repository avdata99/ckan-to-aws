output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ckan_security_group_id" {
  value = aws_security_group.ckan.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
