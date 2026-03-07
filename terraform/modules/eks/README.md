# EKS Module

This Terraform module creates an Amazon EKS cluster with managed node groups for running Kubernetes workloads.

## Overview

The EKS module provisions:

- EKS Cluster with control plane
- On-Demand Managed Node Group
- Spot Managed Node Group
- OIDC Identity Provider for IRSA
- EKS Addons support

## Relationship to VPC (Private Subnets)

The EKS module **uses the same private subnets** from the VPC module. This is a critical relationship that ensures the cluster and its nodes are deployed in the correct network infrastructure.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC                                     │
│                    10.0.0.0/16                                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Private Subnets (AZ1, AZ2)                   │  │
│  │  ┌──────────────────┐    ┌──────────────────┐           │  │
│  │  │ 10.0.10.0/24     │    │ 10.0.20.0/24    │           │  │
│  │  │                  │    │                  │           │  │
│  │  │ ┌──────────────┐ │    │ ┌──────────────┐ │           │  │
│  │  │ │ EKS Cluster │ │    │ │ EKS Cluster │ │           │  │
│  │  │ └──────────────┘ │    │ └──────────────┘ │           │  │
│  │  │                  │    │                  │           │  │
│  │  │ ┌──────────────┐ │    │ ┌──────────────┐ │           │  │
│  │  │ │ On-Demand    │ │    │ │ On-Demand    │ │           │  │
│  │  │ │ Node Group   │ │    │ │ Node Group   │ │           │  │
│  │  │ └──────────────┘ │    │ └──────────────┘ │           │  │
│  │  │                  │    │                  │           │  │
│  │  │ ┌──────────────┐ │    │ ┌──────────────┐ │           │  │
│  │  │ │ Spot         │ │    │ │ Spot         │ │           │  │
│  │  │ │ Node Group   │ │    │ │ Node Group   │ │           │  │
│  │  │ └──────────────┘ │    │ └──────────────┘ │           │  │
│  │  └──────────────────┘    └──────────────────┘           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## How EKS Uses VPC Private Subnets

### 1. Connection Flow

```
VPC Module                           EKS Module
┌─────────────────────┐            ┌─────────────────────────┐
│                     │            │                         │
│ Creates:           │            │ Requires:               │
│ - Private Subnets  │──────────▶│ - subnet_ids           │
│   (main_private_   │  (output) │   (list of subnet IDs) │
│    subnet_ids)     │            │                         │
│                     │            │ Uses for:               │
│                     │            │ - EKS Cluster          │
│                     │            │ - On-Demand Nodes       │
│                     │            │ - Spot Nodes            │
└─────────────────────┘            └─────────────────────────┘
```

### 2. Configuration in Environment

In your environment's `main.tf`, the connection is made:

```hcl
# VPC Module
module "vpc" {
  source = "../vpc"
  # ... configuration
}

# EKS Module - uses private subnets from VPC
module "eks" {
  source = "../eks"

  # Private subnets from VPC module
  subnet_ids = module.vpc.main_private_subnet_ids

  # ... other configuration
}
```

### 3. How Subnets Are Used

The `subnet_ids` variable is used in three places within the EKS module:

#### EKS Cluster

```hcl
resource "aws_eks_cluster" "eks" {
  vpc_config {
    subnet_ids = var.subnet_ids
    # ... other config
  }
}
```

#### On-Demand Node Group

```hcl
resource "aws_eks_node_group" "ondemand-node" {
  subnet_ids = var.subnet_ids
  # ... other config
}
```

#### Spot Node Group

```hcl
resource "aws_eks_node_group" "spot-node" {
  subnet_ids = var.subnet_ids
  # ... other config
}
```

## Usage

### Basic Example

