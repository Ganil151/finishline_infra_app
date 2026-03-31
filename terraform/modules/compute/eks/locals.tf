locals {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${var.cluster_name}"
    Module  = "eks"
    Cluster = var.cluster_name
  })

  node_group_tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}
