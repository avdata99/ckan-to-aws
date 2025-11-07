terraform {
  # This block declares that we are using an S3 backend.
  # It is intentionally left without configuration values inside.
  # This is called "Partial Configuration".
  backend "s3" {
    # The specific configuration (bucket, key, region, etc.) is not
    # hardcoded here. Instead, it is provided dynamically during
    # initialization via the `terraform init -backend-config="..."` command.
    #
    # This allows us to use variables from the .env file without checking
    # secrets or environment-specific names into version control.
    # The `scripts/030-terraform-init.sh` script handles this process.
  }
}
