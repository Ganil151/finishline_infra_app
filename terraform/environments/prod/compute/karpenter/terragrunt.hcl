#============================================================
#                 ***  Karpenter Module  ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//compute/karpenter"
}

locals {
  compute_tag = {
    project_name = "finishline-infra-app"
    environment  = "prod"
    managed_by   = "finishline-infra-team"
  }

  #============================================================
  #  Karpenter Configuration (per RUNBOOK.md)
  #  Prod Environment Specifications:
  #    - Instance Types: m5.large, m5.xlarge, m5.2xlarge, c5.xlarge
  #    - Max CPU: 500
  #    - Capacity Types: on-demand, spot (prod prefers on-demand)
  #============================================================
  karpenter_config = {
    instance_types = ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.xlarge"]
    max_cpu        = 500
    capacity_types = ["on-demand", "spot"]
    ami_family     = "Bottlerocket"
    volume_size    = "100Gi"
    namespace      = "karpenter"

    # Subnet and SG tags for Karpenter discovery
    subnet_tags = {
      "karpenter.sh/discovery" = "finishline-infra-app-prod-eks"
    }
    security_group_tags = {
      "karpenter.sh/discovery" = "finishline-infra-app-prod-eks"
    }

    detailed_monitoring = true
  }
}

#============================================================
#  Dependencies
#============================================================
dependency "eks" {
  config_path = "../eks"
}

dependency "iam" {
  config_path = "../../security/iam"
}

inputs = {
  #============================================================
  #  Project Variables
  #============================================================
  project_name  = local.compute_tag.project_name
  environment   = local.compute_tag.environment
  computed_tags = local.compute_tag

  #============================================================
  #  Cluster Connection (from EKS dependency)
  #============================================================
  cluster_name               = dependency.eks.outputs.cluster_name
  cluster_endpoint           = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate     = dependency.eks.outputs.cluster_certificate_authority_data
  aws_region                 = "us-east-1"

  #============================================================
  #  Karpenter Configuration
  #============================================================
  karpenter_instance_profile_name = dependency.iam.outputs.karpenter_node_instance_profile_name
  karpenter_node_role_name        = dependency.iam.outputs.karpenter_node_role_name

  karpenter_subnet_tags = local.karpenter_config.subnet_tags

  karpenter_security_group_tags = local.karpenter_config.security_group_tags

  karpenter_instance_types = local.karpenter_config.instance_types

  karpenter_max_cpu = local.karpenter_config.max_cpu

  karpenter_capacity_types = local.karpenter_config.capacity_types

  karpenter_ami_family = local.karpenter_config.ami_family

  karpenter_volume_size = local.karpenter_config.volume_size

  karpenter_detailed_monitoring = local.karpenter_config.detailed_monitoring
}
