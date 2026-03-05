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

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
}

variable "ingress_rules" {
  description = "The ingress rules for the security group"
  type        = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
variable "egress_rules" {
  description = "The egress rules for the security group"
  type        = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}