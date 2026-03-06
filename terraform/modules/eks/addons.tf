resource "aws_eks_addon" "eks-addons" {
  for_each = var.is_eks_addons_enabled ? { for k, v in var.addons : k => v } : {}

  cluster_name                = aws_eks_cluster.eks[0].name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Optional: attach an IRSA role if provided per addon
  service_account_role_arn = lookup(each.value, "service_account_role_arn", null)

  depends_on = [
    aws_eks_node_group.ondemand-node,
    aws_eks_node_group.spot-node,
  ]
}
