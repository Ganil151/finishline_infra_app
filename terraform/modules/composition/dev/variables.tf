# ===========================================================
#               ***   Project Variables   ***
# ===========================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "managed_by" {
  description = "Team managing this resource"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Centralized common tags from root.hcl"
  type        = map(string)
}

# ===========================================================
#               ***   VPC Variables   ***
# ===========================================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets_cidr" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames"
  type        = bool
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support"
  type        = bool
}

variable "enable_karpenter_discovery" {
  description = "Whether to enable Karpenter discovery tags"
  type        = bool
}

variable "karpenter_cluster_name" {
  description = "Cluster name to use for Karpenter discovery tags"
  type        = string
}

variable "vpc_ingress_rules" {
  description = "List of ingress rules for the network ACL"
  type = list(object({
    rule_no    = number
    from_port  = number
    to_port    = number
    protocol   = string
    action     = string
    cidr_block = string
  }))
}

variable "vpc_egress_rules" {
  description = "List of egress rules for the network ACL"
  type = list(object({
    rule_no    = number
    from_port  = number
    to_port    = number
    protocol   = string
    action     = string
    cidr_block = string
  }))
}

variable "vpc_create_eks_endpoint" {
  description = "Whether to create the EKS interface endpoint"
  type        = bool
}

variable "vpc_create_sts_endpoint" {
  description = "Whether to create the STS interface endpoint"
  type        = bool
}

variable "vpc_create_ec2_endpoint" {
  description = "Whether to create the EC2 interface endpoint"
  type        = bool
}

variable "vpc_create_s3_endpoint" {
  description = "Whether to create the S3 gateway endpoint"
  type        = bool
}

# ===========================================================
#               ***   Security Group Variables   ***
# ===========================================================
variable "security_group_name" {
  description = "Name of the security group"
  type        = string
}

variable "security_group_description" {
  description = "Description of the security group"
  type        = string
}

variable "sg_ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "sg_egress_rules" {
  description = "List of egress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

# ===========================================================
#               ***   ALB Variables   ***
# ===========================================================
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "alb_internal" {
  description = "Whether the ALB is internal"
  type        = bool
}

variable "alb_type" {
  description = "Type of the Application Load Balancer"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection for the ALB"
  type        = bool
}

variable "alb_enable_http2" {
  description = "Whether to enable HTTP2 for the ALB"
  type        = bool
}

variable "alb_enable_cross_zone_load_balancing" {
  description = "Whether to enable cross-zone load balancing"
  type        = bool
}

variable "alb_target_group_port" {
  description = "Port for the ALB target group"
  type        = number
}

variable "alb_target_group_protocol" {
  description = "Protocol for the ALB target group"
  type        = string
}

variable "alb_target_type" {
  description = "Type of target for the ALB group"
  type        = string
}

variable "alb_health_check_path" {
  description = "Path for ALB health checks"
  type        = string
}

variable "alb_health_check_matcher" {
  description = "Response code matcher for ALB health checks"
  type        = string
}

variable "alb_health_check_interval" {
  description = "Interval for ALB health checks"
  type        = number
}

variable "alb_health_check_enabled" {
  description = "Whether to enable health checks"
  type        = bool
}

variable "alb_healthy_threshold" {
  description = "Healthy threshold for ALB"
  type        = number
}

variable "alb_unhealthy_threshold" {
  description = "Unhealthy threshold for ALB"
  type        = number
}

variable "alb_health_check_timeout" {
  description = "Timeout for ALB health checks"
  type        = number
}

variable "alb_stickiness_type" {
  description = "Type of stickiness for ALB"
  type        = string
}

variable "alb_stickiness_enabled" {
  description = "Whether to enable stickiness"
  type        = bool
}

variable "alb_stickiness_cookie_duration" {
  description = "Duration for stickiness cookie"
  type        = number
}

variable "alb_listener_port" {
  description = "Port for the ALB listener"
  type        = number
}

variable "alb_listener_protocol" {
  description = "Protocol for the ALB listener"
  type        = string
}

variable "alb_listener_default_action" {
  description = "Default action for the ALB listener"
  type        = string
}

variable "alb_enable_access_logs" {
  description = "Whether to enable access logs for the ALB"
  type        = bool
  default     = false
}

variable "alb_access_logs_s3_bucket" {
  description = "S3 bucket for storing ALB access logs"
  type        = string
  default     = ""
}

variable "alb_access_logs_s3_prefix" {
  description = "Prefix for ALB access log files in the S3 bucket"
  type        = string
  default     = ""
}

# ===========================================================
#               ***   IAM Variables   ***
# ===========================================================
variable "is_eks_cluster_enabled" {
  description = "Whether to enable EKS cluster IAM resources"
  type        = bool
}

variable "is_eks_nodegroup_role_enabled" {
  description = "Whether to enable EKS nodegroup IAM role"
  type        = bool
}

variable "iam_is_eks_role_enabled" {
  description = "Whether to enable EKS role"
  type        = bool
}

variable "iam_eks_oidc_url" {
  description = "EKS OIDC URL for IRSA"
  type        = string
  default     = ""
}

variable "iam_oidc_thumbprint" {
  description = "OIDC thumbprint"
  type        = string
}

variable "iam_s3_access_type" {
  description = "S3 access type (read/write)"
  type        = string
}

