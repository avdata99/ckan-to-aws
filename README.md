# CKAN to AWS Deployment

This guide provides step-by-step instructions to deploy the CKAN application on AWS using Terraform and Docker.

## Requirements

- **AWS Account**: Ensure you have an AWS account with the necessary permissions to create resources.
- **AWS CLI**: Install and configure the AWS CLI with your credentials.
- **Docker**: Install Docker to build and manage container images.
- **Terraform**: Install Terraform to manage infrastructure as code.
- **jq**: Install jq for JSON processing (`apt install jq` or `brew install jq`).

## Quick Start

1. Copy `.env.sample` to `.env` and configure your values
2. Run the full deployment: `./scripts/deploy.sh`
3. Start the service when ready (command shown at end of deployment)

## Configuration

### Step 1: Prepare Your Environment

1. **Copy the sample configuration**:
   ```bash
   cp .env.sample .env
   ```

2. **Edit `.env`** and update the following required values:
   - `UNIQUE_PROJECT_ID`: A unique identifier for your project (no underscores, must be globally unique for S3)
   - `AWS_PROFILE`: Your AWS CLI profile name
   - `AWS_REGION`: Target AWS region
   - `DB_PASSWORD`: A secure password for the database

### Step 2: Deploy Everything

Run the full deployment script:

```bash
./scripts/deploy.sh
```

This single script performs all deployment steps in order:

1. **Backend Setup** - Creates S3 bucket and DynamoDB table for Terraform state
2. **Terraform Init** - Initializes Terraform with the S3 backend
3. **VPC Deployment** - Creates or configures the network
4. **Security Groups** - Creates firewall rules for all components
5. **RDS Deployment** - Creates the PostgreSQL database (~10-15 minutes)
6. **ECR Repositories** - Creates container registries
7. **Docker Build & Push** - Builds and pushes CKAN, Solr, and Redis images
8. **Secrets Manager** - Stores all application secrets securely
9. **ECS Cluster** - Creates the container orchestration cluster
10. **ECS Task Definitions** - Defines how containers should run
11. **ALB Deployment** - Creates the Application Load Balancer
12. **ECS Service** - Creates the service (starts with 0 tasks)

### Step 3: Start the Application

After deployment completes, start the ECS service:

```bash
aws ecs update-service \
  --cluster YOUR_PROJECT_ID-dev-cluster \
  --service YOUR_PROJECT_ID-dev-ckan \
  --desired-count 1 \
  --region us-east-2 \
  --profile your-aws-profile
```

### Step 4: Monitor and Access

**Watch the logs**:
```bash
aws logs tail /ecs/YOUR_PROJECT_ID-dev --follow --region us-east-2 --profile your-aws-profile
```

**Force a new deployment** (to pull latest images):
```bash
aws ecs update-service \
  --cluster YOUR_PROJECT_ID-dev-cluster \
  --service YOUR_PROJECT_ID-dev-ckan \
  --force-new-deployment \
  --region us-east-2 \
  --profile your-aws-profile
```

**Access your CKAN instance** at the ALB URL shown at the end of deployment.

## Architecture Overview

The deployment creates an "all-in-one" ECS task that runs:
- **CKAN** (port 5000) - The main application
- **Solr** (port 8983) - Search engine
- **Redis** (port 6379) - Caching layer

All three containers run in the same task and communicate via `localhost`.

**AWS Resources Created**:
- VPC with public/private subnets (or uses existing VPC)
- Security Groups for ALB, ECS, and RDS
- RDS PostgreSQL instance
- ECR repositories for container images
- ECS Cluster (Fargate)
- Application Load Balancer
- Secrets Manager secret for credentials
- CloudWatch Log Group

## Configuration Options

### Using an Existing VPC

Set in your `.env`:
```bash
CREATE_VPC=false
VPC_ID="vpc-xxxxxxxxxxxxxxxxx"
PUBLIC_SUBNET_IDS='["subnet-xxx", "subnet-yyy"]'
PRIVATE_SUBNET_IDS='["subnet-zzz", "subnet-aaa"]'
DB_SUBNET_IDS='["subnet-bbb", "subnet-ccc"]'
```

