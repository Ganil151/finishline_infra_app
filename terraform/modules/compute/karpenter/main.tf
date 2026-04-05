#========================================================================
#                      *** KARPENTER Configuration ***
#========================================================================
locals {
  tags = merge(var.common_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}
#________________________________________________________________________
#                     KARPENTER CRDs Configuration
#________________________________________________________________________

resource "kubectl_manifest" "karpenter_crds" {
  for_each = toset([
    "${path.module}/../../../scripts/karpenter/karpenter-crds.yaml",
    "${path.module}/../../../scripts/karpenter/karpenter-crds-nodepool.yaml",
    "${path.module}/../../../scripts/karpenter/karpenter-nodeclaim.yaml",
  ])
  yaml_body = file(each.value)
}

#________________________________________________________________________
#                     KARPENTER EC2NodeClass Configuration
#________________________________________________________________________

resource "kubectl_manifest" "karpenter_ec2_node_class" {
  yaml_body = templatefile("${path.module}/../../../scripts/karpenter/karpenter-ec2-node-class.yaml", {
    cluster_name                  = var.cluster_name
    karpenter_ami_family          = var.karpenter_ami_family
    karpenter_node_role           = var.karpenter_node_role_name
    karpenter_subnet_tags         = { "karpenter.sh/discovery" = var.cluster_name }
    karpenter_security_group_tags = { "karpenter.sh/discovery" = var.cluster_name }
    karpenter_volume_size         = var.karpenter_volume_size
    karpenter_volume_type         = "gp3"
    karpenter_detailed_monitoring = false
  })
  depends_on = [
    kubectl_manifest.karpenter_crds,
  ]
}

#________________________________________________________________________
#                     KARPENTER NodePool Configuration
#________________________________________________________________________

resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = templatefile("${path.module}/../../../scripts/karpenter/karpenter-nodepool.yaml", {
    cluster_name             = var.cluster_name
    karpenter_capacity_types = var.karpenter_capacity_types
    karpenter_instance_types = var.karpenter_instance_types
    karpenter_max_cpu        = var.karpenter_max_cpu
  })
  depends_on = [
    kubectl_manifest.karpenter_crds,
    kubectl_manifest.karpenter_ec2_node_class,
  ]
}

#________________________________________________________________________
#                     KARPENTER Helm Chart Configuration
#________________________________________________________________________

resource "helm_release" "karpenter" {
  name             = "karpenter"
  chart            = "oci://public.ecr.aws/karpenter/karpenter"
  namespace        = var.karpenter_namespace
  version          = "1.3.3"
  timeout          = 600
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  force_update     = true
  skip_crds        = true

  set {
    name  = "serviceAccount.name"
    value = "karpenter"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.karpenter_controller_role_arn
  }

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "settings.awsRegion"
    value = var.aws_region
  }

  dynamic "set_sensitive" {
    for_each = var.karpenter_interruption_queue_name != "" ? [var.karpenter_interruption_queue_name] : []
    content {
      name  = "settings.interruptionQueue"
      value = set_sensitive.value
    }
  }

  lifecycle {
    ignore_changes = [
      version
    ]
  }

  depends_on = [
    kubectl_manifest.karpenter_crds,
    kubectl_manifest.karpenter_ec2_node_class,
    kubectl_manifest.karpenter_nodepool,
  ]
}
