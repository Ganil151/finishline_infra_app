#============================================================
#         ***   Terragrunt Root Configuration   ***
#============================================================

locals {
  account_id = get_aws_account_id()
  region     = "us-east-1"

  common_tags = {
    Project     = "finishline-infra-app"
    ManagedBy   = "finishline-infra-team"
    Environment = get_env("TG_ENV", "dev")
    Reporter    = "Ganil Batist Yan"
  }

  #============================================================
  #  Conditional Provider Selection
  #============================================================
  is_k8s_module = length(regexall("compute/karpenter|compute/helm$", path_relative_to_include())) > 0

  k8s_provider_content = <<EOF
#============================================================
#          ***  Kubernetes Provider Configuration  ***
#============================================================
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

#============================================================
#          ***  Helm Provider Configuration  ***
#============================================================
provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

#============================================================
#          ***  Time Provider Configuration  ***
#============================================================
provider "time" {}

#============================================================
#          ***  Kubectl Provider Configuration  ***
#============================================================
provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--region",
      var.aws_region
    ]
  }
  load_config_file = false
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket       = "finishline-infra-app-e534d5ea"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "finishline-infra-app"
      Environment = "${get_env("TG_ENV", "dev")}"
      ManagedBy   = "finishline-infra-team"
      Terraform   = "true"
    }
  }
}

provider "tls" {}

provider "random" {}
EOF
}

# Generate Kubernetes/Helm/Kubectl providers conditionally
# This logic is only active for modules that manage cluster-level resources
generate "kubernetes-provider" {
  path      = "kubernetes-provider.tf"
  if_exists = "overwrite"
  contents  = local.is_k8s_module ? local.k8s_provider_content : "# No Kubernetes provider needed for this module (detected by root.hcl)"
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<EOF
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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
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