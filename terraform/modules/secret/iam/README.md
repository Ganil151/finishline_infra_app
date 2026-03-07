# IAM Module

This Terraform module creates IAM roles and policies required for EKS cluster operation, including cluster roles, node group roles, and OIDC identity provider configuration.

## Overview

The IAM module provisions four main components:

1. **EKS Cluster Role**: IAM role for the EKS control plane
2. **EKS Node Group Role**: IAM role for worker nodes
3. **OIDC Provider**: Identity provider for Kubernetes service accounts
4. **OIDC IAM Role**: Role with S3 access for service accounts

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        IAM Module                                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. EKS Cluster Role                                      │   │
│  │    ┌─────────────────────────────────────────────┐      │   │
│  │    │ aws_iam_role.eks-cluster-role                │      │   │
│  │    │ - Service: eks.amazonaws.com                │      │   │
│  │    │ + AmazonEKSClusterPolicy                     │      │   │
│  │    └─────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 2. EKS Node Group Role                                   │   │
│  │    ┌─────────────────────────────────────────────┐      │   │
│  │    │ aws_iam_role.eks-nodegroup-role             │      │   │
│  │    │ - Service: ec2.amazonaws.com                │      │   │
│  │    │ + AmazonEKSWorkerNodePolicy                  │      │   │
│  │    │ + AmazonEKS_CNI_Policy                      │      │   │
│  │    │ + AmazonEC2ContainerRegistryReadOnly         │      │   │
│  │    │ + AmazonEBSCSIDriverPolicy                   │      │   │
│  │    └─────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 3. OIDC Provider & Role                                   │   │
│  │    ┌──────────────────────┐  ┌──────────────────────┐  │   │
│  │    │ OIDC Provider         │  │ OIDC IAM Role         │  │   │
│  │    │ (aws_iam_openid_     │─▶│ (aws_iam_role.        │  │   │
│  │    │  connect_provider)    │  │  eks_oidc)            │  │   │
│  │    └──────────────────────┘  └──────────────────────┘  │   │
│  │                                       │                   │   │
│  │                                       ▼                   │   │
│  │                              ┌──────────────────────┐   │   │
│  │                              │ OIDC IAM Policy      │   │   │
│  │                              │ (S3 Access)          │   │   │
│  │                              └──────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "iam" {
  source = "./modules/secret/iam"

  cluster_name                  = "finishline-dev"
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true
  is_eks_cluster_enabled        = true
  eks_oidc_url                  = "https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXX"
}
```

### Complete Example with S3 Bucket Restriction

```hcl
module "iam" {
  source = "./modules/secret/iam"

  cluster_name                  = "finishline-prod"
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true
  is_eks_cluster_enabled        = true
  eks_oidc_url                  = "https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXX"
  oidc_thumbprint               = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  s3_bucket_arn                = "finishline-data-bucket"
}
```

### Using with EKS Module

```hcl
# First create IAM roles
module "iam" {
  source = "./modules/secret/iam"

  cluster_name                  = "finishline-dev"
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true
  is_eks_cluster_enabled        = true
  eks_oidc_url                  = ""  # Will be updated after EKS creation
}

# Then use with EKS module
module "eks" {
  source = "./modules/eks"

