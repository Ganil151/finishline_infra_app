##############################################
# EKS Cluster Outputs
##############################################
output "cluster_id" {
  description = "The name/ID of the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].id : null
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].arn : null
}

output "cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster API server"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].endpoint : null
}

output "cluster_version" {
  description = "The Kubernetes version running on the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].version : null
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].certificate_authority[0].data : null
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "The cluster-managed security group ID created by EKS"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].vpc_config[0].cluster_security_group_id : null
}

##############################################
# OIDC Provider Outputs
##############################################
output "cluster_oidc_issuer" {
  description = "The OIDC issuer URL for the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].identity[0].oidc[0].issuer : null
}

output "cluster_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC identity provider for the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_iam_openid_connect_provider.eks_oidc_provider[0].arn : null
}

##############################################
# Node Group Outputs
##############################################
output "ondemand_node_group_id" {
  description = "The ID of the on-demand node group"
  value       = var.is_eks_node_group_enabled ? aws_eks_node_group.ondemand-node[0].id : null
}

output "ondemand_node_group_arn" {
  description = "The ARN of the on-demand node group"
  value       = var.is_eks_node_group_enabled ? aws_eks_node_group.ondemand-node[0].arn : null
}

output "spot_node_group_id" {
  description = "The ID of the spot node group"
  value       = var.is_eks_node_group_enabled ? aws_eks_node_group.spot-node[0].id : null
}

output "spot_node_group_arn" {
  description = "The ARN of the spot node group"
  value       = var.is_eks_node_group_enabled ? aws_eks_node_group.spot-node[0].arn : null
}
