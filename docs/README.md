# EKS Bootstraps Module

This module provides EKS managed node groups, bootstrap addons, and Karpenter configuration for Kubernetes clusters.

## Overview

The bootstraps module handles:

- **EKS Managed Node Groups** - Auto-scaling node groups for running Kubernetes workloads
- **Bootstrap Addons** - Core EKS addons (vpc-cni, coredns, kube-proxy)
- **Karpenter** - Optional auto-scaling solution for Kubernetes

## Resources Created

### IAM Resources

- IAM Role for EKS Node Group
- IAM Instance Profile for nodes
- IAM Role and Policy for Karpenter (optional)

### Kubernetes Resources

- EKS Managed Node Group
- EKS Addons (vpc-cni, coredns, kube-proxy)

## Usage

```hcl
terraform {
  source = "../../modules/compute/bootstraps"
}

include {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on EKS cluster
dependency "eks" {
  config_path = "../eks"
}

inputs = {
  project_name  = "finishline-infra-app"
  environment   = "dev"
  managed_by    = "finishline-infra-team"
  aws_region    = "us-east-1"

  cluster_name = "finishline-dev-eks"

  is_eks_nodegroup_enabled     = true
  is_eks_nodegroup_role_enabled = true

  node_group_name         = "primary-node-group"
  node_group_instance_types = ["t3.medium"]
  node_group_desired_size = 2
  node_group_min_size     = 1
  node_group_max_size     = 4
  node_group_subnets      = dependency.eks.outputs.private_subnet_ids
}
```

## Variables

| Variable                    | Description                    | Type         | Default       |
| --------------------------- | ------------------------------ | ------------ | ------------- |
| `project_name`              | Name of the project            | string       | required      |
| `environment`               | Environment (dev, stage, prod) | string       | required      |
| `cluster_name`              | EKS cluster name               | string       | required      |
| `node_group_name`           | Name of the node group         | string       | required      |
| `node_group_instance_types` | EC2 instance types             | list(string) | ["t3.medium"] |
| `node_group_capacity_type`  | ON_DEMAND or SPOT              | string       | "ON_DEMAND"   |
| `node_group_desired_size`   | Desired number of nodes        | number       | 2             |
| `node_group_min_size`       | Minimum nodes                  | number       | 1             |
| `node_group_max_size`       | Maximum nodes                  | number       | 4             |
| `is_karpenter_enabled`      | Enable Karpenter               | bool         | false         |

## Outputs

| Output               | Description                         |
| -------------------- | ----------------------------------- |
| `nodegroup_role_arn` | IAM role ARN for node group         |
| `nodegroup_id`       | EKS node group ID                   |
| `nodegroup_status`   | Node group status                   |
| `karpenter_role_arn` | Karpenter IAM role ARN (if enabled) |

## Dependencies

- EKS Cluster must be created first
- VPC with private subnets for node group placement
- Security groups for node communication
