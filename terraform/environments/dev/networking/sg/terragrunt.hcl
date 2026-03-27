#============================================================
#            *** Security Groups Module ***
#============================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../vpc"]
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-mock-id"
  }
}



terraform {
  # CORRECTED: Double-slash syntax for module source path
  source = "../../../../modules//networking/sg"
}

inputs = {
 
  project_name = "finishline-infra-app"
  environment  = "dev"
  managed_by   = "finishline-infra-team"
  aws_region   = "us-east-1"

  security_group_name        = "finishline-dev-sg"
  security_group_description = "Security group for dev environment"
  vpc_id                     = dependency.vpc.outputs.vpc_id

  # Karpenter discovery tags for security group auto-discovery
  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-infra-app-dev-eks"

  ingress_rules = [
    {
      description = "SSH access from internet"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["186.6.206.40/32"]
    },
    {
      description = "HTTP access from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS access from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "MySQL - VPC internal only"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "EKS Kubelet - VPC internal only"
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Environment = "dev"
    ManagedBy   = "finishline-infra-team"
    Project     = "finishline-infra-app"
  }
}