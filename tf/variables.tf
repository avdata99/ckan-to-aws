variable "project_id" {
  description = "Unique identifier for the project, from UNIQUE_PROJECT_ID in .env"
  type        = string
}

variable "environment" {
  description = "Deployment environment, from ENVIRONMENT in .env"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

# --- VPC Variables ---
variable "create_vpc" {
  description = "Flag to create a new VPC, from CREATE_VPC in .env"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of an existing VPC, from VPC_ID in .env"
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs, from PUBLIC_SUBNET_IDS in .env"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs, from PRIVATE_SUBNET_IDS in .env"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC. Used only if create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
