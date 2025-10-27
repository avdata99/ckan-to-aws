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

## Prepare local environment

This document is for Ubuntu users but it can be adapted to other OS.  

Install awscli.  

```bash
sudo apt install awscli
```

Create a Python 3.12 environment and install dependencies:

```bash
pip install -r cdk/requirements.txt
```

## Deploy to AWS

Fill the `scripts/.env` file with the corresponding data.  
Ensure your AWS credentials are configured locally, either via environment variables or the AWS CLI configuration.  
Then, you can run the deployment script:

```bash
cd scripts
./deploy.sh
```
