#========================================================================
#                  *** Finishline Project Variables ***
#========================================================================
variable "project_name" {
  description = "The name of the project"
  type        = string
}
variable "environment" {
  description = "The environment name"
  type        = string
}
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
variable "aws_region" {
  description = "The AWS region"
  type        = string
}
#_______________________*** Karpenter Variables *** ______________________
variable "enable_karpenter_discovery" {
  description = "Whether to enable Karpenter discovery"
  type        = bool
}

variable "karpenter_cluster_name" {
  description = "The name of the Karpenter cluster"
  type        = string
}

#========================================================================
#                  *** Virtual Private Cloud Variables ***
#========================================================================
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}
variable "enable_dns_support" {
  description = "Whether to enable DNS support for the VPC"
  type        = bool
}
variable "enable_dns_hostnames" { 
  description = "Whether to enable DNS hostnames for the VPC"
  type        = bool
}
variable "instance_tenancy" {
  description = "The tenancy of the instances in the VPC"
  type        = string
}
#___________________*** Public Subnets Variables ***______________________
variable "public_subnets_cidr" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
}
variable "public_subnets_az" {
  description = "The availability zones for the public subnets"
  type        = list(string)
}
variable "map_public_ip_on_launch" {
  description = "Whether to map public IP addresses on launch for the public subnets"
  type        = bool
}
#___________________*** Private Subnets Variables ***_____________________
variable "private_subnets_cidr" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
}
variable "private_subnets_az" {
  description = "The availability zones for the private subnets"
  type        = list(string)
}
variable "map_private_ip_on_launch" {
  description = "Whether to map private IP addresses on launch for the private subnets"
  type        = bool
}
#_____________________*** Network ACL Variables *** ______________________
variable "network_acl_ingress_rules" {
  description = "The ingress rules for the network ACL"
  type        = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
variable "network_acl_egress_rules" {
  description = "The egress rules for the network ACL"
  type        = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
variable "private_dns_enabled" {
  description = "Whether to enable private DNS for the VPC"
  type        = bool
}
#_____________________*** Endpoints Variables *** ________________________
variable "create_eks_endpoints" {
  description = "Whether to create EKS endpoints"
  type        = bool
}
variable "create_sts_endpoint" {
  description = "Whether to create STS endpoint"
  type        = bool
}
variable "create_ec2_endpoint" {
  description = "Whether to create EC2 endpoint"
  type        = bool
}
variable "create_s3_endpoint" {
  description = "Whether to create S3 endpoint"
  type        = bool
}