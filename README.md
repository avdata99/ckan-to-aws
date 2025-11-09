# CKAN to AWS Deployment

This guide provides step-by-step instructions to deploy the CKAN application on AWS using Terraform and Docker.

## Requirements

- **AWS Account**: Ensure you have an AWS account with the necessary permissions to create resources.
- **AWS CLI**: Install and configure the AWS CLI with your credentials.
- **Docker**: Install Docker to build and manage container images.
- **Terraform**: Install Terraform to manage infrastructure as code.

## Step 1: Prepare Your Workspace

## Getting Started: Setting Up the Terraform Backend

Before you can deploy any infrastructure, you must set up a "remote backend".
This is a one-time process that creates an S3 bucket to store your Terraform state file
(its memory of your infrastructure) and a DynamoDB table to prevent conflicts when working in a team.

### Instructions:

1.  **Configure Your Environment**:
    -   Copy the `/.env.sample` file to a new file named `/.env`.
    -   Open `/.env` and fill in the values, especially `TF_STATE_BUCKET`. **This bucket name must be globally unique.**

2.  **Run the Backend Setup Script**:
    -   This script reads your `.env` file and creates the required AWS resources.
    ```bash
    ./scripts/010-setup-backend.sh
    ```
    You'll see something like this upon successful completion:
    ```
    ========================================
    Terraform Backend Setup
    ========================================
    Setting up environment...
    Loading environment variables from /home/user/dev/ckan-to-aws/.env
    Checking requirements...
    Using AWS profile: your-custom-profile
    AWS Account ID: XXXXXXXXXXX
    ECR Registry: XXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
    Environment setup complete for your project your-unique-id
    Environment: dev
    Region: us-east-2
    Account: XXXXXXXXXXX
    ECR Registry: XXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
    Checking for S3 bucket: ckan-to-aws-tf-state-your-unique-id...
    S3 bucket not found. Creating it...
    {
        "Location": "http://ckan-to-aws-tf-state-your-unique-id.s3.amazonaws.com/"
    }
    S3 bucket created.
    Enabling versioning on S3 bucket...
    Versioning enabled.
    ```

3.  **Initialize Terraform**:
    -   Run the `030-terraform-init.sh` script. This script reads your `.env` file and correctly
    configures Terraform to use your S3 backend.
    ```bash
    ./scripts/030-terraform-init.sh
    ```

    You should see output similar to this:
    ```
    ========================================
    Terraform Initialization
    ========================================
    Setting up environment...
    Loading environment variables from /homeuser/dev/ckan-to-aws/.env
    Checking requirements...
    Using AWS profile: your-custom-profile
    AWS Account ID: XXXXXXXXXXx
    ECR Registry: XXXXXXXXXXx.dkr.ecr.us-east-2.amazonaws.com
    Environment setup complete for your project you-project-internal-id
    Environment: dev
    Region: us-east-2
    Account: XXXXXXXXXXx
    ECR Registry: XXXXXXXXXXx.dkr.ecr.us-east-2.amazonaws.com
    Initializing Terraform with S3 backend...
    Using AWS Profile: your-custom-profile
    WARNING: State locking with DynamoDB is disabled.
    Initializing the backend...
    Initializing provider plugins...
    - Finding hashicorp/aws versions matching "~> 5.0"...
    - Installing hashicorp/aws v5.100.0...
    - Installed hashicorp/aws v5.100.0 (signed by HashiCorp)
    Terraform has created a lock file .terraform.lock.hcl to record the provider
    selections it made above. Include this file in your version control repository
    so that Terraform can guarantee to make the same selections by default when
    you run "terraform init" in the future.

    Terraform has been successfully initialized!

    You may now begin working with Terraform. Try running "terraform plan" to see
    any changes that are required for your infrastructure. All Terraform commands
    should now work.

    If you ever set or change modules or backend configuration for Terraform,
    rerun this command to reinitialize your working directory. If you forget, other
    commands will detect it and remind you to do so if necessary.
    ========================================
    Terraform initialized successfully!
    ========================================

    ```

    Running `terraform init` **did not** create anything in AWS or push a state file to S3. It only did the following on your local machine:
    -   Verified it can connect to your S3 backend.
    -   Downloaded the necessary AWS provider plugin.
    -   Created a `.terraform.lock.hcl` file to lock the provider version.

    Your S3 bucket is still empty. The state file will only be created the first time you run `terraform apply`.


> **How does this work?** The `tf/backend.tf` file tells Terraform *that* we are using an S3 backend, but it's intentionally left without details. The `030-terraform-init.sh` script provides those missing details (bucket name, region, etc.) from your `.env` file when it runs `terraform init`. This is the standard, secure way to configure a backend without hardcoding values.

After these steps, your project is correctly configured to manage its state remotely. You are now ready to start defining and deploying your infrastructure.

### Step 1: Deploy the Network (VPC)

This step deploys the foundational network. It can either create a new VPC or use an existing one, based on the `CREATE_VPC` variable in your `.env` file.

```bash
./scripts/050-deploy-vpc.sh
```

Terraform will show you the execution plan and prompt you for confirmation. Review the changes and type `yes` to proceed.

> **How does this work?** The script uses `terraform plan -target=module.vpc`. The `-target` flag tells Terraform to *only* create/update the resources defined in the `vpc` module in `tf/main.tf`, ignoring everything else. This gives us precise control over the deployment process.

> **Note:** This script also generates the `terraform.tfvars` file with all your configuration. If you update your `.env` file later (e.g., change `ALLOWED_CIDR_BLOCKS`), simply re-run this script. Terraform will detect that the VPC hasn't changed and only update the tfvars file. It's safe to run multiple times.

### Step 2: Deploy Security Groups

This step creates all the security groups needed for your infrastructure. Security groups act as virtual firewalls that control traffic between your resources.

**Important:** Security Groups are **always created new**, even when reusing an existing VPC. This is standard practice because:
- Security Groups are application-specific (they define the exact ports your app needs)
- They reference each other (e.g., CKAN can talk to RDS, ALB can talk to CKAN)
- Each application should have isolated security rules for better security
- The client typically provides VPC/subnets but not Security Groups

```bash
./scripts/060-deploy-security-groups.sh
```

The script will create security groups for:
- **ALB**: Allows HTTP/HTTPS from the internet (or restricted IPs if configured)
- **CKAN ECS Tasks**: Allows traffic from ALB on port 5000
- **Solr ECS Tasks**: Allows traffic from CKAN on port 8983
- **RDS**: Allows PostgreSQL connections from CKAN on port 5432
- **Redis**: Allows Redis connections from CKAN on port 6379

> **Customizing access:** By default, the ALB accepts traffic from anywhere (`0.0.0.0/0`). To restrict access to specific IP ranges, edit the `ALLOWED_CIDR_BLOCKS` variable in your `.env` file, then **re-run `050-deploy-vpc.sh`** to update the configuration. For example: `ALLOWED_CIDR_BLOCKS='["203.0.113.0/24", "198.51.100.0/24"]'`

> **Why this order?** Security groups only depend on the VPC and have no other dependencies. By creating them now, we can reference them in subsequent steps (RDS, Redis, ECS, ALB) without circular dependencies.

---
*Next steps will include deploying the database (RDS) and cache (Redis), each with its own targeted script.*