output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = module.iam.eks_nodegroup_role_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.main_vpc_id
}
