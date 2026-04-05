#========================================================================
#                      *** KARPENTER Outputs ***
#========================================================================
output "karpenter_crds_applied" {
  description = "Indicates that the Karpenter CRDs (EC2NodeClass, NodePool, NodeClaim) have been applied."
  value       = "CRDs applied successfully"
}

output "karpenter_ec2_node_class_applied" {
  description = "Indicates that the Karpenter EC2NodeClass has been applied."
  value       = kubectl_manifest.karpenter_ec2_node_class.uid
}

output "karpenter_nodepool_applied" {
  description = "Indicates that the Karpenter NodePool has been applied."
  value       = kubectl_manifest.karpenter_nodepool.uid
}

output "karpenter_helm_release_name" {
  description = "The name of the deployed Karpenter Helm release."
  value       = helm_release.karpenter.name
}

output "karpenter_helm_release_namespace" {
  description = "The namespace where the Karpenter Helm release was deployed."
  value       = helm_release.karpenter.namespace
}

output "karpenter_helm_release_version" {
  description = "The deployed version of the Karpenter Helm chart."
  value       = helm_release.karpenter.version
}