```hcl
module "eks" {
  source = "./modules/eks"

  project_name              = "finishline"
  environment               = "dev"
  manage_by                 = "terraform"
  cluster_name              = "finishline-dev"
  cluster_version           = "1.35"

  # IAM Roles
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  node_role_arn             = module.iam.eks_nodegroup_role_arn

  # Network - private subnets from VPC
  subnet_ids                = module.vpc.main_private_subnet_ids
  security_group_ids        = [module.security_group.finishline_sg_id]

  # Cluster config
  is_eks_cluster_enabled    = true
  is_eks_node_group_enabled = true

  # Node groups
  desired_capacity_on_demand = 2
  min_capacity_on_demand    = 2
  max_capacity_on_demand    = 2
}
```

### Complete Example

```hcl
module "eks" {
  source = "./modules/eks"

  project_name              = "finishline"
  environment               = "prod"
  manage_by                 = "terraform"
  cluster_name              = "finishline-prod"
  cluster_version           = "1.35"
  is_eks_cluster_enabled    = true
  is_eks_node_group_enabled = true
  is_eks_addons_enabled    = true

  # IAM Roles
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  node_role_arn             = module.iam.eks_nodegroup_role_arn

  # Network - Private subnets from VPC (REQUIRED)
  subnet_ids                = module.vpc.main_private_subnet_ids
  security_group_ids        = [module.security_group.finishline_sg_id]

  # Endpoint access
  endpoint_private_access   = true
  endpoint_public_access    = false

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # Addons
  addons = {
    vpc-cni = {
      version = "v1.18.0-eksbuild.1"
    }
  }

  # On-Demand Node Group
  desired_capacity_on_demand = 3
  min_capacity_on_demand    = 2
  max_capacity_on_demand    = 5
  ondemand_instance_types   = ["m5.large"]

  # Spot Node Group
  desired_capacity_spot     = 3
  min_capacity_spot         = 1
  max_capacity_spot         = 5
  spot_instance_types       = ["m5.large", "m5.xlarge"]
}
```

## Variables

| Variable                     | Description                                                                | Type           | Required |
| ---------------------------- | -------------------------------------------------------------------------- | -------------- | -------- |
| `project_name`               | The name of the project                                                    | `string`       | Yes      |
| `environment`                | The environment (dev, staging, prod)                                       | `string`       | Yes      |
| `manage_by`                  | The entity responsible for managing the cluster                            | `string`       | Yes      |
| `cluster_name`               | The name of the EKS cluster                                                | `string`       | Yes      |
| `cluster_role_arn`           | ARN of the IAM role for EKS control plane                                  | `string`       | Yes      |
| `node_role_arn`              | ARN of the IAM role for node groups                                        | `string`       | Yes      |
| `subnet_ids`                 | List of private subnet IDs from VPC module                                 | `list(string)` | Yes      |
| `security_group_ids`         | List of security group IDs                                                 | `list(string)` | Yes      |
| `cluster_version`            | Kubernetes version                                                         | `string`       | Yes      |
| `is_eks_cluster_enabled`     | Enable/disable cluster creation                                            | `bool`         | Yes      |
| `is_eks_node_group_enabled`  | Enable/disable node groups                                                 | `bool`         | Yes      |
| `is_eks_addons_enabled`      | Enable/disable addons                                                      | `bool`         | No       |
| `endpoint_private_access`    | Enable private API endpoint                                                | `bool`         | No       |
| `endpoint_public_access`     | Enable public API endpoint                                                 | `bool`         | No       |
| `cluster_enabled_log_types`  | CloudWatch log types                                                       | `list(string)` | No       |
| `addons`                     | Map of addons to install                                                   | `map(any)`     | No       |
| `desired_capacity_on_demand` | Desired number of on-demand nodes                                          | `number`       | No       |
| `min_capacity_on_demand`     | Minimum number of on-demand nodes                                          | `number`       | No       |
| `max_capacity_on_demand`     | Maximum number of on-demand nodes                                          | `number`       | No       |
| `ondemand_instance_types`    | List of instance types for on-demand nodes (default: ["t3.medium"])        | `list(string)` | No       |
| `desired_capacity_spot`      | Desired number of spot nodes                                               | `number`       | No       |
| `min_capacity_spot`          | Minimum number of spot nodes                                               | `number`       | No       |
| `max_capacity_spot`          | Maximum number of spot nodes                                               | `number`       | No       |
| `spot_instance_types`        | List of instance types for spot nodes (default: ["t3.medium", "t3.large"]) | `list(string)` | No       |

