#============================================================
#  EKS Cluster Outputs
#============================================================
output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].id, "")
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].name, "")
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].arn, "")
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server (use this for private access)"
  value       = try(aws_eks_cluster.eks[0].endpoint, "")
}

output "cluster_public_endpoint" {
  description = "Public endpoint for the EKS cluster API server (use this for external access when public_access is enabled)"
  value       = try(aws_eks_cluster.eks[0].endpoint, "")
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].certificate_authority[0].data, "")
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].version, "")
}

output "cluster_platform_version" {
  description = "Platform version of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].platform_version, "")
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].status, "")
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = try(aws_eks_cluster.eks[0].identity[0].oidc[0].issuer, "")
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = var.is_eks_cluster_enabled ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.eks[0].identity[0].oidc[0].issuer, "https://", "")}" : ""
}

#============================================================
#  EKS Node Group Outputs
#============================================================
output "node_group_id" {
  description = "ID of the EKS node group"
  value       = try(aws_eks_node_group.nodegroup[0].id, "")
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = try(aws_eks_node_group.nodegroup[0].node_group_name, "")
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = try(aws_eks_node_group.nodegroup[0].arn, "")
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = try(aws_eks_node_group.nodegroup[0].status, "")
}

output "node_group_resources" {
  description = "List of Auto Scaling Group ARNs for the EKS node group"
  value       = try(aws_eks_node_group.nodegroup[0].resources[0].autoscaling_groups, [])
}

#============================================================
#  Data Source Outputs
#============================================================
output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
