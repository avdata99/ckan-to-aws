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

---
*Next steps will include deploying the database and supporting services, each with its own targeted script.*