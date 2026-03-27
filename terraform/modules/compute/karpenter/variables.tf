#============================================================
#                 ***  Karpenter Variables  ***
#============================================================
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Certificate authority data of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "karpenter_instance_profile_name" {
  description = "IAM instance profile name for Karpenter nodes"
  type        = string
}

variable "karpenter_node_role_name" {
  description = "IAM role name for Karpenter nodes"
  type        = string
}

variable "karpenter_subnet_tags" {
  description = "Tags to select subnets for Karpenter nodes"
  type        = map(string)
}

variable "karpenter_security_group_tags" {
  description = "Tags to select security groups for Karpenter nodes"
  type        = map(string)
}

variable "karpenter_instance_types" {
  description = "List of instance types for Karpenter to provision"
  type        = list(string)
}

variable "karpenter_max_cpu" {
  description = "Maximum CPU cores Karpenter can provision"
  type        = number
}

variable "karpenter_capacity_types" {
  description = "Capacity types (spot, on-demand)"
  type        = list(string)
}

variable "karpenter_ami_family" {
  description = "AMI family for Karpenter nodes (e.g., Bottlerocket, AL2)"
  type        = string
}

variable "karpenter_volume_size" {
  description = "Root volume size for Karpenter nodes"
  type        = string
}

variable "karpenter_detailed_monitoring" {
  description = "Enable detailed monitoring for Karpenter nodes"
  type        = bool
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "computed_tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller service account"
  type        = string
}

variable "karpenter_interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  type        = string
}