## Outputs

| Output                               | Description               |
| ------------------------------------ | ------------------------- |
| `cluster_id`                         | EKS cluster ID            |
| `cluster_arn`                        | EKS cluster ARN           |
| `cluster_endpoint`                   | API server endpoint URL   |
| `cluster_version`                    | Kubernetes version        |
| `cluster_certificate_authority_data` | CA certificate for API    |
| `cluster_security_group_id`          | Cluster security group ID |
| `cluster_oidc_issuer`                | OIDC issuer URL           |
| `cluster_oidc_provider_arn`          | OIDC provider ARN         |
| `ondemand_node_group_id`             | On-demand node group ID   |
| `ondemand_node_group_arn`            | On-demand node group ARN  |
| `spot_node_group_id`                 | Spot node group ID        |
| `spot_node_group_arn`                | Spot node group ARN       |

## Resources Created

### 1. EKS Cluster

- Kubernetes control plane
- VPC configuration with provided subnets
- OIDC identity provider
- Access configuration with `CONFIG_MAP` authentication mode
- Explicitly disables EKS Auto Mode (uses managed node groups instead)

### 2. On-Demand Node Group

- Managed node group with on-demand capacity
- Auto-scaling configuration

### 3. Spot Node Group

- Managed node group with spot capacity
- Cost-optimized for fault-tolerant workloads
- 30GB disk size

### 4. OIDC Provider

- IAM OIDC identity provider for IRSA

### 5. Addons (Optional)

- Configurable EKS addons (VPC-CNI, CoreDNS, etc.)

## Tagging Convention

All resources are tagged consistently:

- `Name`: Resource-specific name
- `Project`: The project name
- `Environment`: The environment
- `ManagedBy`: The value of `manage_by` variable
- `Terraform`: Set to "true"

## Integration with VPC Module

The EKS module is designed to work seamlessly with the VPC module:

```hcl
# 1. Create VPC first
module "vpc" {
  source = "../vpc"
  # ... VPC configuration
}

# 2. Create security group
module "security_group" {
  source = "../security_group"
  vpc_id = module.vpc.main_vpc_id
  # ... security group configuration
}

# 3. Create EKS using VPC's private subnets
module "eks" {
  source = "../eks"

  # Private subnets from VPC - REQUIRED
  subnet_ids         = module.vpc.main_private_subnet_ids
  security_group_ids = [module.security_group.finishline_sg_id]

  # ... other configuration
}
```

### Why Private Subnets?

EKS clusters and nodes should be deployed in private subnets because:

1. **Security**: Nodes are not directly accessible from the internet
2. **Isolation**: Workloads are isolated from public networks
3. **NAT Gateway**: Private subnets can access the internet via NAT Gateway
4. **AWS Services**: Nodes can access AWS services via VPC endpoints

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0
- VPC module must be applied first

## Dependencies

1. **VPC Module**: Must provide private subnet IDs
2. **Security Group Module**: Must provide security group IDs
3. **IAM Module**: Must provide cluster and node role ARNs

## Troubleshooting

### Nodes Not Joining Cluster

1. Verify `subnet_ids` are from the same VPC
2. Check security groups allow node communication
3. Ensure node role has required IAM policies

### Cannot Access API Server

1. Check endpoint configuration (public/private)
2. Verify security groups allow API access
3. Ensure correct IAM permissions

### Subnet Not Found

1. Verify VPC module was applied first
2. Check `subnet_ids` variable is passed correctly
3. Ensure subnets exist in the correct VPC

## Best Practices

1. **Always use private subnets** for EKS nodes
2. **Enable private endpoint access** for security
3. **Use both on-demand and spot** for cost optimization
4. **Configure appropriate node sizes** for workloads
5. **Enable cluster logging** for auditing
