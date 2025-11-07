variable "project_id" {
  description = "Unique identifier for the project, used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "create_vpc" {
  description = "Set to true to create a new VPC."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of an existing VPC to use if create_vpc is false."
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs to use if create_vpc is false."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs to use if create_vpc is false."
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC if create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}
