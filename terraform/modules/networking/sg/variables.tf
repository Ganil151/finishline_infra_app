#========================================================================
#                  *** Finishline Project Variables ***
#========================================================================
variable "project_name" {
  description = "The name of the project"
  type        = string
}
variable "environment" {
  description = "The environment name"
  type        = string
}
variable "aws_region" {
  description = "The AWS region"
  type        = string
}
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
#========================================================================
#                  *** Security Group Variables ***
#========================================================================
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
#========================================================================
#                  *** Karpenter SG Variables ***
#========================================================================
variable "karpenter_cluster_name" {
  description = "The name of the Karpenter cluster"
  type        = string
  default     = ""
}

variable "enable_karpenter_discovery" {
  description = "Whether to enable Karpenter discovery"
  type        = bool
  default     = false
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.ingress_rules : r.description != ""])
    error_message = "Ingress rule description cannot be empty."
  }
}

variable "egress_rules" {
  description = "List of egress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.egress_rules : r.description != ""])
    error_message = "Egress rule description cannot be empty."
  }
}
