# ===========================================================
#               ***   Terraform Configuration   ***
# ===========================================================
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

locals {
  tags = merge(var.common_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}

#============================================================
#  Karpenter CRDs - Install using kubectl_manifest (no plan-time validation)
#============================================================
# CRD: EC2NodeClass
resource "kubectl_manifest" "karpenter_crds" {
  yaml_body = <<YAML
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ec2nodeclasses.karpenter.k8s.aws
  labels:
    app.kubernetes.io/part-of: karpenter
spec:
  role: "KarpenterNodeRole-finishline-infra-node"
  amiFamily: Bottlerocket
  amiSelectorTerms:
    - alias: bottlerocket@latest
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: "finishline-infra-node"
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "finishline-infra-node"
  tags:
    Name: "karpenter-node-finishline-infra-app
    Project: "finishline-infra-app"
  group: karpenter.k8s.aws  
  names:
    kind: EC2NodeClass
    listKind: EC2NodeClassList
    plural: ec2nodeclasses
    singular: ec2nodeclass
  scope: Cluster
  versions:
    - name: v1
      served: true
      storage: true
      subresources:
        status: {}
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML
depends_on = [ kubectl_manifest.karpenter_crds ]
}

# CRD: NodePool
resource "kubectl_manifest" "karpenter_crds_nodepool" {
  yaml_body = <<YAML
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nodepools.karpenter.sh
  labels:
    app.kubernetes.io/part-of: karpenter
spec:
  group: karpenter.sh
  names:
    kind: NodePool
    listKind: NodePoolList
    plural: nodepools
    singular: nodepool
  scope: Cluster
  versions:
    - name: v1
      served: true
      storage: true
      subresources:
        status: {}
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML

  depends_on = [kubectl_manifest.karpenter_crds]
}

# CRD: NodeClaim
resource "kubectl_manifest" "karpenter_crds_nodeclaim" {
  yaml_body = <<YAML
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: nodeclaims.karpenter.sh
  labels:
    app.kubernetes.io/part-of: karpenter
spec:
  group: karpenter.sh
  names:
    kind: NodeClaim
    listKind: NodeClaimList
    plural: nodeclaims
    singular: nodeclaim
  scope: Cluster
  versions:
    - name: v1
      served: true
      storage: true
      subresources:
        status: {}
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML

  depends_on = [kubectl_manifest.karpenter_crds_nodepool]
}

#============================================================
#  Karpenter Helm Chart - Installs Controller
#============================================================
resource "helm_release" "karpenter" {
  name      = "karpenter"
  chart     = "oci://public.ecr.aws/karpenter/karpenter"
  version   = "1.0.8"
  namespace = var.karpenter_namespace
  timeout   = 600

  # PROFESSOR'S MANDATE: Create namespace if it doesn't exist
  create_namespace = true

  # Wait for all resources to be ready
  wait = true

  # Wait for Kubernetes jobs to complete
  wait_for_jobs = true

  # Force upgrade to ensure CRDs are updated
  force_update = true

  # Skip CRD installation since we install them separately
  skip_crds = true

  # IRSA Configuration - Annotate service account with IAM role
  set = [
    {
      name  = "serviceAccount.name"
      value = "karpenter"
    },
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

  depends_on = [
    kubectl_manifest.karpenter_crds,
    kubectl_manifest.karpenter_crds_nodepool,
    kubectl_manifest.karpenter_crds_nodeclaim
  ]
}

#============================================================
#  Time Delay Gate - CRD Registration Buffer
#============================================================
resource "time_sleep" "wait_for_karpenter_crds" {
  create_duration = "60s"

  depends_on = [helm_release.karpenter]
}

#============================================================
#  EC2NodeClass - Defines EC2 configuration for Karpenter
#============================================================
resource "kubectl_manifest" "karpenter_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
  labels:
    karpenter.sh/discovery: ${var.cluster_name}
spec:
  amiFamily: ${var.karpenter_ami_family}
  role: ${var.karpenter_node_role_name}
  subnetSelectorTerms:
    - tags:
        ${join("\n        ", [for k, v in var.karpenter_subnet_tags : "${k}: ${v}"])}
  securityGroupSelectorTerms:
    - tags:
        ${join("\n        ", [for k, v in var.karpenter_security_group_tags : "${k}: ${v}"])}
  tags:
    ${join("\n    ", [for k, v in local.tags : "${k}: ${v}"])}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: ${var.karpenter_volume_size}
        volumeType: gp3
        encrypted: true
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  detailedMonitoring: ${var.karpenter_detailed_monitoring ? "true" : "false"}
YAML

  depends_on = [
    time_sleep.wait_for_karpenter_crds
  ]
}

#============================================================
#  NodePool - Defines node provisioning rules
#============================================================
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  labels:
    karpenter.sh/discovery: ${var.cluster_name}
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [${join(", ", [for v in var.karpenter_capacity_types : "\"${v}\""])}]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: [${join(", ", [for v in var.karpenter_instance_types : "\"${v}\""])}]
      expireAfter: 720h
  limits:
    cpu: ${var.karpenter_max_cpu}
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
  weight: 100
YAML

  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class
  ]
}
