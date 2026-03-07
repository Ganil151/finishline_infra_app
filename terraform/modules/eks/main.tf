##############################################
# Data Source: TLS Certificate for OIDC
##############################################
data "tls_certificate" "eks_cert" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  url   = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
}

##############################################
# EKS Cluster
##############################################
resource "aws_eks_cluster" "eks" {
  count    = var.is_eks_cluster_enabled ? 1 : 0
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = var.security_group_ids
  }

  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Explicitly disable EKS Auto Mode — using managed node groups instead.
  # Required with AWS provider ≥ 6.x which may default to Auto Mode.
  compute_config {
    enabled = false
  }

  storage_config {
    block_storage {
      enabled = false
    }
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = false
    }
  }

  tags = {
    Name        = var.cluster_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Terraform   = "true"
  }
}

##############################################
# OIDC Identity Provider
##############################################
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  count           = var.is_eks_cluster_enabled ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cert[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Terraform   = "true"
  }

  lifecycle {
    # Ignore changes to allow re-running without destroying the existing provider
    ignore_changes = [thumbprint_list]
  }

  depends_on = [aws_eks_cluster.eks]
}

##############################################
# On-Demand Node Group
##############################################
resource "aws_eks_node_group" "ondemand-node" {
  count           = (var.is_eks_cluster_enabled && var.is_eks_node_group_enabled) ? 1 : 0
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-ondemand-nodes"
  node_role_arn   = var.node_role_arn

  scaling_config {
    desired_size = var.desired_capacity_on_demand
    min_size     = var.min_capacity_on_demand
    max_size     = var.max_capacity_on_demand
  }

  subnet_ids     = var.subnet_ids
  instance_types = var.ondemand_instance_types
  capacity_type  = "ON_DEMAND"

  labels = {
    type = "ondemand"
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name                                        = "${var.cluster_name}-ondemand-nodes"
    Project                                     = var.project_name
    Environment                                 = var.environment
    ManagedBy                                   = var.manage_by
    Terraform                                   = "true"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [aws_eks_cluster.eks]
}

##############################################
# Spot Node Group
##############################################
resource "aws_eks_node_group" "spot-node" {
  count           = (var.is_eks_cluster_enabled && var.is_eks_node_group_enabled) ? 1 : 0
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-spot-nodes"
  node_role_arn   = var.node_role_arn

  scaling_config {
    desired_size = var.desired_capacity_spot
    min_size     = var.min_capacity_spot
    max_size     = var.max_capacity_spot
  }

  subnet_ids     = var.subnet_ids
  instance_types = var.spot_instance_types
  capacity_type  = "SPOT"

  update_config {
    max_unavailable = 1
  }

  labels = {
    type      = "spot"
    lifecycle = "spot"
  }

  disk_size = 30

  tags = {
    Name                                        = "${var.cluster_name}-spot-nodes"
    Project                                     = var.project_name
    Environment                                 = var.environment
    ManagedBy                                   = var.manage_by
    Terraform                                   = "true"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [aws_eks_cluster.eks]
}
