#========================================================================
#                      *** EKS Variables Configuration ***
#========================================================================
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
#________________________________________________________________________
#                     EKS CLUSTER VARIABLES Configuration
#________________________________________________________________________
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "cluster_principal" {
  description = "List of principals to be added to the EKS cluster"
  type        = list(string)
}

variable "cluster_admin_principal" {
  description = "List of principals to be added as cluster admins"
  type        = list(string)
}

variable "cluster_admin_kubernetes_groups" {
  description = "List of Kubernetes groups for cluster admins"
  type        = list(string)
}

variable "nodegroup_principal" {
  description = "List of principals to be added to the EKS node group"
  type        = list(string)
}

variable "nodegroup_admin_kubernetes_groups" {
  description = "List of Kubernetes groups for node group admins"
  type        = list(string)
}

variable "cluster_enabled_log_types" {
  description = "List of log types to be enabled for the EKS cluster"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Whether to enable private access to the EKS cluster"
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether to enable public access to the EKS cluster"
  type        = bool
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks to allow public access to the EKS cluster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to be associated with the EKS cluster"
  type        = list(string)
}

variable "authentication_mode" {
  description = "Authentication mode for the EKS cluster"
  type        = string
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether to enable bootstrap cluster creator admin permissions"
  type        = bool
}

variable "enable_upgrade_policy" {
  description = "Whether to enable upgrade policy for the EKS cluster"
  type        = bool
}

variable "upgrade_support_type" {
  description = "Support type for the EKS cluster upgrade"
  type        = string
}

variable "is_eks_cluster_enabled" {
  description = "Whether to enable the EKS cluster"
  type        = bool
}

variable "is_nodegroup_enabled" {
  description = "Whether to enable the EKS node group"
  type        = bool
}

variable "tags" {
  description = "Tags to be added to the EKS cluster"
  type        = map(string)
}

variable "node_group_tags" {
  description = "Tags to be added to the EKS node group"
  type        = map(string)
}
#________________________________________________________________________
#                     MISSING VARIABLES ADDED BY AUDIT
#________________________________________________________________________

variable "eks_cluster_role_arn" {
  description = "ARN for the EKS cluster role"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "cluster_admin_policy_arn" {
  description = "ARN of the cluster admin policy"
  type        = string
}

variable "ebs_csi_driver_role_arn" {
  description = "ARN for the EBS CSI Driver IAM Role"
  type        = string
}

variable "node_role_arn" {
  description = "ARN for the node group role"
  type        = string
}

variable "node_group_subnets" {
  description = "List of subnets for the node group"
  type        = list(string)
}

variable "node_group_ami_type" {
  description = "AMI type for the node group"
  type        = string
}

variable "node_group_instance_types" {
  description = "Instance types for the node group"
  type        = list(string)
}

variable "node_group_min_size" {
  description = "Minimum size of node group"
  type        = number
}

variable "node_group_max_size" {
  description = "Maximum size of node group"
  type        = number
}

variable "node_group_capacity_type" {
  description = "Capacity type for node group (ON_DEMAND or SPOT)"
  type        = string
}

variable "node_group_desired_size" {
  description = "Desired size of node group"
  type        = number
}

variable "node_group_launch_template_id" {
  description = "Launch template ID"
  type        = string
}

variable "launch_template_version" {
  description = "Version of launch template"
  type        = string
}

variable "node_group_update_config_max_unavailable" {
  description = "Max unavailable"
  type        = number
}

variable "node_group_update_config_max_unavailable_percentage" {
  description = "Max unavailable percentage"
  type        = number
}

variable "node_group_create_timeout" {
  description = "Node group create timeout"
  type        = string
}

variable "node_group_update_timeout" {
  description = "Node group update timeout"
  type        = string
}

variable "node_group_delete_timeout" {
  description = "Node group delete timeout"
  type        = string
}
