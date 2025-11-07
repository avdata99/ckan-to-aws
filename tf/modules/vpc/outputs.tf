output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = var.create_vpc ? [for s in aws_subnet.public : s.id] : data.aws_subnets.public[0].ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = var.create_vpc ? [for s in aws_subnet.private : s.id] : data.aws_subnets.private[0].ids
}
