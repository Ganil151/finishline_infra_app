# ===========================================================
#               ***   Networking Outputs   ***
# ===========================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets_ids
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets_ids
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = module.sg.security_group_id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.alb.alb_dns_name
}

# ===========================================================
#               ***   Compute Outputs   ***
# ===========================================================

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "jumphost_public_ip" {
  description = "Public IP of the jumphost"
  value       = module.jumphost.public_ip
}

# ===========================================================
#               ***   Security Outputs   ***
# ===========================================================

output "iam_eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.iam.eks_cluster_role_arn
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = module.key_pair.key_name
}
