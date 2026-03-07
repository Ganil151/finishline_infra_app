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

variable "create_key_pair" {
  description = "Whether to create a new key pair or use an existing one"
  type        = bool
  default     = true
}

#================================================================
# Variables for IAM
#================================================================

variable "is_eks_role_enabled" {
  description = "Whether the EKS cluster IAM role is enabled"
  type        = bool
}

variable "is_eks_nodegroup_role_enabled" {
  description = "Whether the EKS node group IAM role is enabled"
  type        = bool
}

#================================================================
# Variables for the EKS Cluster
#================================================================

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
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

variable "endpoint_private_access" {
  description = "Whether the EKS cluster API endpoint has private access enabled"
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether the EKS cluster API endpoint has public access enabled"
  type        = bool
}

variable "cluster_enabled_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
}

variable "addons" {
  description = "Map of EKS addons. Key = addon name; value = object with version and optional service_account_role_arn."
  type        = map(any)
  default     = {}
}

variable "desired_capacity_on_demand" {
  description = "The desired number of on-demand nodes"
  type        = number
}

variable "max_capacity_on_demand" {
  description = "The maximum number of on-demand nodes"
  type        = number
}

variable "min_capacity_on_demand" {
  description = "The minimum number of on-demand nodes"
  type        = number
}

variable "ondemand_instance_types" {
  description = "List of EC2 instance types for the on-demand node group"
  type        = list(string)
}

variable "desired_capacity_spot" {
  description = "The desired number of spot nodes"
  type        = number
}

variable "max_capacity_spot" {
  description = "The maximum number of spot nodes"
  type        = number
}

variable "min_capacity_spot" {
  description = "The minimum number of spot nodes"
  type        = number
}

variable "spot_instance_types" {
  description = "List of EC2 instance types for the spot node group"
  type        = list(string)
}

#================================================================
# Variables for the EC2 Jump Host
#================================================================

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance. If empty, will use the latest Amazon Linux 2 AMI"
  type        = string
  default     = ""
}

variable "jump_host_instance_type" {
  description = "The instance type for the jump host"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the EC2 instance (deprecated - now uses VPC module output)"
  type        = list(string)
  default     = []
}

variable "finishline_sg_id" {
  description = "The security group ID to attach to the EC2 instance (deprecated - EC2 module creates its own)"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "The key pair name for the EC2 instance (deprecated - uses key_name variable)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "The size of the root volume in GB"
  type        = number
  default     = 20
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for the EC2 instance"
  type        = bool
  default     = true
}

variable "user_data_base64" {
  description = "The base64 encoded user data for the EC2 instance"
  type        = string
  default     = ""
}

variable "ec2_component" {
  description = "The component name for tagging"
  type        = string
  default     = "jump-host"
}

variable "cost_center" {
  description = "The cost center for tagging"
  type        = string
  default     = ""
}

variable "ec2_tags" {
  description = "Additional tags to apply to the EC2 instance"
  type        = map(string)
  default     = {}
}
