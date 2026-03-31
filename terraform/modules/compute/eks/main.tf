#============================================================
#               ***  EKS Cluster Resources  ***
#============================================================
resource "aws_eks_cluster" "eks" {
  count    = var.is_eks_cluster_enabled ? 1 : 0
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    subnet_ids              = var.subnets
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : ["0.0.0.0/0"]
    security_group_ids      = var.security_group_ids
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  dynamic "upgrade_policy" {
    for_each = var.enable_upgrade_policy ? [1] : []

    content {
      support_type = var.upgrade_policy_support_type
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
    ignore_changes = [version]
  }

  tags = local.tags

}

#============================================================
#  EKS Access Entry - For managing cluster access
#============================================================
resource "aws_eks_access_entry" "cluster_admins" {
  for_each = var.is_eks_cluster_enabled ? var.cluster_admin_principals : {}

  cluster_name      = aws_eks_cluster.eks[0].name
  principal_arn     = each.value
  kubernetes_groups = length(var.cluster_admin_kubernetes_groups) > 0 ? var.cluster_admin_kubernetes_groups : null

  tags = local.tags

}

resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each = var.is_eks_cluster_enabled ? var.cluster_admin_principals : {}

  cluster_name  = aws_eks_cluster.eks[0].name
  principal_arn = each.value
  policy_arn    = var.cluster_admin_policy_arn

  access_scope {
    type = "cluster"
  }

}

#============================================================
#  EKS Access Entry - For nodegroup role
#============================================================
resource "aws_eks_access_entry" "nodegroup" {
  count = var.is_eks_cluster_enabled && var.is_eks_nodegroup_enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.eks[0].name
  principal_arn = var.node_group_role_arn
  type          = "EC2_LINUX"

  tags = local.tags

}

