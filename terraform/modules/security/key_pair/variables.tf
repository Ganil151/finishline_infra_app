# ===========================================================
#               ***   Project Variables   ***
# ===========================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "managed_by" {
  description = "Team managing this resource"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Centralized common tags from root.hcl"
  type        = map(string)
}

variable "key_name" {
  description = "Name of the key pair"
  type        = string
}

variable "key_algorithm" {
  description = "Algorithm for the key pair"
  type        = string
}

variable "rsa_bits" {
  description = "Number of bits for the RSA key"
  type        = number
}
