terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # The region is configured via the AWS_REGION environment variable,
  # which is set by the env-setup.sh script.
}
