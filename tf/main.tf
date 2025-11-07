# This file is the main entry point for our Terraform infrastructure.
# We will add modules here as we build each component (VPC, RDS, ECS, etc.).

module "vpc" {
  source = "./modules/vpc"

  project_id  = var.project_id
  environment = var.environment
  create_vpc  = var.create_vpc
  vpc_id      = var.vpc_id
  public_subnet_ids = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
}
