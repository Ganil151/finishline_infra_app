#========================================================================
#                        *** Random Suffixes ***
#========================================================================
resource "random_integer" "random_suffix" {
  min = 1000
  max = 9999
}
#========================================================================
#                      *** IAM ROLE EKS CLUSTER ***
#========================================================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-eks-cluster-role"
  })

}
#========================================================================
#                     *** IAM Data Policies Attachment ***
#========================================================================
resource "aws_iam_role_policy" "eks_cluster_role_policy" {
  role = aws_iam_role.eks_cluster_role.name
  name = "${var.project_name}-${var.environment}-eks-cluster-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
#========================================================================
#                      *** IAM NODE GROUP ROLE ***
#========================================================================
resource "aws_iam_role" "eks_node_group_role" {
  count = var.is_eks_node_group_role_enabled ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-eks-node-group-role"
  })

}
#========================================================================
#             *** IAM NodeGroup Role Policies Attachment ***
#========================================================================
resource "aws_iam_role_policy_attachment" "eks_node_group_role_policy_attachment" {
  for_each = var.is_eks_node_group_role_enabled ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]) : toset([])
  role       = aws_iam_role.eks_node_group_role[0].name
  policy_arn = each.value
}
#========================================================================
#             *** ProviderIAM OIDC (OpenID Connect) ***
#========================================================================
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  count           = var.is_eks_oidc_provider_enabled && var.eks_oidc_url != "" ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.eks_oidc_thumbprint]
  url             = var.eks_oidc_url

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-eks-oidc-provider"
  })
}
#========================================================================
#             *** IAM OIDC (OpenID Connect) ROLE ***
#========================================================================
resource "aws_iam_role" "eks_oidc_role" {
  count = var.is_eks_cluster_enabled && var.is_eks_oidc_provider_enabled ? 1 : 0
  name  = "${var.cluster_name}-oidc-role${random_integer.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks_oidc_provider[0].url, "https://", "")}:sub" = var.eks_oidc_subject
            "${replace(aws_iam_openid_connect_provider.eks_oidc_provider[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-oidc-role"
  })

}
#========================================================================
#             *** S3 OIDC (OpenID Connect) Policy ***
#========================================================================
resource "aws_iam_policy" "s3_oidc_policy" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  name  = "${var.cluster_name}-s3-oidc-policy${random_integer.random_suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = var.s3_prefix == "*" ? "*" : (var.s3_prefix != "" ? "${var.s3_bucket_arn}/${var.s3_prefix}/*" : "${var.s3_bucket_arn}/*")
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${random_integer.random_suffix.result}-s3-oidc-policy"
  })

}

#========================================================================
#          *** S3 OIDC (OpenID Connect) Policy Attachment ***
#========================================================================
resource "aws_iam_role_policy_attachment" "s3_oidc_policy_attachment" {
  count      = var.is_eks_cluster_enabled && var.is_eks_oidc_provider_enabled && var.s3_bucket_arn != "" ? 1 : 0
  role       = aws_iam_role.eks_oidc_role[0].name
  policy_arn = aws_iam_policy.s3_oidc_policy[0].arn

  depends_on = [aws_iam_role.eks_oidc_role]
}
#========================================================================
#                  *** KARPENTER CONTROLLER ROLE ***
#========================================================================
resource "aws_iam_role" "karpenter_controller_role" {
  count              = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? 1 : 0
  name               = "${var.karpenter_cluster_name}-karpenter-controller-role${random_integer.random_suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy[0].json

  tags = merge(var.common_tags, {
    "karpenter.sh/discovery" = "${var.project_name}-${var.environment}-${var.karpenter_cluster_name}"
  })
}
#============================================================
#  KARPENTER CONTROLLER POLICY
#============================================================
resource "aws_iam_policy" "karpenter_controller_policy" {
  count = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? 1 : 0

  name        = "${var.karpenter_cluster_name}-karpenter-controller-policy${var.name_suffix}"
  description = "IAM policy for Karpenter controller to provision EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2InstanceOperations"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeImages",
          "ec2:DescribeCapacityReservations"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2Tagging"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:network-interface/*",
          "arn:aws:ec2:*:*:launch-template/*",
          "arn:aws:ec2:*:*:spot-instances-request/*"
        ]
      },
      {
        Sid    = "AllowEC2Termination"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/discovery" = "${var.project_name}-${var.environment}-${var.karpenter_cluster_name}"
          }
        }
      },
      {
        Sid    = "AllowIAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.is_eks_node_group_role_enabled ? [
          aws_iam_role.eks_node_group_role[0].arn,
          try(aws_iam_role.karpenter_node_role[0].arn, "*")
          ] : [
          try(aws_iam_role.karpenter_node_role[0].arn, "*")
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowSSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/aws/service/*"
      },
      {
        Sid    = "AllowPricingDataAccess"
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = "arn:aws:eks:*:*:cluster/${var.karpenter_cluster_name}"
      },
      {
        Sid    = "AllowInstanceProfileOperations"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile"
        ]
        Resource = var.karpenter_node_instance_profile_name != "" ? "arn:aws:iam::*:instance-profile/${var.karpenter_node_instance_profile_name}" : "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.karpenter_cluster_name}-karpenter-controller-policy${var.name_suffix}"
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy_attachment" {
  count = var.is_karpenter_enabled && var.is_eks_cluster_enabled ? 1 : 0

  policy_arn = aws_iam_policy.karpenter_controller_policy[0].arn
  role       = aws_iam_role.karpenter_controller_role[0].name
}

#============================================================
#  KARPENTER NODE ROLE
#============================================================
resource "aws_iam_role" "karpenter_node_role" {
  count = var.is_karpenter_enabled ? 1 : 0

  name               = "${var.karpenter_cluster_name}-karpenter-node-role${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role_policy[0].json

  tags = merge(var.common_tags, {
    "karpenter.sh/discovery" = "${var.project_name}-${var.environment}-${var.karpenter_cluster_name}"
  })
}

#============================================================
#  KARPENTER NODE ROLE POLICIES ATTACHMENT
#============================================================
resource "aws_iam_role_policy_attachment" "karpenter_node_policies" {
  for_each = var.is_karpenter_enabled ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]) : toset([])

  policy_arn = each.value
  role       = aws_iam_role.karpenter_node_role[0].name
}

#============================================================
#  KARPENTER NODE INSTANCE PROFILE
#============================================================
resource "aws_iam_instance_profile" "karpenter_node_profile" {
  count = var.is_karpenter_enabled ? 1 : 0

  name = "${var.karpenter_cluster_name}-karpenter-node-profile${var.name_suffix}"
  role = aws_iam_role.karpenter_node_role[0].name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.karpenter_cluster_name}-karpenter-node-profile${var.name_suffix}"
  })
}

#============================================================
#  EBS CSI DRIVER IAM ROLE (for IRSA)
#============================================================
data "aws_iam_policy_document" "ebs_csi_driver_assume_role_policy" {
  count = var.is_ebs_csi_driver_enabled && var.is_eks_cluster_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_url, "https://", "")}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.ebs_csi_driver_namespace}:${var.ebs_csi_driver_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver_role" {
  count = var.is_ebs_csi_driver_enabled && var.is_eks_cluster_enabled ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-driver-role${var.name_suffix}"
  assume_role_policy = try(data.aws_iam_policy_document.ebs_csi_driver_assume_role_policy[0].json, null)

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-ebs-csi-driver-role"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy_attachment" {
  count = var.is_ebs_csi_driver_enabled && var.is_eks_cluster_enabled ? 1 : 0

  role       = aws_iam_role.ebs_csi_driver_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
#============================================================
#  JUMPHOST IAM ROLE
#============================================================
resource "aws_iam_role" "jumphost_role" {
  name = "${var.project_name}-${var.environment}-jumphost-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-jumphost-role"
  })
}

resource "aws_iam_role_policy_attachment" "jumphost_ssm" {
  role       = aws_iam_role.jumphost_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#============================================================
#  JUMPHOST EKS ACCESS POLICY
#============================================================
resource "aws_iam_role_policy" "jumphost_eks_policy" {
  name = "${var.project_name}-${var.environment}-jumphost-eks-policy"
  role = aws_iam_role.jumphost_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-eks-cluster-role"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jumphost_profile" {
  name = "${var.project_name}-${var.environment}-jumphost-profile"
  role = aws_iam_role.jumphost_role.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-jumphost-profile"
  })
}
