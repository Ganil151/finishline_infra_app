variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment for the EKS cluster"
  type        = string
}

variable "manage_by" {
  description = "The entity responsible for managing the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster control plane"
  type        = string
}

variable "node_role_arn" {
  description = "The ARN of the IAM role for the EKS node groups"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster and node groups"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the EKS cluster"
  type        = list(string)
}

variable "is_eks_cluster_enabled" {
  description = "Whether the EKS cluster is enabled"
  type        = bool
}

variable "is_eks_node_group_enabled" {
  description = "Whether the EKS node groups are enabled"
  type        = bool
}

variable "is_eks_addons_enabled" {
  description = "Whether the EKS addons are enabled"
  type        = bool
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "cluster_enabled_log_types" {
  description = "List of control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "endpoint_private_access" {
  description = "Whether the EKS cluster API server endpoint has private access enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS cluster API server endpoint has public access enabled"
  type        = bool
  default     = false
}

variable "addons" {
  description = "Map of EKS addons to install. Key is the addon name; value is an object with version and optional service_account_role_arn."
  type        = map(any)
  default     = {}
}

variable "desired_capacity_on_demand" {
  description = "The desired number of on-demand nodes"
  type        = number
  default     = 2
}

variable "max_capacity_on_demand" {
  description = "The maximum number of on-demand nodes"
  type        = number
  default     = 4
}

variable "min_capacity_on_demand" {
  description = "The minimum number of on-demand nodes"
  type        = number
  default     = 1
}

variable "ondemand_instance_types" {
  description = "List of EC2 instance types for the on-demand node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_capacity_spot" {
  description = "The desired number of spot nodes"
  type        = number
  default     = 1
}

variable "max_capacity_spot" {
  description = "The maximum number of spot nodes"
  type        = number
  default     = 3
}

variable "min_capacity_spot" {
  description = "The minimum number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_instance_types" {
  description = "List of EC2 instance types for the spot node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}
