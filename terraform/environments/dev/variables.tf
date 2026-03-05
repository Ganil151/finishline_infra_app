#================================================================
# Variables for the Project
#================================================================
variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "aws_region" {
  description = "The AWS region for the VPC"
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

#================================================================
# Variables for the VPC
#================================================================

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames for the VPC"
  type        = bool
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support for the VPC"
  type        = bool
}

variable "map_public_ip_on_launch" {
  description = "Whether to map public IP on launch for the subnets"
  type        = bool
}

variable "public_subnets_cidrs" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_subnets_cidrs" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "The availability zones for the VPC"
  type        = list(string)
}

#================================================================
# Variables for the Security Group
#================================================================

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
}

variable "ingress_rules" {
  description = "The ingress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "egress_rules" {
  description = "The egress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

#================================================================
# Variables for the Key Pair
#================================================================

variable "key_name" {
  description = "The name of the key pair"
  type        = string
}
