#============================================================
#  EKS Addons - Core Kubernetes Components
#============================================================
resource "aws_eks_addon" "vpc_cni" {
  count = var.is_eks_cluster_enabled ? 1 : 0

  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = local.tags
}

resource "aws_eks_addon" "coredns" {
  count = var.is_eks_cluster_enabled ? 1 : 0

  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = local.tags

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_node_group.nodegroup
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.is_eks_cluster_enabled ? 1 : 0

  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = local.tags
}

# Note: aws-ebs-csi-driver addon is only created when IRSA is configured
# (i.e., when ebs_csi_driver_role_arn is provided)
resource "aws_eks_addon" "aws_ebs_csi_driver" {
  count = var.is_eks_cluster_enabled && var.is_ebs_csi_driver_enabled ? 1 : 0

  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = var.ebs_csi_driver_role_arn

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    aws_eks_node_group.nodegroup
  ]
  tags = local.tags
}

#============================================================
#  EKS Node Group
#============================================================
resource "aws_eks_node_group" "nodegroup" {
  count = var.is_eks_nodegroup_enabled ? 1 : 0

  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.node_group_subnets

  # Launch template takes precedence - when specified, omit conflicting parameters
  dynamic "launch_template" {
    for_each = var.node_group_launch_template_id != "" ? [var.node_group_launch_template_id] : []

    content {
      id      = launch_template.value
      version = var.node_group_launch_template_version
    }
  }

  # Only set these if NOT using a launch template
  ami_type       = var.node_group_launch_template_id == "" ? var.node_group_ami_type : null
  instance_types = var.node_group_launch_template_id == "" ? var.node_group_instance_types : null
  disk_size      = var.node_group_launch_template_id == "" ? var.node_group_disk_size : null
  capacity_type  = var.node_group_launch_template_id == "" ? var.node_group_capacity_type : null

  scaling_config {
    desired_size = var.node_group_scaling_config != null ? var.node_group_scaling_config.desired_size : 1
    min_size     = var.node_group_scaling_config != null ? var.node_group_scaling_config.min_size : 1
    max_size     = var.node_group_scaling_config != null ? var.node_group_scaling_config.max_size : 1
  }

  dynamic "update_config" {
    for_each = var.node_group_update_config != null ? [var.node_group_update_config] : []

    content {
      max_unavailable = update_config.value.max_unavailable
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [labels, taint]
  }

  timeouts {
    create = var.node_group_timeouts.create
    update = var.node_group_timeouts.update
    delete = var.node_group_timeouts.delete
  }

  labels = var.node_group_labels

  tags = merge(local.tags, var.node_group_tags, {
    Name = "${var.node_group_name}-node"
  })

  depends_on = [
    aws_eks_cluster.eks
  ]

}
