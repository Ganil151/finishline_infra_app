#============================================================
#                 *** IAM Module  ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//security/iam"
}

locals {
  compute_tag = {
    project_name = "finishline-infra-app"
    environment  = "dev"
    managed_by   = "finishline-infra-team"
  }
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
  #  IAM Variables (15 required)
  #============================================================
  cluster_name = "finishline-infra-app-dev-eks"

  name_suffix                   = ""
  is_eks_cluster_enabled        = true
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true

  
  # Dynamically fetch the EKS OIDC URL via Terragrunt run_cmd, preventing Terraform from dropping the IAM Role creation count sequence.
  eks_oidc_url             = trimspace(run_cmd("--terragrunt-quiet", "aws", "eks", "describe-cluster", "--name", "finishline-infra-app-dev-eks", "--region", "us-east-1", "--query", "cluster.identity.oidc.issuer", "--output", "text"))
  oidc_thumbprint          = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  eks_oidc_namespace       = "default"
  eks_oidc_service_account = ""
  eks_oidc_subject         = "" 

  # S3 Access Configuration (for OIDC service account S3 access)
  s3_bucket_arn  = ""
  s3_prefix      = ""
  s3_access_type = "read"

  # Karpenter Configuration
  is_karpenter_enabled             = true
  karpenter_namespace              = "karpenter"
  karpenter_service_account        = "karpenter"
  karpenter_cluster_name           = "finishline-infra-app-dev-eks"
  karpenter_node_instance_profile_name = ""
  enable_deterministic_naming      = false

  # EBS CSI Driver Configuration (for IRSA)
  is_ebs_csi_driver_enabled        = true
  ebs_csi_driver_namespace         = "kube-system"
  ebs_csi_driver_service_account   = "ebs-csi-controller-sa"
}
