#============================================================
#                 *** IAM Module Outputs ***
#============================================================

#============================================================
# EKS Cluster Role Outputs
#============================================================
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = try(aws_iam_role.eks_cluster_role.arn, "")
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = try(aws_iam_role.eks_cluster_role.name, "")
}

#============================================================
# EKS Nodegroup Role Outputs
#============================================================
output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS nodegroup IAM role"
  value       = try(aws_iam_role.eks_nodegroup_role[0].arn, "")
}

output "eks_nodegroup_role_name" {
  description = "Name of the EKS nodegroup IAM role"
  value       = try(aws_iam_role.eks_nodegroup_role[0].name, "")
}

#============================================================
# OIDC Provider Outputs
#============================================================
output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = try(aws_iam_openid_connect_provider.eks_oidc_provider[0].arn, "")
}

output "eks_oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = try(aws_iam_openid_connect_provider.eks_oidc_provider[0].url, "")
}

#============================================================
# OIDC Role Outputs
#============================================================
output "eks_oidc_role_arn" {
  description = "ARN of the EKS OIDC IAM role"
  value       = try(aws_iam_role.eks_oidc_role[0].arn, "")
}

output "eks_oidc_role_name" {
  description = "Name of the EKS OIDC IAM role"
  value       = try(aws_iam_role.eks_oidc_role[0].name, "")
}

#============================================================
# S3 OIDC Policy Outputs
#============================================================
output "s3_oidc_policy_arn" {
  description = "ARN of the S3 OIDC policy"
  value       = try(aws_iam_policy.s3_oidc_policy[0].arn, "")
}

output "s3_oidc_policy_name" {
  description = "Name of the S3 OIDC policy"
  value       = try(aws_iam_policy.s3_oidc_policy[0].name, "")
}

#============================================================
# Karpenter Controller Outputs
#============================================================
output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = try(aws_iam_role.karpenter-controller-role[0].arn, "")
}

output "karpenter_controller_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = try(aws_iam_role.karpenter-controller-role[0].name, "")
}

output "karpenter_controller_policy_arn" {
  description = "ARN of the Karpenter controller IAM policy"
  value       = try(aws_iam_policy.karpenter-controller-policy[0].arn, "")
}

output "karpenter_controller_policy_name" {
  description = "Name of the Karpenter controller IAM policy"
  value       = try(aws_iam_policy.karpenter-controller-policy[0].name, "")
}

#============================================================
# Karpenter Node Outputs
#============================================================
output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = try(aws_iam_role.karpenter-node-role[0].arn, "")
}

output "karpenter_node_role_name" {
  description = "Name of the Karpenter node IAM role"
  value       = try(aws_iam_role.karpenter-node-role[0].name, "")
}

output "karpenter_node_instance_profile_arn" {
  description = "ARN of the Karpenter node instance profile"
  value       = try(aws_iam_instance_profile.karpenter-node-profile[0].arn, "")
}

output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile"
  value       = try(aws_iam_instance_profile.karpenter-node-profile[0].name, "")
}

#============================================================
# Service Account IAM Outputs (for IRSA)
#============================================================
output "karpenter_service_account_iam" {
  description = "Map containing Karpenter service account IAM role information for IRSA"
  value = var.is_karpenter_enabled && var.is_eks_cluster_enabled && var.eks_oidc_url != "" ? {
    role_arn        = aws_iam_role.karpenter-controller-role[0].arn
    role_name       = aws_iam_role.karpenter-controller-role[0].name
    namespace       = var.karpenter_namespace
    service_account = var.karpenter_service_account
  } : {}
}

output "eks_oidc_service_account_iam" {
  description = "Map containing EKS OIDC service account IAM role information for IRSA"
  value = var.is_eks_cluster_enabled && var.eks_oidc_url != "" ? {
    role_arn        = try(aws_iam_role.eks_oidc_role[0].arn, "")
    role_name       = try(aws_iam_role.eks_oidc_role[0].name, "")
    namespace       = var.eks_oidc_namespace
    service_account = var.eks_oidc_service_account
  } : {}
}

#============================================================
# EBS CSI Driver Role Outputs
#============================================================
output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role for IRSA"
  value       = try(aws_iam_role.ebs-csi-driver-role[0].arn, "")
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = try(aws_iam_role.ebs-csi-driver-role[0].name, "")
}

#============================================================
# Random Suffix Output
#============================================================
output "random_suffix" {
  description = "Random suffix generated for resource naming"
  value       = random_integer.random_suffix.result
}
