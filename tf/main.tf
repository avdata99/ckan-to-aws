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

  project_id          = var.project_id
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
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

  project_id      = var.project_id
  environment     = var.environment
  ckan_repo_name  = var.ecr_ckan_repo_name
  solr_repo_name  = var.ecr_solr_repo_name
  redis_repo_name = var.ecr_redis_repo_name
}

module "alb" {
  source = "./modules/alb"

  project_id            = var.project_id
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_sg_id
}

module "ecs_tasks" {
  source = "./modules/ecs-tasks"

  project_id               = var.project_id
  environment              = var.environment
  aws_region               = var.aws_region
  ecr_ckan_repository_url  = module.ecr.ckan_repository_url
  ecr_solr_repository_url  = module.ecr.solr_repository_url
  ecr_redis_repository_url = module.ecr.redis_repository_url
  image_tag                = var.image_tag
  log_group_name           = module.ecs_cluster.log_group_name

  # Secret ARN for all application secrets
  app_secret_arn = data.aws_secretsmanager_secret.app_secrets.arn

  # Non-sensitive configuration
  db_name = var.db_name

  # Task resources
  ckan_task_cpu     = var.ckan_task_cpu
  ckan_task_memory  = var.ckan_task_memory
  solr_task_cpu     = var.solr_task_cpu
  solr_task_memory  = var.solr_task_memory
  redis_task_cpu    = var.redis_task_cpu
  redis_task_memory = var.redis_task_memory

  # ALB DNS for CKAN_SITE_URL
  alb_dns_name = module.alb.alb_dns_name
}

module "ecs_service_all_in_one" {
  source = "./modules/ecs-service-all-in-one"

  project_id             = var.project_id
  environment            = var.environment
  cluster_id             = module.ecs_cluster.cluster_id
  task_definition_arn    = module.ecs_tasks.all_in_one_task_definition_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  ckan_security_group_id = module.security_groups.ckan_ecs_sg_id
  alb_target_group_arn   = module.alb.ckan_target_group_arn
  desired_count          = 1 # Start with 0 tasks
}

# Data source to get the secret ARN
data "aws_secretsmanager_secret" "app_secrets" {
  name = "${var.project_id}-${var.environment}-secrets"
}
