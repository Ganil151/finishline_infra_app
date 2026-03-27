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

variable "computed_tags" {
  description = "Additional tags to apply"
  type        = map(string)
}

variable "enable_karpenter_discovery" {
  description = "Whether to enable Karpenter discovery tags on subnets and security groups"
  type        = bool
}

variable "karpenter_cluster_name" {
  description = "Cluster name to use for Karpenter discovery tags (only used if enable_karpenter_discovery is true)"
  type        = string
}

# ===========================================================
#               ***   VPC Variables   ***
# ===========================================================
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support"
  type        = bool
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames"
  type        = bool
}

variable "public_subnets_cidr" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "ingress_rules_transform" {
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

variable "egress_rules_transform" {
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

# ===========================================================
#          ***   VPC Endpoint Variables   ***
# ===========================================================
variable "create_eks_endpoint" {
  description = "Whether to create EKS API VPC endpoint"
  type        = bool
  default     = true
}

variable "create_sts_endpoint" {
  description = "Whether to create STS VPC endpoint"
  type        = bool
  default     = true
}

variable "create_ec2_endpoint" {
  description = "Whether to create EC2 VPC endpoint"
  type        = bool
  default     = true
}

variable "create_s3_endpoint" {
  description = "Whether to create S3 VPC endpoint"
  type        = bool
  default     = true
}
