terraform {
  backend "s3" {
    # TODO: Replace with the bucket name from your .env file
    bucket = "your-unique-bucket-name-for-tfstate"

    # This is the path to the state file inside the bucket.
    # Using a path helps organize state files if you have multiple environments.
    key    = "ckan/dev/terraform.tfstate"

    # TODO: Replace with the region from your .env file
    region = "us-east-2"

    # TODO: Replace with the DynamoDB table name from your .env file
    dynamodb_table = "ckan-terraform-state-lock"

    # Encrypt the state file at rest for added security
    encrypt = true
  }
}
