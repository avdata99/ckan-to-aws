# CKAN automated deploys to AWS

> **ALPHA STAGE WARNING**
> This project is currently in **alpha stage** and under active development.  
> - Features may be incomplete or unstable
> - Breaking changes may occur without notice  
> - Not recommended for production use without thorough testing
> - Documentation may be incomplete or outdated
> 
> Use at your own risk and please report any issues you encounter.

This repository contains the necessary configuration and scripts to
automate the deployment of CKAN instances to AWS infrastructure.

## ECS

The deployment process utilizes AWS ECS (Elastic Container Service) to manage
containerized CKAN applications.

## ECR

Docker images for CKAN are stored in AWS ECR (Elastic Container Registry).

## Infrastructure as Code

This project uses **Terraform** to manage AWS infrastructure including:
- VPC with public and private subnets
- ECS Cluster and Services (CKAN, Solr, Redis)
- RDS PostgreSQL database
- Application Load Balancer
- Security Groups and IAM roles

## Prepare local environment

This document is for Ubuntu users but it can be adapted to other OS.

Install required tools:

```bash
# Install AWS CLI (required for ECR login and Terraform AWS provider)
sudo apt install awscli

# Verify installation
aws --version
# Ensure you have locally AWS credentials ready to use in a profile.

# Install Terraform (required for infrastructure deployment)
# See https://developer.hashicorp.com/terraform/install

# Verify installation
terraform --version
```

## Configuration

1. Copy the environment configuration file:
```bash
cp .env.sample .env
```

2. Edit `.env` to configure your settings (required: ENVIRONMENT, AWS_REGION, DB_PASSWORD)

## Deploy to AWS

Ensure your AWS credentials are configured locally, either via environment variables or the AWS CLI configuration.

Run the deployment script:

```bash
cd scripts
./deploy.sh
```

This script will:
1. Set up the environment and validate AWS credentials
2. Build and push Docker images to ECR
3. Deploy infrastructure using Terraform (VPC, RDS, ECS, ALB)
4. Output the ALB URL to access your CKAN instance

## Terraform Commands

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# View outputs
terraform output
```
