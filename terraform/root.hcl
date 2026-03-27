#============================================================
#         ***   Terragrunt Root Configuration   ***
#============================================================

locals {
  account_id = get_aws_account_id()
  region     = "us-east-1"
  
  common_tags = {
    Project   = "finishline-infra-app"
    ManagedBy = "finishline-infra-team"
    Environment = "${get_env("TG_ENV", "dev")}"
    Reporter  = "Ganil Batist Yan"
  }
}
remote_state {
  backend = "s3"
  config = {
    bucket = "finishline-infra-app-ba3347ce"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true
  }
  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project = "finishline-infra-app"
      Environment = "${get_env("TG_ENV", "dev")}"
      ManagedBy = "finishline-infra-team"
      Terraform = "true"
    }
  }
}

provider "tls" {}

provider "random" {}
EOF
}

# Generate Kubernetes provider for modules that need it (eks, karpenter)
# Note: Kubernetes provider is configured in module-specific provider.tf files
# This file is intentionally empty to avoid conflicts
generate "kubernetes-provider" {
  path = "kubernetes-provider.tf"
  if_exists = "overwrite"
  contents = <<EOF
# Kubernetes provider is configured in module-specific provider.tf files
# This file is intentionally empty to avoid conflicts
EOF
}

generate "versions" {
  path = "versions.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}
EOF
}

inputs = {
  aws_region   = local.region
  project_name = "finishline-infra-app"
  common_tags  = local.common_tags
}