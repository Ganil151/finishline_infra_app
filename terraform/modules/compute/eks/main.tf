#========================================================================
#                      *** EKS Main Configuration ***
#========================================================================

#________________________________________________________________________
#                     EKS CLUSTER Configuration
#________________________________________________________________________
resource "aws_eks_cluster" "eks" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  name = var.cluster_name 
  role_arn = var.eks_cluster_role_arn
  version = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    subnet_ids = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access = var.endpoint_public_access
    public_access_cidrs = length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : ["0.0.0.0/0"]
    security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : []
  }

  access_config {
    authentication_mode = var.authentication_mode != "" ? var.authentication_mode : "API"
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  dynamic "upgrade_policy" {
    for_each = var.enable_upgrade_policy ? [1] : []
    content {
      support_type = var.upgrade_support_type != "" ? var.upgrade_support_type : "STANDARD"      
    }
  }

  compute_config {
    enabled = false    
  }

  storage_config {
    block_storage {
      enabled = false
    }    
  }

  lifecycle {
    ignore_changes = [
      version,
      enabled_cluster_log_types,
      
    ]
  }

  tags = local.tags

}

#________________________________________________________________________
#                     EKS ACCESS ENTRY Configuration
#________________________________________________________________________
resource "aws_eks_access_entry" "cluster_admins" {
  for_each = var.is_eks_cluster_enabled ? toset(var.cluster_principal) : []
  cluster_name = aws_eks_cluster.eks[0].name
  principal_arn = each.value
  kubernetes_groups = length(var.cluster_admin_kubernetes_groups) > 0 ? var.cluster_admin_kubernetes_groups : ["system:masters"]

  type = "STANDARD"
  tags = local.tags
}
#________________________________________________________________________
#                 EKS ACCESS POLICY BINDING Configuration
#________________________________________________________________________
resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each = var.is_eks_cluster_enabled ? toset(var.cluster_admin_principal) : []
  cluster_name = aws_eks_cluster.eks[0].name
  principal_arn = each.value
  policy_arn = var.cluster_admin_policy_arn

  access_scope {
    type = "cluster"
  }
}
#________________________________________________________________________
#                   EKS ACCESS ENTRY NODEGROUP Configuration
#________________________________________________________________________
resource "aws_eks_access_entry" "nodegroup_admins" {
  for_each = var.is_eks_cluster_enabled && var.is_nodegroup_enabled ? toset(var.nodegroup_principal) : []
  cluster_name = aws_eks_cluster.eks[0].name
  principal_arn = each.value
  type = "EC2_LINUX"
  kubernetes_groups = length(var.nodegroup_admin_kubernetes_groups) > 0 ? var.nodegroup_admin_kubernetes_groups : ["system:bootstrappers", "system:nodes"]

  tags = local.tags
}

