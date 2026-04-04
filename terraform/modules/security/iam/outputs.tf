#========================================================================
#                        *** IAM Outputs ***
#========================================================================

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.name
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = var.is_eks_node_group_role_enabled ? aws_iam_role.eks_node_group_role[0].arn : null
}

output "eks_node_group_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = var.is_eks_node_group_role_enabled ? aws_iam_role.eks_node_group_role[0].name : null
}

output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = var.is_eks_oidc_provider_enabled ? aws_iam_openid_connect_provider.eks_oidc_provider[0].arn : null
}

output "eks_oidc_role_arn" {
  description = "ARN of the EKS OIDC IAM role"
  value       = var.is_eks_cluster_enabled && var.is_eks_oidc_provider_enabled ? aws_iam_role.eks_oidc_role[0].arn : null
}

output "eks_oidc_role_name" {
  description = "Name of the EKS OIDC IAM role"
  value       = var.is_eks_cluster_enabled && var.is_eks_oidc_provider_enabled ? aws_iam_role.eks_oidc_role[0].name : null
}

output "s3_oidc_policy_arn" {
  description = "ARN of the S3 OIDC IAM policy"
  value       = var.is_eks_cluster_enabled && var.is_eks_oidc_provider_enabled && var.s3_bucket_arn != "" ? aws_iam_policy.s3_oidc_policy[0].arn : null
}

output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? aws_iam_role.karpenter_controller_role[0].arn : null
}

output "karpenter_controller_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? aws_iam_role.karpenter_controller_role[0].name : null
}

output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = var.is_karpenter_enabled ? aws_iam_role.karpenter_node_role[0].arn : null
}

output "karpenter_node_role_name" {
  description = "Name of the Karpenter node IAM role"
  value       = var.is_karpenter_enabled ? aws_iam_role.karpenter_node_role[0].name : null
}

output "karpenter_instance_profile_name" {
  description = "Name of the Karpenter instance profile"
  value       = var.is_karpenter_enabled ? aws_iam_instance_profile.karpenter_node_profile[0].name : null
}

output "karpenter_instance_profile_arn" {
  description = "ARN of the Karpenter instance profile"
  value       = var.is_karpenter_enabled ? aws_iam_instance_profile.karpenter_node_profile[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.is_ebs_csi_driver_enabled && var.is_eks_cluster_enabled ? aws_iam_role.ebs_csi_driver_role[0].arn : null
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = var.is_ebs_csi_driver_enabled && var.is_eks_cluster_enabled ? aws_iam_role.ebs_csi_driver_role[0].name : null
}

output "jumphost_role_arn" {
  description = "ARN of the JumpHost IAM role"
  value       = aws_iam_role.jumphost_role.arn
}

output "jumphost_role_name" {
  description = "Name of the JumpHost IAM role"
  value       = aws_iam_role.jumphost_role.name
}

output "jumphost_instance_profile_name" {
  description = "Name of the JumpHost instance profile"
  value       = aws_iam_instance_profile.jumphost_profile.name
}

output "jumphost_instance_profile_arn" {
  description = "ARN of the JumpHost instance profile"
  value       = aws_iam_instance_profile.jumphost_profile.arn
}
