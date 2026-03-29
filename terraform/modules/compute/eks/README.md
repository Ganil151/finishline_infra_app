# EKS Module

This Terraform module creates and manages Amazon Elastic Kubernetes Service (EKS) clusters with managed node groups for the Finishline project. It integrates with the [Security IAM Module](../../security/iam/README.md) for IAM roles and the [Networking VPC/SG Modules](../../networking/README.md) for network infrastructure.

---

## Table of Contents

- [Overview](#overview)
- [Integration with Other Modules](#integration-with-other-modules)
- [Architecture](#architecture)
- [Features](#features)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Required Variables](#required-variables)
  - [Optional Variables](#optional-variables)
  - [Cluster Configuration](#cluster-configuration)
  - [Node Group Configuration](#node-group-configuration)
  - [Access Configuration](#access-configuration)
- [Outputs](#outputs)
- [EKS Access Management](#eks-access-management)
- [IRSA (IAM Roles for Service Accounts)](#irsa-iam-roles-for-service-accounts)
- [Tags](#tags)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [AWS CLI Commands](#aws-cli-commands)
- [Module Structure](#module-structure)

---

## Overview

> [!NOTE] 
> **The 101 Concept:** Amazon EKS (Elastic Kubernetes Service) is like a highly-trained conductor for a massive orchestra of containers. Instead of you having to manually install, operate, and maintain the Kubernetes control plane across multiple virtual machines, AWS does the heavy lifting for you. It ensures your cluster is highly available, secure, and always running.

> [!TIP]
> **The DevSecOps Angle:** In this module, we deliberately separate our Node Groups (the EC2 servers where your apps run) from our Control Plane. We also enforce private API endpoints where possible, meaning hackers on the public internet cannot even *see* our Kubernetes master node. Finally, we implement **IRSA** (IAM Roles for Service Accounts) so that pods get their own individual security badges, rather than sharing a master skeleton key.

The EKS module provides a production-ready Kubernetes cluster on AWS with the following capabilities:

- **Managed Control Plane** - AWS manages the Kubernetes control plane operations (etcd, API server).
- **Managed Node Groups** - Automated EC2 provisioning and lifecycle management
- **EKS Access Entries** - IAM-based cluster access control
- **IRSA Support** - IAM Roles for Kubernetes Service Accounts
- **Multi-AZ Deployment** - High availability across availability zones
- **Private Endpoint** - Secure API server access
- **CloudWatch Logging** - Control plane log integration

**Integration Points:**

| Integration         | Source Module  | Purpose                    |
| ------------------- | -------------- | -------------------------- |
| **IAM Roles**       | security/iam   | Cluster and node IAM roles |
| **VPC/Subnets**     | networking/vpc | Network infrastructure     |
| **Security Groups** | networking/sg  | Control plane security     |
| **OIDC Provider**   | security/iam   | IRSA trust relationship    |

---

## Integration with Other Modules

### Dependency Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS Module Dependencies                       │
└─────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │  Security IAM Module │
                    │                     │
                    │ • eks_cluster_role  │
                    │ • eks_nodegroup_role│
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Networking Modules   │
                    │                     │
                    │ • VPC               │
                    │ • Subnets           │
                    │ • Security Groups   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   EKS Module        │
                    │                     │
                    │ • EKS Cluster       │
                    │ • Node Group        │
                    │ • Access Entries    │
                    └─────────────────────┘
```

### Terraform Integration Example

```hcl
# ============================================================
# 1. Security Module - IAM Roles
# ============================================================
module "iam" {
  source = "../../security/iam"

  project_name             = "finishline"
  environment              = "prod"
  managed_by               = "platform-team"
  aws_region               = "us-east-1"
  cluster_name             = "finishline-prod-eks"

  # Enable EKS IAM resources
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true
}

# ============================================================
# 2. Networking Module - VPC
# ============================================================
module "vpc" {
  source = "../../networking/vpc"

  project_name         = "finishline"
  environment          = "prod"
  managed_by           = "platform-team"
  aws_region           = "us-east-1"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24"]

  ingress_rules_transform = [ /* ... */ ]
  egress_rules_transform  = [ /* ... */ ]
}

# ============================================================
# 3. Networking Module - Security Groups
# ============================================================
module "eks_sg" {
  source = "../../networking/sg"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-east-1"
  vpc_id          = module.vpc.vpc_id

  security_group_name        = "finishline-prod-eks-sg"
  security_group_description = "Security group for EKS cluster"

  ingress_rules = [
    {
      description = "HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "EKS API from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  egress_rules = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# ============================================================
# 4. Compute Module - EKS Cluster
# ============================================================
module "eks" {
  source = "../../compute/eks"

  project_name  = "finishline"
  environment   = "prod"
  managed_by    = "platform-team"
  aws_region    = "us-east-1"
  cluster_name  = "finishline-prod-eks"

  # From Security Module
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  node_group_role_arn  = module.iam.eks_nodegroup_role_arn

  # From Networking Module
  subnets            = module.vpc.private_subnets_ids
  security_group_ids = [module.eks_sg.security_group_id]

  # Cluster configuration
  cluster_version = "1.30"
  is_eks_cluster_enabled = true

  # Endpoint access
  endpoint_private_access = true
  endpoint_public_access  = false
  public_access_cidrs     = ["0.0.0.0/0"]

  # Logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Authentication
  authentication_mode = "API"
  bootstrap_cluster_creator_admin_permissions = true

  # Node group configuration
  is_eks_nodegroup_enabled = true
  node_group_name          = "managed-nodes"
  node_group_ami_type      = "BOTTLEROCKET_x86_64"
  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_disk_size     = 50

  node_group_scaling_config = {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  node_group_update_config = {
    max_unavailable = 1
  }
}
```

---

## Architecture

### EKS Cluster Architecture

```
                                    Internet
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │   Route 53 (Optional)         │
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │   Public Subnets              │
                        │   - NAT Gateway               │
                        │   - Internet Gateway          │
                        └───────────────────────────────┘
                                        │
                                        │ Private Access
                                        ▼
            ┌───────────────────────────────────────────────────────┐
            │                    VPC                                 │
            │                  10.0.0.0/16                           │
            │                                                        │
            │  ┌──────────────────────────────────────────────────┐ │
            │  │              Private Subnets                      │ │
            │  │                                                   │ │
            │  │  ┌─────────────────────────────────────────────┐ │ │
            │  │  │         EKS Control Plane (Managed)          │ │ │
            │  │  │  - API Server                                │ │ │
            │  │  │  - etcd                                      │ │ │
            │  │  │  - Controller Manager                        │ │ │
            │  │  │  - Scheduler                                 │ │ │
            │  │  └─────────────────────────────────────────────┘ │ │
            │  │                                                   │ │
            │  │  ┌─────────────────────────────────────────────┐ │ │
            │  │  │         Managed Node Group                   │ │ │
            │  │  │  - EC2 Instances (t3.medium)                 │ │ │
            │  │  │  - kubelet                                   │ │ │
            │  │  │  - kube-proxy                                │ │ │
            │  │  │  - CNI Plugin                                │ │ │
            │  │  └─────────────────────────────────────────────┘ │ │
            │  │                                                   │ │
            │  │  ┌─────────────────────────────────────────────┐ │ │
            │  │  │         Karpenter Nodes (Dynamic)            │ │ │
            │  │  │  - EC2 Instances (Auto-scaled)               │ │ │
            │  │  │  - Provisioned by Karpenter                  │ │ │
            │  │  └─────────────────────────────────────────────┘ │ │
            │  │                                                   │ │
            │  └──────────────────────────────────────────────────┘ │
            └───────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────────┐
                    │   Security Module (IAM)           │
                    │                                   │
                    │ • Cluster Role                    │
                    │ • Node Group Role                 │
                    │ • OIDC Provider                   │
                    └───────────────────────────────────┘
```

### Network Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EKS Network Flow                                 │
└─────────────────────────────────────────────────────────────────────────┘

1. kubectl command from developer
   │
   ▼
2. EKS API Server (Private Endpoint)
   - Authentication via IAM
   - Authorization via Access Entries
   │
   ▼
3. Control Plane Components
   - API Server processes request
   - etcd stores cluster state
   - Controller Manager maintains desired state
   - Scheduler assigns pods to nodes
   │
   ▼
4. Worker Nodes (Managed Node Group)
   - kubelet receives pod assignments
   - kube-proxy configures networking
   - CNI plugin assigns pod IPs
   │
   ▼
5. Pods Run on Nodes
   - Application containers
   - Sidecar containers
   - Init containers
```

---

## Features

| Feature                   | Description                                   |
| ------------------------- | --------------------------------------------- |
| **Managed Control Plane** | AWS manages API server, etcd, and controllers |
| **Managed Node Groups**   | Automated EC2 provisioning and lifecycle      |
| **EKS Access Entries**    | IAM-based cluster access control (new model)  |
| **Multiple Auth Modes**   | API, API_AND_CONFIG_MAP, or CONFIG_MAP        |
| **Private Endpoint**      | Secure API server access via private network  |
| **CloudWatch Logging**    | Control plane log types integration           |
| **IRSA Ready**            | OIDC provider integration for pod IAM         |
| **Multi-AZ**              | Nodes distributed across availability zones   |
| **Bottlerocket Support**  | Hardened container OS option                  |
| **Upgrade Policy**        | Optional automated upgrade support            |

---

## Usage

### Basic EKS Cluster

```hcl
module "eks" {
  source = "./modules/compute/eks"

  # Required variables
  project_name  = "finishline"
  environment   = "dev"
  managed_by    = "dev-team"
  aws_region    = "us-east-1"
  cluster_name  = "finishline-dev-eks"

  # From Security Module
  eks_cluster_role_arn = "arn:aws:iam::123456789012:role/finishline-dev-eks-cluster-role"
  node_group_role_arn  = "arn:aws:iam::123456789012:role/finishline-dev-eks-nodegroup-role"

  # From Networking Module
  subnets            = ["subnet-abc123", "subnet-def456"]
  security_group_ids = ["sg-abc123"]

  # Cluster configuration
  cluster_version = "1.30"
  is_eks_cluster_enabled = true

  # Endpoint access
  endpoint_private_access = true
  endpoint_public_access  = false

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # Authentication
  authentication_mode = "API"
  bootstrap_cluster_creator_admin_permissions = true

  # Node group
  is_eks_nodegroup_enabled = true
  node_group_name          = "default-nodes"
  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_disk_size     = 50

  node_group_scaling_config = {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  node_group_update_config = {
    max_unavailable = 1
  }
}
```

---

## Configuration

### Required Variables

| Variable                                      | Type           | Description                                    | Example                      |
| --------------------------------------------- | -------------- | ---------------------------------------------- | ---------------------------- |
| `project_name`                                | `string`       | Name of the project                            | `"finishline"`               |
| `environment`                                 | `string`       | Environment name                               | `"dev"`, `"prod"`            |
| `managed_by`                                  | `string`       | Managing team                                  | `"platform-team"`            |
| `aws_region`                                  | `string`       | AWS region                                     | `"us-east-1"`                |
| `cluster_name`                                | `string`       | EKS cluster name                               | `"finishline-prod-eks"`      |
| `cluster_version`                             | `string`       | Kubernetes version                             | `"1.30"`                     |
| `is_eks_cluster_enabled`                      | `bool`         | Enable EKS cluster                             | `true`                       |
| `eks_cluster_role_arn`                        | `string`       | IAM role ARN for cluster                       | From `security/iam` output   |
| `cluster_enabled_log_types`                   | `list(string)` | Log types to enable                            | `["api", "audit"]`           |
| `subnets`                                     | `list(string)` | Subnet IDs for nodes                           | From `networking/vpc` output |
| `endpoint_private_access`                     | `bool`         | Enable private endpoint                        | `true`                       |
| `endpoint_public_access`                      | `bool`         | Enable public endpoint                         | `false`                      |
| `public_access_cidrs`                         | `list(string)` | CIDRs for public access                        | `["0.0.0.0/0"]`              |
| `security_group_ids`                          | `list(string)` | Security groups                                | From `networking/sg` output  |
| `authentication_mode`                         | `string`       | Auth mode: API, API_AND_CONFIG_MAP, CONFIG_MAP | `"API"`                      |
| `bootstrap_cluster_creator_admin_permissions` | `bool`         | Grant creator admin                            | `true`                       |
| `is_eks_nodegroup_enabled`                    | `bool`         | Enable node group                              | `true`                       |
| `node_group_name`                             | `string`       | Node group name                                | `"managed-nodes"`            |
| `node_group_role_arn`                         | `string`       | IAM role for nodes                             | From `security/iam` output   |
| `node_group_subnets`                          | `list(string)` | Subnets for nodes                              | From `networking/vpc` output |
| `node_group_ami_type`                         | `string`       | AMI type                                       | `"BOTTLEROCKET_x86_64"`      |
| `node_group_instance_types`                   | `list(string)` | Instance types                                 | `["t3.medium"]`              |
| `node_group_capacity_type`                    | `string`       | ON_DEMAND or SPOT                              | `"ON_DEMAND"`                |
| `node_group_disk_size`                        | `number`       | Root disk size in GiB                          | `50`                         |
| `node_group_scaling_config`                   | `object`       | Scaling configuration                          | See below                    |
| `node_group_update_config`                    | `object`       | Update configuration                           | See below                    |

### Optional Variables

| Variable                             | Type           | Default                                                 | Description                        |
| ------------------------------------ | -------------- | ------------------------------------------------------- | ---------------------------------- |
| `enable_upgrade_policy`              | `bool`         | `false`                                                 | Enable automated upgrade policy    |
| `upgrade_policy_support_type`        | `string`       | `"STANDARD"`                                            | STANDARD or EXTENDED               |
| `cluster_admin_principals`           | `map(string)`  | `{}`                                                    | IAM principals for admin access    |
| `cluster_admin_kubernetes_groups`    | `list(string)` | `[]`                                                    | Kubernetes groups for admins       |
| `cluster_admin_policy_arn`           | `string`       | `"arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"` | Admin policy ARN                   |
| `node_group_launch_template_id`      | `string`       | `""`                                                    | Custom launch template ID          |
| `node_group_launch_template_version` | `string`       | `"$Default"`                                            | Launch template version            |
| `node_group_labels`                  | `map(string)`  | `{}`                                                    | Kubernetes labels for nodes        |
| `node_group_tags`                    | `map(string)`  | `{}`                                                    | AWS tags for nodes                 |
| `node_group_taints`                  | `list(object)` | `[]`                                                    | Kubernetes taints for nodes        |
| `ebs_csi_driver_role_arn`            | `string`       | `""`                                                    | IAM role for EBS CSI driver (IRSA) |
| `node_group_timeouts`                | `object`       | See below                                               | Operation timeouts                 |

### Cluster Configuration

#### Cluster Version

```hcl
# Use current stable version
cluster_version = "1.30"

# Check available versions
aws eks describe-addon-versions --query "addons[].addonVersions[].kubernetesVersions" --output table
```

#### Endpoint Access

```hcl
# Private only (recommended for production)
endpoint_private_access = true
endpoint_public_access  = false

# Public and private (for development)
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["203.0.113.0/24"]  # Corporate IP

# Public only (not recommended)
endpoint_private_access = false
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]
```

#### Logging Configuration

```hcl
# All log types (recommended for production)
cluster_enabled_log_types = [
  "api",              # Kubernetes API server
  "audit",            # Kubernetes audit logs
  "authenticator",    # Kubernetes authenticator
  "controllerManager", # Controller manager
  "scheduler"         # Kubernetes scheduler
]

# Minimal logging (for development)
cluster_enabled_log_types = ["api", "authenticator"]

# No logging (not recommended)
cluster_enabled_log_types = []
```

### Node Group Configuration

#### Scaling Configuration

```hcl
node_group_scaling_config = {
  desired_size = 2  # Initial number of nodes
  min_size     = 2  # Minimum nodes (for HA)
  max_size     = 4  # Maximum nodes
}

# Production (high availability)
node_group_scaling_config = {
  desired_size = 3
  min_size     = 3
  max_size     = 10
}

# Development (cost optimization)
node_group_scaling_config = {
  desired_size = 1
  min_size     = 0  # Can scale to zero
  max_size     = 2
}
```

#### Update Configuration

```hcl
node_group_update_config = {
  max_unavailable = 1  # Max nodes unavailable during update
}

# For larger node groups
node_group_update_config = {
  max_unavailable = 2  # Allow 2 nodes unavailable
}
```

#### AMI Types

| AMI Type              | Description             | Use Case                |
| --------------------- | ----------------------- | ----------------------- |
| `AL2_x86_64`          | Amazon Linux 2 (x86-64) | General purpose         |
| `AL2_ARM_64`          | Amazon Linux 2 (ARM)    | Graviton instances      |
| `BOTTLEROCKET_x86_64` | Bottlerocket (x86-64)   | **Recommended**         |
| `BOTTLEROCKET_ARM_64` | Bottlerocket (ARM)      | Graviton + Bottlerocket |

**Why Bottlerocket?**

- Minimal container OS (smaller attack surface)
- Automatic updates
- Immutable infrastructure
- Better security posture

#### Instance Types

```hcl
# General purpose (balanced)
node_group_instance_types = ["t3.medium"]

# Compute optimized
node_group_instance_types = ["c5.large", "c5.xlarge"]

# Memory optimized
node_group_instance_types = ["m5.large", "m5.xlarge"]

# Mixed (for Karpenter base)
node_group_instance_types = ["t3.medium", "m5.large"]
```

#### Capacity Types

```hcl
# On-Demand (production)
node_group_capacity_type = "ON_DEMAND"

# Spot (cost optimization, fault-tolerant workloads)
node_group_capacity_type = "SPOT"
```

### Access Configuration

#### Authentication Modes

| Mode                 | Description                      | Use Case        |
| -------------------- | -------------------------------- | --------------- |
| `API`                | IAM-only access (new model)      | **Recommended** |
| `API_AND_CONFIG_MAP` | Both IAM and aws-auth ConfigMap  | Migration       |
| `CONFIG_MAP`         | aws-auth ConfigMap only (legacy) | Legacy clusters |

#### Access Entries

```hcl
# Grant admin access to IAM roles/users
cluster_admin_principals = {
  admin_user_1 = "arn:aws:iam::123456789012:user/admin1"
  admin_user_2 = "arn:aws:iam::123456789012:user/admin2"
  admin_role   = "arn:aws:iam::123456789012:role/admin-role"
}

cluster_admin_kubernetes_groups = ["system:masters"]
cluster_admin_policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
```

---

## Outputs

| Output                               | Type     | Description                             |
| ------------------------------------ | -------- | --------------------------------------- |
| `cluster_id`                         | `string` | EKS cluster ID                          |
| `cluster_name`                       | `string` | EKS cluster name                        |
| `cluster_arn`                        | `string` | EKS cluster ARN                         |
| `cluster_endpoint`                   | `string` | API server endpoint URL                 |
| `cluster_certificate_authority_data` | `string` | Base64-encoded CA certificate           |
| `cluster_version`                    | `string` | Kubernetes version                      |
| `cluster_platform_version`           | `string` | EKS platform version                    |
| `cluster_status`                     | `string` | Cluster status (ACTIVE, CREATING, etc.) |
| `cluster_oidc_issuer_url`            | `string` | OIDC issuer URL (for IRSA)              |
| `cluster_oidc_provider_arn`          | `string` | OIDC provider ARN                       |
| `node_group_id`                      | `string` | Node group ID                           |
| `node_group_name`                    | `string` | Node group name                         |
| `node_group_arn`                     | `string` | Node group ARN                          |
| `node_group_status`                  | `string` | Node group status                       |
| `node_group_resources`               | `list`   | Auto Scaling Group ARNs                 |
| `aws_account_id`                     | `string` | AWS account ID                          |
| `aws_region`                         | `string` | AWS region                              |

### Using Outputs

```hcl
# Configure kubectl
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${module.eks.aws_region}"
  }
}

# Pass to Karpenter module
module "karpenter" {
  source = "../karpenter"

  cluster_name               = module.eks.cluster_name
  cluster_endpoint           = module.eks.cluster_endpoint
  cluster_ca_certificate     = module.eks.cluster_certificate_authority_data
}

# Get OIDC URL for IRSA
output "oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}
```

---

## EKS Access Management

### Access Entry Types

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS Access Management                         │
└─────────────────────────────────────────────────────────────────┘

Authentication Mode: API (Recommended)
├─ Access Entries (IAM-based)
│  ├─ Standard Access Entry
│  │  └─ Associates IAM principal with Kubernetes groups
│  └─ EC2 Linux Access Entry
│     └─ For nodegroup IAM roles (automatic)

Authentication Mode: CONFIG_MAP (Legacy)
└─ aws-auth ConfigMap
   └─ Deprecated, use Access Entries instead
```

### Configuring Access

```hcl
# Grant cluster admin access
cluster_admin_principals = {
  # IAM users
  admin_user = "arn:aws:iam::123456789012:user/admin"

  # IAM roles (for CI/CD)
  github_actions_role = "arn:aws:iam::123456789012:role/github-actions"

  # IAM roles (for developers)
  developer_role = "arn:aws:iam::123456789012:role/developer-access"
}

# Kubernetes groups
cluster_admin_kubernetes_groups = ["system:masters"]

# Policy ARN
cluster_admin_policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
```

### Verifying Access

```bash
# List access entries
aws eks list-access-entries --cluster-name finishline-prod-eks

# Describe access entry
aws eks describe-access-entry \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::123456789012:user/admin

# List access policy associations
aws eks list-access-policies \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::123456789012:user/admin
```

---

## IRSA (IAM Roles for Service Accounts)

### Overview

IRSA allows Kubernetes pods to assume IAM roles, providing fine-grained AWS permissions without using node-level credentials.

### IRSA Setup Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    IRSA Configuration Flow                       │
└─────────────────────────────────────────────────────────────────┘

1. Security Module creates OIDC Provider
   └─ Trust relationship with EKS cluster

2. Security Module creates IAM Role
   └─ Trust: OIDC provider + service account subject

3. EKS Module provides OIDC URL
   └─ cluster_oidc_issuer_url output

4. Kubernetes Service Account annotated
   └─ eks.amazonaws.com/role-arn: <IAM role ARN>

5. Pod assumes IAM role
   └─ Via web identity token
```

### Configuring IRSA

```hcl
# Step 1: Security Module - Create OIDC and IAM roles
module "iam" {
  source = "../../security/iam"

  is_eks_cluster_enabled = true
  eks_oidc_url           = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint        = data.tls_certificate.eks.thumbs[0]

  # EBS CSI Driver IRSA
  is_ebs_csi_driver_enabled = true
  ebs_csi_driver_namespace  = "kube-system"
  ebs_csi_driver_service_account = "ebs-csi-controller-sa"
}

# Step 2: EKS Module - Pass IAM role for EBS CSI Driver
module "eks" {
  source = "../../compute/eks"

  # ... other configuration

  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn
}

# Step 3: Kubernetes - Annotate service account
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: ebs-csi-controller-sa
#   namespace: kube-system
#   annotations:
#     eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/ebs-csi-driver-role
```

### Getting OIDC Information

```bash
# Get OIDC issuer URL
aws eks describe-cluster --name finishline-prod-eks \
  --query "cluster.identity.oidc.issuer" --output text

# Get OIDC thumbprint
openssl s_client -showcerts -servername oidc.eks.us-east-1.amazonaws.com \
  -connect oidc.eks.us-east-1.amazonaws.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout -inform pem | \
  awk -F= '{gsub(/:/, "", $2); print tolower($2)}'
```

---

## Tags

The module automatically applies the following tags to all resources:

| Tag Key       | Value                                         | Purpose                     |
| ------------- | --------------------------------------------- | --------------------------- |
| `Name`        | `{project_name}-{environment}-eks-{resource}` | Resource identification     |
| `Project`     | `{project_name}`                              | Cost allocation             |
| `Environment` | `{environment}`                               | Environment identification  |
| `Managed_By`  | `{managed_by}`                                | Team ownership              |
| `Terraform`   | `true`                                        | Indicates Terraform-managed |

---

## Best Practices

### 1. Use Private Endpoint

```hcl
# ✅ Good: Private endpoint for production
endpoint_private_access = true
endpoint_public_access  = false

# ❌ Bad: Public endpoint exposed
endpoint_public_access = true
public_access_cidrs    = ["0.0.0.0/0"]
```

### 2. Enable All Log Types

```hcl
# ✅ Good: Full logging for production
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]

# ❌ Bad: No logging
cluster_enabled_log_types = []
```

### 3. Use Bottlerocket AMI

```hcl
# ✅ Good: Bottlerocket for security
node_group_ami_type = "BOTTLEROCKET_x86_64"

# ❌ Bad: Generic AL2
node_group_ami_type = "AL2_x86_64"
```

### 4. Multi-AZ Deployment

```hcl
# From VPC module - ensure subnets span AZs
module "vpc" {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# EKS will distribute nodes across AZs
module "eks" {
  subnets = module.vpc.private_subnets_ids
}
```

### 5. Use Access Entries (API Mode)

```hcl
# ✅ Good: API mode with access entries
authentication_mode = "API"
cluster_admin_principals = {
  admin = "arn:aws:iam::ACCOUNT:user/admin"
}

# ❌ Bad: Legacy CONFIG_MAP mode
authentication_mode = "CONFIG_MAP"
```

### 6. Configure Upgrade Policy

```hcl
# ✅ Good: Enable upgrade policy for production
enable_upgrade_policy       = true
upgrade_policy_support_type = "STANDARD"

# ❌ Bad: No upgrade policy
enable_upgrade_policy = false
```

---

## Examples

### Development Cluster

```hcl
module "eks_dev" {
  source = "./modules/compute/eks"

  project_name  = "finishline"
  environment   = "dev"
  managed_by    = "dev-team"
  aws_region    = "us-east-1"
  cluster_name  = "finishline-dev-eks"

  # IAM roles
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  node_group_role_arn  = module.iam.eks_nodegroup_role_arn

  # Networking
  subnets            = module.vpc.private_subnets_ids
  security_group_ids = [module.eks_sg.security_group_id]

  # Minimal configuration for dev
  cluster_version = "1.30"
  is_eks_cluster_enabled = true

  endpoint_private_access = true
  endpoint_public_access  = true  # Allow public access for dev
  public_access_cidrs     = ["0.0.0.0/0"]

  cluster_enabled_log_types = ["api"]  # Minimal logging

  authentication_mode = "API"
  bootstrap_cluster_creator_admin_permissions = true

  # Small node group for cost
  is_eks_nodegroup_enabled = true
  node_group_name          = "dev-nodes"
  node_group_instance_types = ["t3.small"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_disk_size     = 30

  node_group_scaling_config = {
    desired_size = 1
    min_size     = 0  # Can scale to zero
    max_size     = 2
  }

  node_group_update_config = {
    max_unavailable = 1
  }
}
```

### Production Cluster

```hcl
module "eks_prod" {
  source = "./modules/compute/eks"

  project_name  = "finishline"
  environment   = "prod"
  managed_by    = "platform-team"
  aws_region    = "us-east-1"
  cluster_name  = "finishline-prod-eks"

  # IAM roles
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  node_group_role_arn  = module.iam.eks_nodegroup_role_arn

  # Networking
  subnets            = module.vpc.private_subnets_ids
  security_group_ids = [module.eks_sg.security_group_id]

  # Production configuration
  cluster_version = "1.30"
  is_eks_cluster_enabled = true

  endpoint_private_access = true
  endpoint_public_access  = false  # Private only
  public_access_cidrs     = []

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  authentication_mode = "API"
  bootstrap_cluster_creator_admin_permissions = true

  # Upgrade policy
  enable_upgrade_policy       = true
  upgrade_policy_support_type = "STANDARD"

  # Access management
  cluster_admin_principals = {
    platform_admin = "arn:aws:iam::ACCOUNT:role/platform-admin"
    oncall_admin   = "arn:aws:iam::ACCOUNT:role/oncall-access"
  }
  cluster_admin_kubernetes_groups = ["system:masters"]
  cluster_admin_policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"

  # Base node group (Karpenter handles scaling)
  is_eks_nodegroup_enabled = true
  node_group_name          = "base-nodes"
  node_group_ami_type      = "BOTTLEROCKET_x86_64"
  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_disk_size     = 50

  node_group_scaling_config = {
    desired_size = 2
    min_size     = 2  # HA minimum
    max_size     = 4
  }

  node_group_update_config = {
    max_unavailable = 1
  }

  # EBS CSI Driver with IRSA
  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn
}
```

---

## Troubleshooting

### Issue: Cluster Creation Fails

**Symptoms**: `AccessDenied: EKS cannot assume role`

**Resolution**:

```bash
# Verify IAM role exists
aws iam get-role --role-name finishline-prod-eks-cluster-role

# Check trust policy
aws iam get-role --role-name finishline-prod-eks-cluster-role \
  --query 'Role.AssumeRolePolicyDocument' --output json

# Verify policy attachment
aws iam list-attached-role-policies \
  --role-name finishline-prod-eks-cluster-role

# Expected: AmazonEKSClusterPolicy attached
```

### Issue: Nodes Not Joining Cluster

**Symptoms**: Node group shows `Creating` but nodes don't join

**Resolution**:

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name finishline-prod-eks \
  --nodegroup-name managed-nodes

# Check node IAM role
aws iam get-role --role-name finishline-prod-eks-nodegroup-role

# Verify trust policy allows EC2
aws iam get-role --role-name finishline-prod-eks-nodegroup-role \
  --query 'Role.AssumeRolePolicyDocument' --output json

# Check security group allows node communication
aws ec2 describe-security-groups \
  --filters "Name=group-id,Values=sg-xxx"
```

### Issue: Cannot Access API Server

**Symptoms**: `kubectl` times out or connection refused

**Resolution**:

```bash
# Check endpoint access
aws eks describe-cluster --name finishline-prod-eks \
  --query 'cluster.resourcesVpcConfig.{endpointPrivateAccess:endpointPrivateAccess,endpointPublicAccess:endpointPublicAccess}'

# If private only, ensure you're in the VPC
# If public, check public_access_cidrs

# Update kubeconfig
aws eks update-kubeconfig --name finishline-prod-eks

# Test connection
kubectl cluster-info
```

### Issue: OIDC Provider Not Created

**Symptoms**: IRSA doesn't work, OIDC outputs empty

**Resolution**:

```bash
# Get OIDC issuer URL from cluster
aws eks describe-cluster --name finishline-prod-eks \
  --query 'cluster.identity.oidc.issuer' --output text

# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# If missing, create manually or re-apply security/iam module
```

---

## AWS CLI Commands

### Cluster Management

```bash
# List EKS clusters
aws eks list-clusters

# Describe cluster
aws eks describe-cluster --name finishline-prod-eks

# Get cluster status
aws eks describe-cluster --name finishline-prod-eks \
  --query 'cluster.{name:name,status:status,version:version}'

# Update kubeconfig
aws eks update-kubeconfig --name finishline-prod-eks --region us-east-1
```

### Node Group Management

```bash
# List node groups
aws eks list-nodegroups --cluster-name finishline-prod-eks

# Describe node group
aws eks describe-nodegroup \
  --cluster-name finishline-prod-eks \
  --nodegroup-name managed-nodes

# Get node group status
aws eks describe-nodegroup \
  --cluster-name finishline-prod-eks \
  --nodegroup-name managed-nodes \
  --query 'nodegroup.{status:status,desiredSize:scalingConfig.desiredSize}'

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name finishline-prod-eks \
  --nodegroup-name managed-nodes \
  --scaling-config desiredSize=3,minSize=2,maxSize=5
```

### Access Management

```bash
# List access entries
aws eks list-access-entries --cluster-name finishline-prod-eks

# Describe access entry
aws eks describe-access-entry \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::ACCOUNT:user/admin

# List access policy associations
aws eks list-access-policies \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::ACCOUNT:user/admin

# Create access entry
aws eks create-access-entry \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::ACCOUNT:user/newuser \
  --kubernetes-groups system:masters

# Associate access policy
aws eks associate-access-policy \
  --cluster-name finishline-prod-eks \
  --principal-arn arn:aws:iam::ACCOUNT:user/newuser \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### OIDC/IRSA

```bash
# Get OIDC issuer URL
aws eks describe-cluster --name finishline-prod-eks \
  --query 'cluster.identity.oidc.issuer' --output text

# List OIDC providers
aws iam list-open-id-connect-providers

# Describe OIDC provider
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXX
```

---

## Module Structure

```
eks/
├── main.tf          # EKS cluster and node group resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── addons.tf        # EKS addons configuration
├── data.tf          # Data sources (caller identity, region)
├── locals.tf        # Local values (tags, etc.)
└── README.md        # This documentation
```

### Resources Created

| Resource                                           | Type               | Conditional                                           |
| -------------------------------------------------- | ------------------ | ----------------------------------------------------- |
| `aws_eks_cluster.eks`                              | EKS Cluster        | `is_eks_cluster_enabled`                              |
| `aws_eks_node_group.nodegroup`                     | Node Group         | `is_eks_nodegroup_enabled`                            |
| `aws_eks_access_entry.cluster_admins`              | Access Entry       | `is_eks_cluster_enabled`                              |
| `aws_eks_access_entry.nodegroup`                   | Node Access Entry  | `is_eks_cluster_enabled && node_group_role_arn != ""` |
| `aws_eks_access_policy_association.cluster_admins` | Policy Association | `is_eks_cluster_enabled`                              |

---

## Related Documentation

- [Compute Modules Parent README](../README.md) - Overview of all compute modules
- [Karpenter Module](../karpenter/README.md) - Node autoscaling
- [Jumphost Module](../jumphost/README.md) - Bastion host access
- [Security IAM Module](../../security/iam/README.md) - IAM roles and OIDC
- [Networking VPC Module](../../networking/vpc/README.md) - VPC and subnets
- [Networking SG Module](../../networking/sg/README.md) - Security groups
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
