#========================================================================
#                      *** EKS Addons Configuration ***
#========================================================================

#______________________VPC CNI Configuration______________________
resource "aws_eks_addon" "vpc_cni" {
  count = var.is_eks_cluster_enabled ? 1 : 0 
  cluster_name                = aws_eks_cluster.eks[0].name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = var.node_group_create_timeout != "" ? var.node_group_create_timeout : "30m"
    update = var.node_group_update_timeout != "" ? var.node_group_update_timeout : "30m"
    delete = var.node_group_delete_timeout != "" ? var.node_group_delete_timeout : "30m"
  }

  tags       = merge(local.tags, { Name = "${var.cluster_name}-${var.environment}-vpc-cni" })
  depends_on = [aws_eks_cluster.eks]
}

#______________________CoreDNS Configuration______________________
resource "aws_eks_addon" "coredns" {
  count = var.is_eks_cluster_enabled ? 1 : 0 
  cluster_name                = aws_eks_cluster.eks[0].name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = var.node_group_create_timeout != "" ? var.node_group_create_timeout : "30m"
    update = var.node_group_update_timeout != "" ? var.node_group_update_timeout : "30m"
    delete = var.node_group_delete_timeout != "" ? var.node_group_delete_timeout : "30m"
  }

  tags       = merge(local.tags, { Name = "${var.cluster_name}-${var.environment}-coredns" })
  depends_on = [aws_eks_addon.vpc_cni, aws_eks_node_group.nodegroup[0]]
}

#______________________Kube-Proxy Configuration______________________
resource "aws_eks_addon" "kube_proxy" {
  count = var.is_eks_cluster_enabled ? 1 : 0 
  cluster_name                = aws_eks_cluster.eks[0].name
  addon_name                  = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = var.node_group_create_timeout != "" ? var.node_group_create_timeout : "30m"
    update = var.node_group_update_timeout != "" ? var.node_group_update_timeout : "30m"
    delete = var.node_group_delete_timeout != "" ? var.node_group_delete_timeout : "30m"
  }

  tags       = merge(local.tags, { Name = "${var.cluster_name}-${var.environment}-kube-proxy" })
  depends_on = [aws_eks_cluster.eks]
}

#______________________EBS CSI Driver Configuration______________________
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.is_eks_cluster_enabled ? 1 : 0 
  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = var.ebs_csi_driver_role_arn

  timeouts {
    create = var.node_group_create_timeout != "" ? var.node_group_create_timeout : "30m"
    update = var.node_group_update_timeout != "" ? var.node_group_update_timeout : "30m"
    delete = var.node_group_delete_timeout != "" ? var.node_group_delete_timeout : "30m"
  }

  tags       = merge(local.tags, { Name = "${var.cluster_name}-${var.environment}-ebs-csi-driver" })
  depends_on = [aws_eks_node_group.nodegroup[0]]
}
#______________________EKS NODEGROUP Configuration______________________
resource "aws_eks_node_group" "nodegroup" {
  count        = var.is_eks_cluster_enabled && var.is_nodegroup_enabled ? 1 : 0
  cluster_name = aws_eks_cluster.eks[0].name
  node_group_name = var.node_group_name
  node_role_arn = var.node_role_arn
  subnet_ids = var.node_group_subnets

  ami_type       = var.node_group_ami_type
  instance_types = var.node_group_instance_types
  capacity_type  = var.node_group_capacity_type

  scaling_config {
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
    desired_size = var.node_group_desired_size
  }
  
  dynamic "launch_template" {
    for_each = var.node_group_launch_template_id != "" ? [var.node_group_launch_template_id] : []

    content {
      id      = var.node_group_launch_template_id
      version = var.launch_template_version
    }
  }

  dynamic "update_config" {
    for_each = var.node_group_update_config_max_unavailable != null || var.node_group_update_config_max_unavailable_percentage != null ? [1] : []

    content {
      max_unavailable            = var.node_group_update_config_max_unavailable
      max_unavailable_percentage = var.node_group_update_config_max_unavailable_percentage
    }
  }

  timeouts {
    create = var.node_group_create_timeout != "" ? var.node_group_create_timeout : "30m"
    update = var.node_group_update_timeout != "" ? var.node_group_update_timeout : "30m"
    delete = var.node_group_delete_timeout != "" ? var.node_group_delete_timeout : "30m"
  }

  tags = merge(local.node_group_tags, { Name = "${var.cluster_name}-${var.environment}-nodegroup" })
}