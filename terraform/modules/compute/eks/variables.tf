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

variable "computed_tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
}

#============================================================
#  EKS Cluster Variables
#============================================================
variable "cluster_name" {
  description = "Name of the EKS cluster (e.g., finishline-infra-app-dev-eks)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (e.g., 1.28, 1.29, 1.30)"
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.cluster_version))
    error_message = "cluster_version must be in the format X.Y (e.g., 1.30)."
  }
}

variable "is_eks_cluster_enabled" {
  description = "Whether to enable EKS cluster resources"
  type        = bool
}

variable "eks_cluster_role_arn" {
  description = "ARN of the IAM role for EKS cluster (from security/iam module output)"
  type        = string
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable (api, audit, authenticator, controllerManager, scheduler)"
  type        = list(string)
}

variable "subnets" {
  description = "List of private subnet IDs for the EKS cluster VPC"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Whether to enable private access to the EKS endpoint"
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether to enable public access to the EKS endpoint"
  type        = bool
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS cluster publicly"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the EKS cluster control plane"
  type        = list(string)
}

variable "authentication_mode" {
  description = "Authentication mode for the EKS cluster (API, API_AND_CONFIG_MAP, CONFIG_MAP)"
  type        = string

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be one of: API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether to bootstrap cluster creator admin permissions"
  type        = bool
}

variable "enable_upgrade_policy" {
  description = "Whether to enable upgrade policy for the EKS cluster"
  type        = bool
}

variable "upgrade_policy_support_type" {
  description = "Support type for upgrade policy (STANDARD or EXTENDED)"
  type        = string
}

#============================================================
#  EKS Addon Variables
#============================================================
variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver addon (for IRSA). Leave empty to skip IRSA configuration."
  type        = string
}

#============================================================
#  EKS Access Entry Variables
#============================================================
variable "cluster_admin_principals" {
  description = "Map of IAM principal ARNs to grant cluster admin access"
  type        = map(string)
}

variable "cluster_admin_kubernetes_groups" {
  description = "List of Kubernetes groups to associate with cluster admin principals"
  type        = list(string)
}

variable "cluster_admin_policy_arn" {
  description = "ARN of the IAM policy to associate with cluster admin principals"
  type        = string
}

#============================================================
#  EKS Node Group Variables
#============================================================
variable "is_eks_nodegroup_enabled" {
  description = "Whether to enable EKS node group resources"
  type        = bool
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the IAM role for the EKS node group (from security/iam module output)"
  type        = string
}

variable "node_group_subnets" {
  description = "List of subnet IDs for the EKS node group"
  type        = list(string)
}

variable "node_group_ami_type" {
  description = "AMI type for the EKS node group (AL2_x86_64, AL2_ARM_64, BOTTLEROCKET_x86_64, etc.)"
  type        = string

  validation {
    condition     = contains(["AL2_x86_64", "AL2_ARM_64", "BOTTLEROCKET_x86_64", "BOTTLEROCKET_ARM_64", "CUSTOM"], var.node_group_ami_type)
    error_message = "The API rigorously enforces case-sensitivity. The provider strictly requires lower-case 'x' in 'x86_64' (e.g., 'BOTTLEROCKET_x86_64'). 'BOTTLEROCKET_X86_64' is invalid and will natively fail the AWS API constraint validation."
  }
}

variable "node_group_instance_types" {
  description = "List of instance types for the EKS node group"
  type        = list(string)
}

variable "node_group_capacity_type" {
  description = "Capacity type for the EKS node group (ON_DEMAND or SPOT)"
  type        = string
}

variable "node_group_disk_size" {
  description = "Disk size in GiB for the EKS node group"
  type        = number
}

variable "node_group_scaling_config" {
  description = "Scaling configuration for the EKS node group"
  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })
}

variable "node_group_update_config" {
  description = "Update configuration for the EKS node group"
  type = object({
    max_unavailable = number
  })
}

variable "node_group_launch_template_id" {
  description = "Launch template ID for the EKS node group (leave empty to use default node group settings)"
  type        = string
}

variable "node_group_launch_template_version" {
  description = "Launch template version for the EKS node group (default: $Default)"
  type        = string
}

variable "node_group_labels" {
  description = "Map of Kubernetes labels to apply to the EKS node group"
  type        = map(string)
}

variable "node_group_tags" {
  description = "Map of AWS tags to apply to the EKS node group"
  type        = map(string)
}

variable "node_group_taints" {
  description = "List of Kubernetes taints to apply to the EKS node group"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
}

variable "node_group_timeouts" {
  description = "Timeouts for EKS node group operations"
  type = object({
    create = string
    update = string
    delete = string
  })
}
