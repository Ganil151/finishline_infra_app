#============================================================
#                 ***  Karpenter Outputs  ***
#============================================================
output "karpenter_ec2_node_class_name" {
  description = "Name of the Karpenter EC2NodeClass"
  value       = "default"
}

output "karpenter_node_pool_name" {
  description = "Name of the Karpenter NodePool"
  value       = "default"
}
