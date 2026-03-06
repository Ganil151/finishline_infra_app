resource "aws_eks_cluster" "eks" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  name = var.cluster_name
  role_arn = var.cluster_role_arn
  version = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}