# CKAN automated deploys to AWS

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