variable "iam_is_karpenter_enabled" {
  description = "Whether to enable Karpenter IAM resources"
  type        = bool
}

variable "iam_is_ebs_csi_driver_enabled" {
  description = "Whether to enable EBS CSI driver IAM resources"
  type        = bool
}

variable "iam_name_suffix" {
  description = "Suffix for IAM resource names"
  type        = string
}

variable "iam_eks_oidc_subject" {
  description = "Kubernetes service account subject for OIDC trust"
  type        = string
}

variable "iam_eks_oidc_namespace" {
  description = "Kubernetes namespace for the OIDC service account"
  type        = string
}

variable "iam_eks_oidc_service_account" {
  description = "Kubernetes service account name for OIDC identity"
  type        = string
}

variable "iam_s3_bucket_arn" {
  description = "ARN of the S3 bucket to grant OIDC access"
  type        = string
}

variable "iam_s3_prefix" {
  description = "S3 bucket prefix to grant access to"
  type        = string
}

variable "iam_karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter roles"
  type        = string
}

variable "iam_karpenter_service_account" {
  description = "Kubernetes service account name for Karpenter IRSA"
  type        = string
}

variable "iam_karpenter_cluster_name" {
  description = "EKS cluster name for Karpenter provisioning"
  type        = string
}

variable "iam_karpenter_node_instance_profile_name" {
  description = "IAM instance profile name for Karpenter nodes"
  type        = string
}

variable "iam_enable_deterministic_naming" {
  description = "Use deterministic naming for IAM roles"
  type        = bool
}

variable "iam_ebs_csi_driver_namespace" {
  description = "Kubernetes namespace for EBS CSI driver"
  type        = string
}

variable "iam_ebs_csi_driver_service_account" {
  description = "Kubernetes service account name for EBS CSI IRSA"
  type        = string
}

# ===========================================================
#               ***   EKS Variables   ***
# ===========================================================
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "endpoint_private_access" {
  description = "Whether to enable private access to the EKS endpoint"
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether to enable public access to the EKS endpoint"
  type        = bool
}

variable "eks_cluster_enabled_log_types" {
  description = "List of log types to enable for the EKS cluster"
  type        = list(string)
}

variable "eks_authentication_mode" {
  description = "Authentication mode for the EKS cluster"
  type        = string
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "node_group_instance_types" {
  description = "List of instance types for the EKS node group"
  type        = list(string)
}

variable "node_group_scaling_config" {
  description = "Scaling configuration for the EKS node group"
  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })
}

variable "eks_node_group_ami_type" {
  description = "AMI type for the EKS node group"
  type        = string
}

variable "eks_node_group_capacity_type" {
  description = "Capacity type for the EKS node group"
  type        = string
}

variable "eks_node_group_disk_size" {
  description = "Disk size for the EKS node group (GB)"
  type        = number
}

variable "eks_node_group_labels" {
  description = "Labels for the EKS node group"
  type        = map(string)
}

variable "eks_node_group_timeouts" {
  description = "Timeouts for EKS node group operations"
  type = object({
    create = string
    update = string
    delete = string
  })
}

# ===========================================================
#               ***   Key Pair Variables   ***
# ===========================================================
variable "key_name" {
  description = "Name of the key pair"
  type        = string
}

variable "key_algorithm" {
  description = "Algorithm for the key pair"
  type        = string
}

variable "rsa_bits" {
  description = "Number of bits for the RSA key"
  type        = number
}

# ===========================================================
#               ***   Jumphost Variables   ***
# ===========================================================
variable "is_finishline_jumphost_enabled" {
  description = "Whether to enable the jumphost instance"
  type        = bool
}

variable "jumphost_ami_id" {
  description = "AMI ID for the jumphost instance"
  type        = string
}

variable "jumphost_instance_type" {
  description = "EC2 instance type for the jumphost"
  type        = string
}

variable "jumphost_root_volume_size" {
  description = "Root volume size for the jumphost"
  type        = number
}

variable "jumphost_root_volume_type" {
  description = "Root volume type for the jumphost"
  type        = string
}

variable "jumphost_metadata_http_tokens" {
  description = "Whether IMDSv2 is required for jumphost"
  type        = string
}

variable "jumphost_user_data_script_path" {
  description = "Path to the user data script for jumphost"
  type        = string
}

variable "jumphost_user_data_replace_on_change" {
  description = "Whether to replace the jumphost when user data changes"
  type        = bool
}

# ===========================================================
#               ***   Karpenter Variables   ***
# ===========================================================
variable "karpenter_instance_types" {
  description = "List of instance types for Karpenter to provision"
  type        = list(string)
}

variable "karpenter_max_cpu" {
  description = "Maximum CPU cores Karpenter can provision"
  type        = number
}

variable "karpenter_capacity_types" {
  description = "List of capacity types for Karpenter (spot, on-demand)"
  type        = list(string)
}

variable "karpenter_ami_family" {
  description = "AMI family for Karpenter nodes (AL2, Bottlerocket)"
  type        = string
}

variable "karpenter_volume_size" {
  description = "Volume size for Karpenter nodes"
  type        = string
}

variable "karpenter_detailed_monitoring" {
  description = "Whether to enable detailed monitoring for Karpenter nodes"
  type        = bool
}

variable "karpenter_interruption_queue_name" {
  description = "Name of the interruption queue for Karpenter"
  type        = string
}
