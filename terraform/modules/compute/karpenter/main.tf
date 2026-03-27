locals {
  tags = merge(var.computed_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}

#============================================================
#  Karpenter Helm Chart - Installs CRDs and Controller
#============================================================
resource "helm_release" "karpenter" {
  name      = "karpenter"
  chart     = "oci://public.ecr.aws/karpenter/karpenter"
  version   = "1.0.8"
  namespace = var.karpenter_namespace
  timeout   = 600

  set = [
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.karpenter_controller_role_arn
    },
    {
      name  = "settings.clusterName"
      value = var.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = var.cluster_endpoint
    },
    {
      name  = "replicas"
      value = "1"
    }
  ]

  set_sensitive = var.karpenter_interruption_queue_name != "" ? [
    {
      name  = "settings.interruptionQueue"
      value = var.karpenter_interruption_queue_name
    }
  ] : []

  lifecycle {
    ignore_changes = [version]
  }
}

#============================================================
#  EC2NodeClass - Defines EC2 configuration for Karpenter
#============================================================
resource "kubernetes_manifest" "karpenter_ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"

    metadata = {
      name = "default"
      labels = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }

    spec = {
      amiFamily = var.karpenter_ami_family
      role      = var.karpenter_node_role_name

      subnetSelectorTerms = [
        {
          tags = var.karpenter_subnet_tags
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = var.karpenter_security_group_tags
        }
      ]

      tags = {
        "karpenter.sh/discovery" = var.cluster_name
      }

      # Block device mapping for EBS
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize = var.karpenter_volume_size
            volumeType = "gp3"
            encrypted  = true
          }
        }
      ]

      # Metadata options for IMDSv2
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"
      }

      # Detailed monitoring (optional, costs extra)
      detailedMonitoring = var.karpenter_detailed_monitoring
    }
  }

  # Retry configuration for cluster connectivity issues
  timeouts {
    create = "10m"
  }

  depends_on = [
    helm_release.karpenter
  ]
}

#============================================================
#  NodePool - Defines node provisioning rules
#============================================================
resource "kubernetes_manifest" "karpenter_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"

    metadata = {
      name = "default"
      labels = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }

    spec = {
      template = {
        spec = {
          nodeClassRef = {
            name = "default"
          }

          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.karpenter_capacity_types
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.karpenter_instance_types
            }
          ]

          # Expire nodes after 720h (30 days) for cost optimization
          expireAfter = "720h"
        }
      }

      # Resource limits
      limits = {
        cpu = var.karpenter_max_cpu
      }

      # Disruption settings
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
      }

      # Weight for node pool selection (higher = preferred)
      weight = 100
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2_node_class
  ]
}
