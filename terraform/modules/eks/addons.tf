resource "aws_eks_addon" "eks-addons" {
  for_each = var.is_eks_addons_enabled ? { for k, v in var.addons : k => v } : {}

  cluster_name                = aws_eks_cluster.eks[0].name
  addon_name                  = each.key
  addon_version               = each.value.version != "" ? each.value.version : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Optional: attach an IRSA role if provided per addon
  service_account_role_arn = lookup(each.value, "service_account_role_arn", null)

  tags = {
    Name        = "${var.cluster_name}-${each.key}-addon"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Terraform   = "true"
  }

  lifecycle {
    # Ignore changes to version to allow AWS to manage addon updates
    ignore_changes = [addon_version]
  }

  depends_on = [
    aws_eks_node_group.ondemand-node,
    aws_eks_node_group.spot-node,
  ]
}
