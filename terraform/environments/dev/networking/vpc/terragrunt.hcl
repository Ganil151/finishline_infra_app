#============================================================
#  Terragrunt Configuration - VPC Module
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules/networking/vpc"
}

inputs = {
  project_name = "finishline-infra-app"
  environment  = "dev"
  managed_by   = "finishline-infra-team"
  aws_region   = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  availability_zones = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]
  public_subnets_cidr = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
  private_subnets_cidr = [
    "10.0.10.0/24",
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Karpenter discovery tags for subnet auto-discovery
  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-infra-app-dev-eks"

  computed_tags = {}

  ingress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 120
      from_port  = 22
      to_port    = 22
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 130
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]

  egress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 120
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]

  #============================================================
  #  VPC Endpoint Configuration
  #============================================================
  create_eks_endpoint = true
  create_sts_endpoint = true
  create_ec2_endpoint = true
  create_s3_endpoint  = true
}
