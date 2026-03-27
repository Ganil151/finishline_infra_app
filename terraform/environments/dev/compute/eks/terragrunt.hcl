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
    environment  = "dev"
    managed_by   = "finishline-infra-team"
  }
}

#============================================================
#  Dependencies
#============================================================
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
  #  Project Variables
  #============================================================
  project_name  = local.compute_tag.project_name
  environment   = local.compute_tag.environment
  managed_by    = local.compute_tag.managed_by
  computed_tags = local.compute_tag

  #============================================================
  #  EKS Cluster Variables 
  #============================================================
  cluster_name = "finishline-infra-app-dev-eks"

  cluster_version = "1.30"

  is_eks_cluster_enabled = true

  eks_cluster_role_arn = dependency.iam.outputs.eks_cluster_role_arn

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  subnets = dependency.vpc.outputs.private_subnets_ids

  # Endpoint access - Enable public for dev environment (disable for prod)
  endpoint_private_access = true
  endpoint_public_access  = true   # Enable for dev to allow Terraform/Kubectl access
  public_access_cidrs     = ["0.0.0.0/0"]  # Restrict to your IP in production

  security_group_ids = [dependency.sg.outputs.security_group_id]

  authentication_mode = "API"

  bootstrap_cluster_creator_admin_permissions = true
  enable_upgrade_policy                       = false
  upgrade_policy_support_type                 = "STANDARD"

  #============================================================
  #  EKS Access Entry Variables 
  #============================================================
  cluster_admin_principals = {}

  cluster_admin_kubernetes_groups = []
  cluster_admin_policy_arn        = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"

  #============================================================
  #  EKS Node Group Variables
  #============================================================
  is_eks_nodegroup_enabled = true

  node_group_name = "default-nodegroup"

  node_group_role_arn = dependency.iam.outputs.eks_nodegroup_role_arn

  node_group_subnets = dependency.vpc.outputs.private_subnets_ids

  # Using BOTTLEROCKET_x86_64 for hardened, minimal container OS
  node_group_ami_type = "BOTTLEROCKET_x86_64"

  # Base node group for essential workloads
  # Karpenter will handle specialized/scalable workloads
  node_group_instance_types = ["t3.medium"]

  node_group_capacity_type = "ON_DEMAND"

  node_group_disk_size = 50

  # No auto-scaling for now (fixed capacity)
  node_group_scaling_config = {
    desired_size = 2
    min_size     = 2
    max_size     = 2
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

  #============================================================
  #  EKS Addon Variables
  #============================================================
  # EBS CSI Driver will use instance credentials until OIDC is configured
  ebs_csi_driver_role_arn = ""
}
