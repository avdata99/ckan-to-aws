terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configured dynamically by deployment script
    # bucket = "ckan-terraform-state-{environment}-{account_id}"
    # key    = "terraform.tfstate"
    # region = set from .env
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "security_groups" {
  source = "./modules/security_groups"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

module "rds" {
  source = "./modules/rds"
  
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_id    = module.security_groups.rds_security_group_id
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"
  
  environment = var.environment
}

module "alb" {
  source = "./modules/alb"
  
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
}

module "ecs_services" {
  source = "./modules/ecs_services"
  
  environment            = var.environment
  ecs_cluster_id         = module.ecs_cluster.cluster_id
  ecs_cluster_name       = module.ecs_cluster.cluster_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_target_group_arn   = module.alb.target_group_arn
  ckan_security_group_id = module.security_groups.ckan_security_group_id
  
  ecr_registry      = var.ecr_registry
  aws_region        = var.aws_region
  
  # Database connection
  db_host     = module.rds.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  
  # CKAN configuration
  ckan_site_url = var.ckan_site_url
  ckan_site_id  = var.ckan_site_id
}