  cluster_name              = "finishline-dev"
  cluster_role_arn         = module.iam.eks_cluster_role_arn
  node_role_arn            = module.iam.eks_nodegroup_role_arn
  # ... other configuration
}
```

## Variables

| Variable                        | Description                                     | Type           | Required |
| ------------------------------- | ----------------------------------------------- | -------------- | -------- |
| `cluster_name`                  | The EKS cluster name                            | `string`       | Yes      |
| `is_eks_role_enabled`           | Whether to create the EKS cluster role          | `bool`         | Yes      |
| `is_eks_nodegroup_role_enabled` | Whether to create the node group role           | `bool`         | Yes      |
| `is_eks_cluster_enabled`        | Whether the EKS cluster is enabled (for OIDC)   | `bool`         | Yes      |
| `eks_oidc_url`                  | The OIDC issuer URL from EKS cluster            | `string`       | No       |
| `oidc_thumbprint`               | Server certificate thumbprint for OIDC provider | `list(string)` | No       |
| `s3_bucket_arn`                 | S3 bucket ARN to restrict OIDC role access      | `string`       | No       |

## Outputs

### Cluster Role Outputs

| Output                  | Description                      |
| ----------------------- | -------------------------------- |
| `eks_cluster_role_arn`  | ARN of the EKS cluster IAM role  |
| `eks_cluster_role_name` | Name of the EKS cluster IAM role |

### Node Group Role Outputs

| Output                    | Description                         |
| ------------------------- | ----------------------------------- |
| `eks_nodegroup_role_arn`  | ARN of the EKS node group IAM role  |
| `eks_nodegroup_role_name` | Name of the EKS node group IAM role |

### OIDC Outputs

| Output                  | Description                       |
| ----------------------- | --------------------------------- |
| `eks_oidc_role_arn`     | ARN of the OIDC IAM role          |
| `eks_oidc_role_name`    | Name of the OIDC IAM role         |
| `eks_oidc_policy_arn`   | ARN of the OIDC IAM policy        |
| `eks_oidc_provider_arn` | ARN of the OIDC identity provider |
| `eks_oidc_provider_url` | URL of the OIDC identity provider |

## Resources Created

### 1. EKS Cluster Role

**IAM Role** (`aws_iam_role.eks-cluster-role`):

- Name: `{cluster-name}-cluster-role-{random-suffix}`
- Trust Policy: Allows `eks.amazonaws.com` service to assume this role

**Policy Attachment** (`aws_iam_role_policy_attachment.AmazonEKSClusterPolicy`):

- Attaches `AmazonEKSClusterPolicy` managed policy
- Required for EKS cluster operations

### 2. EKS Node Group Role

**IAM Role** (`aws_iam_role.eks-nodegroup-role`):

- Name: `{cluster-name}-nodegroup-role-{random-suffix}`
- Trust Policy: Allows `ec2.amazonaws.com` service to assume this role

**Policy Attachments** (`aws_iam_role_policy_attachment.node-policies`):

- `AmazonEKSWorkerNodePolicy`: Allows nodes to join cluster
- `AmazonEKS_CNI_Policy`: Allows CNI to manage ENIs
- `AmazonEC2ContainerRegistryReadOnly`: Access to ECR repositories
- `AmazonEBSCSIDriverPolicy`: Allows EBS CSI driver operation

### 3. OIDC Provider

**IAM OIDC Provider** (`aws_iam_openid_connect_provider.eks-oidc-provider`):

- Creates an OIDC identity provider for the EKS cluster
- Client ID: `sts.amazonaws.com`
- Thumbprint: Configurable (defaults to AWS root CA)

### 4. OIDC IAM Role & Policy

**IAM Role** (`aws_iam_role.eks_oidc`):

- Name: `{cluster-name}-oidc-role`
- Trust Policy: Allows `oidc.eks.{region}.amazonaws.com` to assume this role
- Condition: Restricts to specific service account (`kube-system/aws-node`)

**IAM Policy** (`aws_iam_policy.eks-oidc-policy`):

- S3 List All Buckets
- S3 Get Bucket Location
- S3 Get Object (on specified bucket or all buckets)

## Dependency Flow with EKS Module

```
┌─────────────────┐          ┌─────────────────┐
│    IAM Module   │          │   EKS Module    │
├─────────────────┤          ├─────────────────┤
│                 │          │                 │
│ Creates:        │          │ Requires:       │
│ - Cluster Role │◀─────────│ - cluster_role │
│ - NodeGroup    │  (ARN)   │ - node_role    │
│   Role         │          │                 │
│                 │          │                 │
│ Optional:       │          │ Outputs:        │
│ - OIDC Provider│─────────▶│ - OIDC URL     │
│ - OIDC Role    │ (input)  │                 │
└─────────────────┘          └─────────────────┘
```

## Why OIDC?

### Traditional IAM vs OIDC

**Traditional IAM**:

- Long-lived IAM users/access keys
- Keys rotation required
- Not integrated with Kubernetes

**OIDC (OpenID Connect)**:

- Short-lived tokens (automatic rotation)
- Federated identity from Kubernetes
- Pods can assume IAM roles directly (IRSA)

### IRSA (IAM Roles for Service Accounts)

1. Pod authenticates using service account token
2. Token is validated against OIDC provider
3. AWS STS issues
4. Pod temporary credentials can access AWS resources with IAM role permissions

This provides:

- **Security**: No long-lived credentials in pods
- **Granularity**: Role per service account
- **Auditability**: CloudTrail logs show which pod accessed what

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0

## Dependencies

This module can create EKS cluster and node group roles independently.
However, for OIDC resources:

- **Requires**: EKS cluster to be created first (to get OIDC URL)
- **Or**: Pass empty string to disable OIDC creation

### Internal Dependencies

This module uses a `random_integer` resource to generate a unique suffix (1000-9999) for role names to prevent conflicts.

## Considerations

### Random Suffix

A random suffix (1000-9999) is added to role names to prevent conflicts if the module is applied multiple times. This is automatically generated using the `random_integer` resource.

### S3 Bucket Restriction

The OIDC role policy can be scoped to a specific S3 bucket:

- Empty `s3_bucket_arn`: Access to all S3 buckets (not recommended)
- Specific bucket: Access only to that bucket

### OIDC Provider Thumbprint

The default thumbprint is for AWS's root CA. For production, consider updating this value.

## Troubleshooting

### EKS Cluster Role Not Found

- Verify `is_eks_role_enabled = true`
- Check that the role was created in the correct AWS account/region

### Nodes Can't Join Cluster

- Verify node group role has all required policies
- Check node instance profile exists
- Ensure nodes have network access to EKS endpoint

### OIDC Provider Creation Fails

- Ensure EKS cluster exists and is active
- Verify `eks_oidc_url` is correct
- Check OIDC thumbprint is valid

### IRSA Not Working

- Verify OIDC provider is created
- Check service account annotation: `eks.amazonaws.com/role-arn: <role-arn>`
- Ensure trust policy allows the correct service account

## Integration with EKS Module

```hcl
module "iam" {
  source = "./modules/secret/iam"

  cluster_name                  = "finishline-dev"
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true
  is_eks_cluster_enabled        = true
  eks_oidc_url                  = ""  # Set after EKS creation
}

module "eks" {
  source = "./modules/eks"

  project_name              = "finishline"
  environment               = "dev"
  manage_by                 = "terraform"
  cluster_name              = "finishline-dev"
  cluster_version           = "1.29"

  # Use IAM roles from IAM module
  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_nodegroup_role_arn

  # ... other configuration
}
```

## Security Best Practices

1. **Least Privilege**: Use specific S3 bucket restrictions in OIDC policy
2. **Regular Rotation**: IAM roles don't require key rotation (handled by AWS)
3. **Audit**: Use CloudTrail to monitor role usage
4. **Node Isolation**: Use separate IAM roles for different workload types
