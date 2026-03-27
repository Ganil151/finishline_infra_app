#============================================================
#                 ***  Karpenter Module  ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//compute/karpenter"
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

locals {
  compute_tag = {
    project_name = "finishline-infra-app"
    environment  = "dev"
    managed_by   = "finishline-infra-team"
  }

  #============================================================
  #  Karpenter Configuration 
  #============================================================
  karpenter_config = {
    instance_types = ["m5.large", "m5.xlarge", "c5.large"]
    max_cpu        = 50
    capacity_types = ["spot", "on-demand"]
    ami_family     = "Bottlerocket"
    volume_size    = "50Gi"
    namespace      = "karpenter"

    # Subnet and SG tags for Karpenter discovery
    subnet_tags = {
      "karpenter.sh/discovery" = "finishline-infra-app-dev-eks"
    }
    security_group_tags = {
      "karpenter.sh/discovery" = "finishline-infra-app-dev-eks"
    }

    detailed_monitoring = false
  }
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
  karpenter_controller_role_arn   = dependency.iam.outputs.karpenter_controller_role_arn

  # Interruption queue is optional - set empty for basic setup
  karpenter_interruption_queue_name = ""

  karpenter_subnet_tags = local.karpenter_config.subnet_tags

  karpenter_security_group_tags = local.karpenter_config.security_group_tags

  karpenter_instance_types = local.karpenter_config.instance_types

  karpenter_max_cpu = local.karpenter_config.max_cpu

  karpenter_capacity_types = local.karpenter_config.capacity_types

  karpenter_ami_family = local.karpenter_config.ami_family

  karpenter_volume_size = local.karpenter_config.volume_size

  karpenter_detailed_monitoring = local.karpenter_config.detailed_monitoring
}