### Restricting Access

By default, the ALB is open to the internet. To restrict access:
```bash
ALLOWED_CIDR_BLOCKS='["203.0.113.0/24", "198.51.100.0/24"]'
```

### Resource Sizing

Adjust CPU/memory for your workload:
```bash
CKAN_TASK_CPU=2048      # 2 vCPU
CKAN_TASK_MEMORY=4096   # 4 GB
```

### Database Configuration

```bash
DB_INSTANCE_CLASS=db.t3.medium  # Larger instance for production
DB_MULTI_AZ=true                # High availability (doubles cost)
DB_DELETION_PROTECTION=true     # Prevent accidental deletion
```

### Health Check Configuration

CKAN takes time to initialize. If tasks are being killed before they're ready:
```bash
# Increase grace period (default: 300 seconds = 5 minutes)
ECS_HEALTH_CHECK_GRACE_PERIOD=600
```

## Troubleshooting

### Task fails to start
1. Check CloudWatch logs: `aws logs tail /ecs/YOUR_PROJECT_ID-dev --follow`
2. Verify the RDS security group allows connections from ECS
3. Ensure secrets are correctly stored in Secrets Manager

### ALB shows unhealthy targets
1. Wait 2-3 minutes for CKAN to fully initialize
2. Check if the task is running: `aws ecs describe-services --cluster YOUR_CLUSTER --services YOUR_SERVICE`
3. Verify the health check path (`/api/3/action/status_show`) is accessible

### Database connection errors
1. Verify RDS is running and accessible
2. Check the secrets in AWS Secrets Manager contain correct values
3. Ensure the RDS security group allows traffic from the CKAN security group

## Costs

Estimated monthly costs (us-east-2, minimal configuration):
- **RDS db.t3.micro**: ~$15/month
- **Fargate (2 vCPU, 4GB)**: ~$60/month
- **ALB**: ~$20/month
- **NAT Gateway**: ~$35/month (if creating new VPC)
- **ECR/S3/Secrets**: <$5/month

**Total**: ~$130-150/month for a minimal dev environment

## Cleanup

To destroy all resources:
```bash
./scripts/destroy.sh
```

**Options**:
```bash
./scripts/destroy.sh --dry-run      # Show what would be destroyed
./scripts/destroy.sh --force        # Skip confirmation prompts
./scripts/destroy.sh --keep-state   # Keep S3 state bucket
```

**Warning**: This will delete all data including the RDS database. Make sure to backup any important data first.

## Secrets Management

CKAN requires sensitive configuration values (database passwords, API keys, etc.) that should not be stored in plain text. This project uses **AWS Secrets Manager** to securely store and retrieve these values.

### Initial Setup (Before First Deployment)

Before running `./scripts/deploy.sh`, you must create the secrets in AWS Secrets Manager:

```bash
./scripts/tools/push-secrets.sh
```

This script reads values from your `.env` file and creates a secret in AWS Secrets Manager with the following structure:

| Key | Description |
|-----|-------------|
| `db_host` | RDS endpoint (updated automatically after RDS deployment) |
| `db_port` | Database port (default: 5432) |
| `db_name` | Database name |
| `db_username` | Database master username |
| `db_password` | Database master password |
| `secret_key` | CKAN secret key for session encryption |
| `datastore_read_user` | Read-only user for datastore |
| `datastore_read_password` | Password for datastore read user |
| `datastore_write_user` | Write user for datastore |
| `datastore_write_password` | Password for datastore write user |

### How Secrets Flow to Containers

1. **At Deployment**: Secrets are stored in AWS Secrets Manager
2. **ECS Task Definition**: References secrets using `secrets` configuration
3. **Container Runtime**: ECS injects secrets as environment variables
4. **CKAN Startup**: `setup-runtime-env.sh` validates and builds connection URLs

### Updating Secrets

To update secrets after initial deployment:

```bash
# Update all secrets from .env
./scripts/tools/push-secrets.sh --update

# Update only the RDS endpoint (after RDS is created)
./scripts/tools/push-secrets.sh --update-rds-endpoint
```

### Fetching Secrets Locally

