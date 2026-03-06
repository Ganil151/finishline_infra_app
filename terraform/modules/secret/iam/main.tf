#######################
# Local Variables & Utilities
#######################
locals {
  cluster_name = var.cluster_name
}

resource "random_integer" "random_suffix" {
  min = 1000
  max = 9999
}

#######################
# 1. EKS Cluster Role
# (Independent - Needed for Cluster Creation)
#######################
resource "aws_iam_role" "eks-cluster-role" {
  count = var.is_eks_role_enabled ? 1 : 0
  name  = "${local.cluster_name}-cluster-role-${random_integer.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  count      = var.is_eks_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role[0].name
}

#######################
# 2. EKS Node Group Role
#######################
resource "aws_iam_role" "eks-nodegroup-role" {
  count = var.is_eks_nodegroup_role_enabled ? 1 : 0
  name  = "${local.cluster_name}-nodegroup-role-${random_integer.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node-policies" {
  for_each = var.is_eks_nodegroup_role_enabled ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]) : []

  policy_arn = each.value
  role       = aws_iam_role.eks-nodegroup-role[0].name
}

#######################
# 3. OIDC Provider
# (Created AFTER Cluster is up)
#######################
resource "aws_iam_openid_connect_provider" "eks-oidc-provider" {
  count           = var.is_eks_cluster_enabled ? 1 : 0
  url             = var.eks_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.oidc_thumbprint
}

#######################
# 4. OIDC IAM Role 
# (Created AFTER Cluster is up)
#######################
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  # We use count 0/1 here to prevent evaluation errors if cluster is off
  count = var.is_eks_cluster_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks-oidc-provider[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks-oidc-provider[0].arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_oidc" {
  count              = var.is_eks_cluster_enabled ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_role_policy[0].json
  name               = "${local.cluster_name}-oidc-role"
}

resource "aws_iam_policy" "eks-oidc-policy" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  name  = "${local.cluster_name}-oidc-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowListBuckets"
        Action   = ["s3:ListAllMyBuckets"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid      = "AllowBucketLevelAccess"
        Action   = ["s3:GetBucketLocation"]
        Effect   = "Allow"
        Resource = var.s3_bucket_arn != "" ? "arn:aws:s3:::${var.s3_bucket_arn}" : "arn:aws:s3:::*"
      },
      {
        Sid      = "AllowObjectAccess"
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = var.s3_bucket_arn != "" ? "arn:aws:s3:::${var.s3_bucket_arn}/*" : "arn:aws:s3:::*/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-oidc-policy-attach" {
  count      = var.is_eks_cluster_enabled ? 1 : 0
  role       = aws_iam_role.eks_oidc[0].name
  policy_arn = aws_iam_policy.eks-oidc-policy[0].arn
}
