# Karpenter Module

Deploys Karpenter autoscaler for Kubernetes-native node provisioning on EKS clusters.

## Overview

This module manages:

- **Helm Release** - Installs the Karpenter controller via OCI chart from ECR
- **EC2NodeClass** - Defines EC2 configuration (AMI, subnets, security groups, volumes)
- **NodePool** - Defines node provisioning rules (instance types, capacity, disruption)

## Prerequisites

- EKS cluster deployed (`compute/eks`)
- IAM roles created (`security/iam`) including `karpenter-controller` and `karpenter-node` roles
- VPC and security groups with `karpenter.sh/discovery` tags
- Helm provider >= 3.0 (required for `set` argument syntax)

## Usage

```hcl
module "karpenter" {
  source = "../compute/karpenter"

  cluster_name               = module.eks.cluster_name
  cluster_endpoint           = module.eks.cluster_endpoint
  cluster_ca_certificate     = module.eks.cluster_certificate_authority_data
  aws_region                 = "us-east-1"

  karpenter_controller_role_arn    = module.iam.karpenter_controller_role_arn
  karpenter_node_role_name         = module.iam.karpenter_node_role_name
  karpenter_instance_profile_name  = module.iam.karpenter_node_instance_profile_name

  karpenter_subnet_tags = {
    "karpenter.sh/discovery" = "finishline-prod-eks"
  }
  karpenter_security_group_tags = {
    "karpenter.sh/discovery" = "finishline-prod-eks"
  }

  karpenter_instance_types    = ["m5.large", "m5.xlarge", "c5.large"]
  karpenter_max_cpu           = 50
  karpenter_capacity_types    = ["spot", "on-demand"]
  karpenter_ami_family        = "Bottlerocket"
  karpenter_volume_size       = "50Gi"
  karpenter_detailed_monitoring = false

  karpenter_namespace              = "karpenter"
  karpenter_interruption_queue_name = "finishline-prod-eks"

  project_name   = "finishline"
  environment    = "prod"
  computed_tags  = local.common_tags
}
```

## Resources Created

| Resource                        | Description                            |
| ------------------------------- | -------------------------------------- |
| `helm_release.karpenter`        | Karpenter controller (OCI chart from ECR) |
| `karpenter_ec2_node_class`      | EC2NodeClass - EC2 configuration       |
| `karpenter_node_pool`           | NodePool - provisioning rules          |

## Variables

| Variable                              | Description                                      | Type          | Default     |
| ------------------------------------- | ------------------------------------------------ | ------------- | ----------- |
| `cluster_name`                        | Name of the EKS cluster                          | string        | required    |
| `cluster_endpoint`                    | Endpoint URL of the EKS cluster                  | string        | required    |
| `cluster_ca_certificate`              | Certificate authority data of the EKS cluster    | string        | required    |
| `aws_region`                          | AWS region                                       | string        | required    |
| `karpenter_controller_role_arn`       | IAM role ARN for Karpenter controller (IRSA)     | string        | required    |
| `karpenter_node_role_name`            | IAM role name for Karpenter nodes                | string        | required    |
| `karpenter_instance_profile_name`     | IAM instance profile name for Karpenter nodes    | string        | required    |
| `karpenter_subnet_tags`               | Tags to select subnets for Karpenter nodes       | map(string)   | required    |
| `karpenter_security_group_tags`       | Tags to select security groups for Karpenter     | map(string)   | required    |
| `karpenter_instance_types`            | List of instance types for provisioning          | list(string)  | required    |
| `karpenter_max_cpu`                   | Maximum CPU cores Karpenter can provision        | number        | required    |
| `karpenter_capacity_types`            | Capacity types (spot, on-demand)                 | list(string)  | required    |
| `karpenter_ami_family`                | AMI family (e.g., Bottlerocket, AL2)             | string        | required    |
| `karpenter_volume_size`               | Root volume size for Karpenter nodes             | string        | required    |
| `karpenter_detailed_monitoring`       | Enable detailed monitoring for nodes             | bool          | required    |
| `karpenter_namespace`                 | Kubernetes namespace for Karpenter               | string        | `karpenter` |
| `karpenter_interruption_queue_name`   | SQS queue name for interruption handling         | string        | required    |
| `project_name`                        | Project name for tagging                         | string        | required    |
| `environment`                         | Environment name                                 | string        | required    |
| `computed_tags`                       | Map of tags to apply to all resources            | map(string)   | required    |

## Outputs

| Output                           | Description                        |
| -------------------------------- | ---------------------------------- |
| `karpenter_ec2_node_class_name`  | Name of the EC2NodeClass resource  |
| `karpenter_node_pool_name`       | Name of the NodePool resource      |

## Helm Chart Configuration

The module installs the Karpenter chart from the AWS ECR public registry:

```
oci://public.ecr.aws/karpenter/karpenter
```

### Helm Provider >= 3.0

This module uses the `set` argument syntax introduced in Helm provider v3.0:

```hcl
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
```

The `dynamic "set"` block syntax used in Helm provider v2.x is no longer supported. If you encounter the error `Blocks of type "set" are not expected here`, ensure your Helm provider version is >= 3.0 and that `set` values use the `=` argument syntax rather than block syntax.

## Verification

```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region us-east-1

# Verify Karpenter controller
kubectl get pods -n karpenter

# Verify EC2NodeClass and NodePool
kubectl get ec2nodeclass
kubectl get nodepool

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50
```
