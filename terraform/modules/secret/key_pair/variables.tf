variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment for the VPC"
  type        = string
}

variable "manage_by" {
  description = "The entity responsible for managing the VPC"
  type        = string
}

variable "key_name" {
  description = "The name of the key pair"
  type        = string
}

