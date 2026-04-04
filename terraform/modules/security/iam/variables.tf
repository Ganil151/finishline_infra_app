#========================================================================
#                        *** IAM Variables ***
#========================================================================

#-----------------------------------------
# General Configuration
#-----------------------------------------
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#-----------------------------------------
# EKS Cluster Configuration
#-----------------------------------------
variable "is_eks_cluster_enabled" {
  description = "Whether to enable EKS cluster IAM resources"
  type        = bool
  default     = true
}

variable "is_eks_node_group_role_enabled" {
  description = "Whether to enable EKS node group IAM role"
  type        = bool
  default     = true
}

variable "is_eks_oidc_provider_enabled" {
  description = "Whether to enable EKS OIDC provider"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "eks_oidc_url" {
  description = "URL of the EKS OIDC provider"
  type        = string
  default     = ""
}

variable "eks_oidc_thumbprint" {
  description = "Thumbprint for the EKS OIDC provider"
  type        = string
  default     = ""
}

variable "eks_oidc_subject" {
  description = "Subject for the EKS OIDC role trust policy"
  type        = string
  default     = ""
}

variable "eks_oidc_namespace" {
  description = "Kubernetes namespace for the OIDC service account"
  type        = string
  default     = "default"
}

variable "eks_oidc_service_account" {
  description = "Kubernetes service account name for OIDC"
  type        = string
  default     = ""
}

#-----------------------------------------
# S3 OIDC Configuration
#-----------------------------------------
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for OIDC access"
  type        = string
  default     = ""
}

variable "s3_prefix" {
  description = "Prefix for S3 bucket access (use '*' for full bucket access)"
  type        = string
  default     = ""
}

#-----------------------------------------
# Karpenter Configuration
#-----------------------------------------
variable "is_karpenter_enabled" {
  description = "Whether to enable Karpenter IAM resources"
  type        = bool
  default     = false
}

variable "karpenter_cluster_name" {
  description = "Name of the EKS cluster for Karpenter"
  type        = string
  default     = ""
}

variable "karpenter_service_account_namespace" {
  description = "Kubernetes namespace for Karpenter service account"
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account_name" {
  description = "Kubernetes service account name for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_node_instance_profile_name" {
  description = "Name of the instance profile for Karpenter nodes"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Suffix to append to resource names"
  type        = string
  default     = ""
}

#-----------------------------------------
# EBS CSI Driver Configuration
#-----------------------------------------
variable "is_ebs_csi_driver_enabled" {
  description = "Whether to enable EBS CSI driver IAM resources"
  type        = bool
  default     = false
}

variable "ebs_csi_driver_namespace" {
  description = "Kubernetes namespace for EBS CSI driver service account"
  type        = string
  default     = "kube-system"
}

variable "ebs_csi_driver_service_account" {
  description = "Kubernetes service account name for EBS CSI driver"
  type        = string
  default     = "ebs-csi-controller-sa"
}
