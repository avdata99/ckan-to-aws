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

module "rds" {
  source = "./modules/rds"

  project_id              = var.project_id
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  db_subnet_ids           = var.db_subnet_ids
  security_group_id       = module.security_groups.rds_sg_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  engine_version          = var.db_engine_version
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = var.db_deletion_protection
  storage_encrypted       = var.db_encryption_enabled
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_id  = var.project_id
  environment = var.environment
}

module "ecr" {
  source = "./modules/ecr"

  project_id         = var.project_id
  environment        = var.environment
  ckan_repo_name     = var.ecr_ckan_repo_name
  solr_repo_name     = var.ecr_solr_repo_name
  redis_repo_name    = var.ecr_redis_repo_name
}
