#========================================================================
#                        *** EKS Outputs ***
#========================================================================

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].name : null
}

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].id : null
}

output "cluster_endpoint" {
  description = "The endpoint for your Kubernetes API server"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].endpoint : null
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].certificate_authority[0].data : null
}

output "node_group_id" {
  description = "EKS Cluster name and EKS Node Group name separated by a colon"
  value       = var.is_nodegroup_enabled ? aws_eks_node_group.nodegroup[0].id : null
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = var.is_nodegroup_enabled ? aws_eks_node_group.nodegroup[0].arn : null
}
