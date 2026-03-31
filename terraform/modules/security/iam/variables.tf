#============================================================
#  Project Variables
#============================================================
variable "project_name" {
  description = "Name of the project (e.g., finishline-infra-app)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "managed_by" {
  description = "Team managing this resource (e.g., finishline-infra-team)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment (e.g., us-east-1)"
  type        = string
}

variable "common_tags" {
  description = "Centralized common tags from root.hcl"
  type        = map(string)
}

#============================================================
#  IAM Variables
#============================================================
variable "cluster_name" {
  description = "Name of the EKS cluster (e.g., finishline-infra-app-dev-eks)"
  type        = string
}

variable "name_suffix" {
  description = "Suffix for IAM resource names (use empty string for deterministic naming)"
  type        = string
}

variable "is_eks_cluster_enabled" {
  description = "Whether to enable EKS cluster IAM resources (cluster role, nodegroup role, OIDC)"
  type        = bool
}

variable "is_eks_role_enabled" {
  description = "Whether to enable EKS cluster IAM role"
  type        = bool
}

variable "is_eks_nodegroup_role_enabled" {
  description = "Whether to enable EKS nodegroup IAM role with managed policies"
  type        = bool
}

variable "eks_oidc_subject" {
  description = "Kubernetes service account subject for OIDC trust policy (e.g., system:serviceaccount:namespace:serviceaccount)"
  type        = string
}

variable "eks_oidc_url" {
  description = "EKS OIDC provider URL (e.g., https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXX)"
  type        = string
}

variable "eks_oidc_namespace" {
  description = "Kubernetes namespace for the OIDC service account"
  type        = string
}

variable "eks_oidc_service_account" {
  description = "Kubernetes service account name for OIDC identity"
  type        = string
}

variable "oidc_thumbprint" {
  description = "Thumbprint of the OIDC provider certificate (required for OIDC provider creation)"
  type        = string
}

#============================================================
#  S3 Access Variables
#============================================================
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to grant OIDC access to"
  type        = string
}

variable "s3_prefix" {
  description = "S3 bucket prefix/path to grant access to (e.g., bucket-name/prefix)"
  type        = string
}

variable "s3_access_type" {
  description = "Type of S3 access: read, write, or readwrite"
  type        = string

  validation {
    condition     = contains(["read", "write", "readwrite"], var.s3_access_type)
    error_message = "s3_access_type must be one of: read, write, or readwrite."
  }
}

#============================================================
#  Karpenter Variables
#============================================================
variable "is_karpenter_enabled" {
  description = "Whether to enable Karpenter IAM resources (controller role, node role, instance profile)"
  type        = bool
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter controller service account"
  type        = string
}

variable "karpenter_service_account" {
  description = "Kubernetes service account name for Karpenter controller IRSA"
  type        = string
}

variable "karpenter_cluster_name" {
  description = "EKS cluster name for Karpenter provisioning"
  type        = string
}

variable "karpenter_node_instance_profile_name" {
  description = "IAM instance profile name for Karpenter nodes (leave empty to use module-created profile)"
  type        = string
}

variable "enable_deterministic_naming" {
  description = "Use deterministic naming without random suffix (set to true for production environments)"
  type        = bool
}

#============================================================
#  EBS CSI Driver Variables
#============================================================
variable "is_ebs_csi_driver_enabled" {
  description = "Whether to enable EBS CSI driver IAM role for IRSA"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_namespace" {
  description = "Kubernetes namespace for EBS CSI driver service account"
  type        = string
  default     = "kube-system"
}

variable "ebs_csi_driver_service_account" {
  description = "Kubernetes service account name for EBS CSI driver IRSA"
  type        = string
  default     = "ebs-csi-controller-sa"
}
