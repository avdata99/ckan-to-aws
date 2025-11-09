# This file is the main entry point for our Terraform infrastructure.
# We will add modules here as we build each component (VPC, RDS, ECS, etc.).

module "vpc" {
  source = "./modules/vpc"

  project_id         = var.project_id
  environment        = var.environment
  create_vpc         = var.create_vpc
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
}

module "security_groups" {
  source = "./modules/security-groups"

  project_id           = var.project_id
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  allowed_cidr_blocks  = var.allowed_cidr_blocks
}
