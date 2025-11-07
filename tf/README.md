# CKAN on AWS - Terraform Infrastructure

This directory contains the Terraform code to deploy the CKAN application and its dependencies on AWS. The infrastructure is designed to be modular, reusable, and configurable.

## Using a Shared VPC (Read-Only Mode)

This project is designed to safely work with existing, shared infrastructure provided by a client.

When you set `CREATE_VPC=false` in the `.env` file and provide the required IDs (`VPC_ID`, `PUBLIC_SUBNET_IDS`, `PRIVATE_SUBNET_IDS`), the `vpc` module switches into a read-only mode.

-   It uses **Terraform Data Sources** (`data "aws_vpc"`, `data "aws_subnets"`) instead of `resource` blocks.
-   Data sources **only read** information about existing resources. They **cannot create, modify, or delete** them.
-   If the provided IDs are incorrect or the resources don't exist, Terraform will fail with an error, preventing any further action.
-   The information read from the shared VPC is then stored in the Terraform state file, making it available for other resources (like the database and ECS services) to use without ever directly interacting with the shared resources again.

This ensures that your deployment can be safely integrated into an existing enterprise environment without risk.