For local development or debugging, you can fetch secrets to a local file:

```bash
./scripts/tools/fetch-secrets-to-env.sh

# Outputs to .env.generated by default
# Or specify a custom path:
./scripts/tools/fetch-secrets-to-env.sh /path/to/output.env
```

**Note**: Never commit `.env.generated` to version control.

## SSH into Containers (ECS Exec)

Since ECS Fargate doesn't support traditional SSH, we use **ECS Exec** to run commands inside containers. This is similar to `docker exec`.

### Prerequisites

1. Install the Session Manager plugin for AWS CLI:
   ```bash
   # Ubuntu/Debian
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```

2. Make sure your `.env` file is configured with the correct AWS profile and project settings.

### Using the Script

```bash
# Open an interactive shell in the CKAN container
./scripts/tools/ecs-exec.sh

# Run a specific command
./scripts/tools/ecs-exec.sh "ls -la /var/lib/ckan"

# Connect to a different container (solr or redis)
./scripts/tools/ecs-exec.sh "/usr/bin/bash" solr
./scripts/tools/ecs-exec.sh "/usr/bin/bash" redis
```

### Just update CKAN instance

If you apply changes in the CKAN container (like installing extensions), you can force a new deployment to apply those changes:

```bash
./scripts/redeploy.sh
```

or for other containers:

```bash
./scripts/redeploy.sh solr
./scripts/redeploy.sh redis
```

## Advanced Configuration

### CKAN Extensions

Extensions are managed via the `extensions.list.txt` file. Each extension can have its own entrypoint script (`extension.entrypoint.sh`) that runs during container startup.

To add a new extension:

1. Add the extension name to `docker/ckan/files/env/extensions.list.txt`
2. Create the extension directory under `docker/ckan/extensions/`
3. Optionally add `extension.entrypoint.sh` for custom initialization
4. Optionally add `extension.secrets.txt` for AWS Secrets Manager integration

### Extension Secrets

Extensions can define secrets they need in an `extension.secrets.txt` file. These secrets are fetched from AWS Secrets Manager at container startup, before the extension's entrypoint runs.

**File format** (`extension.secrets.txt`):
```text
# Format: ENV_VAR_NAME=secret-name:json-key

# You can use variable substitution:
S3_BUCKET_NAME=${SECRET_NAME}:s3_bucket_name
S3_AWS_ACCESS_KEY_ID=${SECRET_NAME}:s3_access_key_id

# Or hardcode the secret name:
API_KEY=myproject-dev-api-key
```

**Available variables for substitution**:
| Variable | Description | Example |
|----------|-------------|---------|
| `${SECRET_NAME}` | Main project secret | `myproject-dev-secrets` |
| `${UNIQUE_PROJECT_ID}` | Project identifier | `myproject` |
| `${ENVIRONMENT}` | Environment name | `dev` |
| `${AWS_REGION}` | AWS region | `us-east-2` |

**Example**: For the s3filestore extension, create:
```
docker/ckan/extensions/s3filestore/
├── extension.install.sh      # Runs at build time
├── extension.entrypoint.sh   # Runs at container startup
└── extension.secrets.txt     # Secrets to load from AWS
```

**Creating the secret in AWS**:
```bash
aws secretsmanager create-secret \
    --name "myproject-dev-s3-secrets" \
    --secret-string '{"access_key_id":"AKIA...","secret_access_key":"...","bucket_name":"my-bucket","region":"us-east-2"}' \
    --region us-east-2
```

**Note**: Extension secrets are only loaded when running in AWS ECS. For local development, set these values in your `.env` file.

### S3 Filestore

To use S3 for file storage instead of local filesystem, configure these in your `.env`:

```bash
S3_AWS_ACCESS_KEY_ID=AKIA...
S3_AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET_NAME=your-ckan-files-bucket
S3_REGION=us-east-2
S3_ACL=private
```

### Custom CKAN Configuration

The `ckan.ini` file is generated at container startup from environment variables. To customize:

1. Modify `docker/ckan/files/scripts/setup-ckan-ini-file.sh`
2. Rebuild and push the Docker image
3. Force a new deployment
