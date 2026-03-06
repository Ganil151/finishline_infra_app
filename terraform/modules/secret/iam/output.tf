#######################
# EKS Cluster Role Outputs
#######################
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = var.is_eks_role_enabled ? aws_iam_role.eks-cluster-role[0].arn : null
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = var.is_eks_role_enabled ? aws_iam_role.eks-cluster-role[0].name : null
}

#######################
# EKS Node Group Role Outputs
#######################
output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = var.is_eks_nodegroup_role_enabled ? aws_iam_role.eks-nodegroup-role[0].arn : null
}

output "eks_nodegroup_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = var.is_eks_nodegroup_role_enabled ? aws_iam_role.eks-nodegroup-role[0].name : null
}

#######################
# OIDC Role & Policy Outputs
#######################
output "eks_oidc_role_arn" {
  description = "ARN of the EKS OIDC IAM role"
  value       = var.is_eks_cluster_enabled ? aws_iam_role.eks_oidc[0].arn : null
}

output "eks_oidc_role_name" {
  description = "Name of the EKS OIDC IAM role"
  value       = var.is_eks_cluster_enabled ? aws_iam_role.eks_oidc[0].name : null
}

output "eks_oidc_policy_arn" {
  description = "ARN of the EKS OIDC IAM policy"
  value       = var.is_eks_cluster_enabled ? aws_iam_policy.eks-oidc-policy[0].arn : null
}

output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC identity provider"
  value       = var.is_eks_cluster_enabled ? aws_iam_openid_connect_provider.eks-oidc-provider[0].arn : null
}

output "eks_oidc_provider_url" {
  description = "URL of the EKS OIDC identity provider"
  value       = var.is_eks_cluster_enabled ? aws_iam_openid_connect_provider.eks-oidc-provider[0].url : null
}
