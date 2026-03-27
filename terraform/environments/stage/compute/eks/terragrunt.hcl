#============================================================
#                 *** EKS Module  ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//compute/eks"
}

locals {
  compute_tag = {
    project_name = "finishline-infra-app"
    environment  = "stage"
    managed_by   = "finishline-infra-team"
  }
}

dependency "iam" {
  config_path = "../../security/iam"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
}

dependency "sg" {
  config_path = "../../networking/sg"
}

inputs = {
  #============================================================
  #  Project Variables (5 required)
  #============================================================
  project_name  = local.compute_tag.project_name
  environment   = local.compute_tag.environment
  managed_by    = local.compute_tag.managed_by
  aws_region    = "us-east-1"
  computed_tags = local.compute_tag

  #============================================================
  #  EKS Cluster Variables (11 required)
  #============================================================
  cluster_name = "finishline-infra-app-stage-eks"

  cluster_version = "1.30"

  is_eks_cluster_enabled = true

  eks_cluster_role_arn = dependency.iam.outputs.eks_cluster_role_arn

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  subnets = dependency.vpc.outputs.private_subnets_ids

  endpoint_private_access = true
  endpoint_public_access  = false
  public_access_cidrs     = ["0.0.0.0/0"]

  security_group_ids = [dependency.sg.outputs.security_group_id]

  authentication_mode = "API"

  bootstrap_cluster_creator_admin_permissions = true
  enable_upgrade_policy                       = false
  upgrade_policy_support_type                 = "STANDARD"

  #============================================================
  #  EKS Access Entry Variables (3 required)
  #============================================================
  cluster_admin_principals = {}

  cluster_admin_kubernetes_groups = []
  cluster_admin_policy_arn        = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"

  #============================================================
  #  EKS Node Group Variables (17 required)
  #============================================================
  is_eks_nodegroup_enabled = true

  node_group_name = "default-nodegroup"

  node_group_role_arn = dependency.iam.outputs.eks_nodegroup_role_arn

  node_group_subnets = dependency.vpc.outputs.private_subnets_ids

  node_group_ami_type = "BOTTLEROCKET_x86_64"

  node_group_instance_types = ["t3.medium"]

  node_group_capacity_type = "ON_DEMAND"

  node_group_disk_size = 100

  node_group_scaling_config = {
    desired_size = 3
    min_size     = 3
    max_size     = 3
  }

  node_group_update_config = {
    max_unavailable = 1
  }

  node_group_launch_template_id      = ""
  node_group_launch_template_version = "$Default"

  node_group_labels = {
    "node-group-type" = "base"
  }
  node_group_tags = {}

  node_group_taints = []

  node_group_timeouts = {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
