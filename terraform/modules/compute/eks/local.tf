#========================================================================
#                      *** EKS Local Configuration ***
#========================================================================
locals {
  cluster_name = var.cluster_name
  cluster_version = var.cluster_version
  node_group_name = var.node_group_name

  tags = {
    Name = "${var.cluster_name}-${var.environment}-eks"
    Reporter = "Ganil Batist Yan"
  }

  node_group_tags = {
    Name = "${var.cluster_name}-${var.environment}-eks-nodegroup"
    Reporter = "Ganil Batist Yan"
  }
}