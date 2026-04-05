#========================================================================
#                      *** KARPENTER Variables ***
#========================================================================

#________________________________________________________________________
#  Cluster
#________________________________________________________________________
variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "The base64-encoded certificate authority data for the EKS cluster."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster is located."
  type        = string
}

#________________________________________________________________________
#  IAM
#________________________________________________________________________
variable "karpenter_node_role_name" {
  description = "The name of the IAM node role assigned to EC2NodeClass (role name, not ARN)."
  type        = string
}

variable "karpenter_controller_role_arn" {
  description = "The ARN of the Karpenter controller IAM role used for IRSA annotation on the service account."
  type        = string
}

variable "karpenter_instance_profile_name" {
  description = "The name of the IAM instance profile for Karpenter nodes."
  type        = string
}

#________________________________________________________________________
#  NodePool
#________________________________________________________________________
variable "karpenter_capacity_types" {
  description = "The capacity types for Karpenter nodes (e.g. [\"spot\", \"on-demand\"])."
  type        = list(string)
}

variable "karpenter_instance_types" {
  description = "The instance types for Karpenter nodes (e.g. [\"m5.large\", \"c5.large\"])."
  type        = list(string)
}

variable "karpenter_max_cpu" {
  description = "The maximum total CPU limit for the NodePool (e.g. \"50\")."
  type        = string
}

#________________________________________________________________________
#  EC2NodeClass
#________________________________________________________________________
variable "karpenter_ami_family" {
  description = "The AMI family for Karpenter nodes (e.g. AL2, Bottlerocket)."
  type        = string
  default     = "AL2"
}

variable "karpenter_volume_size" {
  description = "The root EBS volume size for Karpenter nodes (e.g. \"50Gi\")."
  type        = string
  default     = "50Gi"
}

variable "karpenter_detailed_monitoring" {
  description = "Whether to enable detailed EC2 monitoring for Karpenter nodes."
  type        = bool
  default     = false
}

#________________________________________________________________________
#  Helm / Namespace
#________________________________________________________________________
variable "karpenter_namespace" {
  description = "The Kubernetes namespace to deploy Karpenter into."
  type        = string
  default     = "karpenter"
}

variable "karpenter_interruption_queue_name" {
  description = "The SQS queue name for Karpenter interruption handling. Leave empty to disable."
  type        = string
  default     = ""
}

#________________________________________________________________________
#  Common
#________________________________________________________________________
variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}