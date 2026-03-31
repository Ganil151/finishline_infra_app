#============================================================
# OpenID Connect (OIDC) IAM ROLE DATA
#============================================================

# Assume role policy document for generic OIDC role
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  count = var.is_eks_cluster_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_url, "https://", "")}"]
      type        = "Federated"
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.eks_oidc_namespace}:${var.eks_oidc_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Assume role policy document for Karpenter Controller (IRSA)
data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  count = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_url, "https://", "")}"]
      type        = "Federated"
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.karpenter_namespace}:${var.karpenter_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Assume role policy document for Karpenter Node Role (EC2)
data "aws_iam_policy_document" "karpenter_node_assume_role_policy" {
  count = var.is_karpenter_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

# Current AWS account identity
data "aws_caller_identity" "current" {}
