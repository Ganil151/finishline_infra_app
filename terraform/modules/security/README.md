# Security Modules

This directory contains the security infrastructure modules for the Finishline project on AWS. These modules provide identity and access management (IAM), SSH key pair management, and security controls for EKS clusters, Karpenter node provisioning, and workload identity.

**These security modules work in conjunction with the [Networking Modules](../networking/README.md)** to provide a complete, secure infrastructure foundation. The networking modules handle network isolation, traffic control, and load balancing, while the security modules handle identity, access management, and authentication.

---

## Table of Contents

- [Overview](#overview)
- [Integration with Networking Modules](#integration-with-networking-modules)
- [Module Architecture](#module-architecture)
- [Modules Summary](#modules-summary)
  - [IAM Module](#iam-module)
  - [Key Pair Module](#key-pair-module)
- [Module Relationships](#module-relationships)
- [Security Architecture](#security-architecture)
- [Complete Usage Example](#complete-usage-example)
- [IRSA (IAM Roles for Service Accounts)](#irsa-iam-roles-for-service-accounts)
- [Karpenter IAM Integration](#karpenter-iam-integration)
- [Best Practices](#best-practices)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Related Documentation](#related-documentation)

---

## Overview

The security modules provide production-ready AWS identity and access management infrastructure following AWS security best practices and the Well-Architected Framework. Together, they deliver:

| Capability             | Description                                                          |
| ---------------------- | -------------------------------------------------------------------- |
| **IAM Roles**          | EKS cluster, nodegroup, and OIDC roles with least-privilege policies |
| **IRSA Support**       | IAM Roles for Kubernetes Service Accounts for fine-grained access    |
| **Karpenter IAM**      | Controller and node roles for automated EC2 provisioning             |
| **EBS CSI Driver**     | IAM role for dynamic persistent volume provisioning                  |
| **SSH Key Pairs**      | RSA 4096-bit key generation and secure management                    |
| **S3 Access Policies** | Scoped bucket access for Kubernetes workloads                        |

### Module Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Modules                              │
│                                                                  │
│  ┌─────────────┐                                                │
│  │  Key Pair   │  (Independent - SSH Access)                   │
│  └─────────────┘                                                │
│                                                                  │
│  ┌─────────────┐                                                │
│  │     IAM     │                                                │
│  │  (Identity) │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  IAM Components:                                         │    │
│  │  • EKS Cluster Role                                      │    │
│  │  • EKS Nodegroup Role                                    │    │
│  │  • OIDC Provider                                         │    │
│  │  • OIDC Role (for IRSA)                                  │    │
│  │  • Karpenter Controller Role                             │    │
│  │  • Karpenter Node Role                                   │    │
│  │  • EBS CSI Driver Role                                   │    │
│  │  • S3 Access Policies                                    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Architecture

### High-Level Architecture

```
                                    ┌─────────────────────────┐
                                    │   Kubernetes Cluster    │
                                    │        (EKS)            │
                                    └───────────┬─────────────┘
                                                │
                        ┌───────────────────────┼───────────────────────┐
                        │                       │                       │
                        ▼                       ▼                       ▼
            ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
            │  Karpenter          │ │  EBS CSI Driver     │ │  Custom Workload    │
            │  Controller         │ │  Controller         │ │  Service Account    │
            │  Service Account    │ │  Service Account    │ │                     │
            │  (IRSA)             │ │  (IRSA)             │ │  (IRSA)             │
            └─────────┬───────────┘ └─────────┬───────────┘ └─────────┬───────────┘
                      │                       │                       │
                      ▼                       ▼                       ▼
            ┌─────────────────────────────────────────────────────────────────────┐
            │                    IAM Module (IRSA Configuration)                   │
            │                                                                      │
            │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
            │  │ Karpenter        │  │ EBS CSI Driver   │  │ OIDC Role        │   │
            │  │ Controller Role  │  │ Role             │  │ (Generic)        │   │
            │  └──────────────────┘  └──────────────────┘  └──────────────────┘   │
            │                                                                      │
            │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
            │  │ Karpenter        │  │ S3 Access        │  │ OIDC Provider    │   │
            │  │ Node Role        │  │ Policy           │  │                  │   │
            │  └──────────────────┘  └──────────────────┘  └──────────────────┘   │
            └─────────────────────────────────────────────────────────────────────┘
                      │                       │                       │
                      ▼                       ▼                       ▼
            ┌─────────────────────────────────────────────────────────────────────┐
            │                    AWS Services                                      │
            │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
            │  │    EC2       │  │     S3       │  │     EBS      │              │
            │  │  Instances   │  │   Buckets    │  │   Volumes    │              │
            │  └──────────────┘  └──────────────┘  └──────────────┘              │
            └─────────────────────────────────────────────────────────────────────┘

            ┌─────────────────────────────────────────────────────────────────────┐
            │                    Key Pair Module (SSH Access)                      │
            │                                                                      │
            │  ┌──────────────────┐         ┌──────────────────┐                  │
            │  │  RSA 4096-bit    │────────►│  AWS Key Pair    │                  │
            │  │  Private Key     │         │  (Public Key)    │                  │
            │  │  (Local File)    │         │                  │                  │
            │  └──────────────────┘         └──────────────────┘                  │
            │                                        │                             │
            │                                        ▼                             │
            │                              ┌──────────────────┐                   │
            │                              │  EC2 Instances   │                   │
            │                              │  SSH Access      │                   │
            │                              └──────────────────┘                   │
            └─────────────────────────────────────────────────────────────────────┘
```

### IAM Trust Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         IAM Trust Relationship Flow                              │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │     Kubernetes Service Account      │
                    │  namespace: karpenter               │
                    │  name: karpenter-controller         │
                    └─────────────────┬───────────────────┘
                                      │
                                      │ 1. Pod requests AWS credentials
                                      ▼
                    ┌─────────────────────────────────────┐
                    │     EKS OIDC Provider               │
                    │  (arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXX) │
                    └─────────────────┬───────────────────┘
                                      │
                                      │ 2. Trust Policy Validation
                                      │    - sub: system:serviceaccount:namespace:name
                                      │    - aud: sts.amazonaws.com
                                      ▼
                    ┌─────────────────────────────────────┐
                    │     IAM Role (IRSA)                 │
                    │  - Trust: OIDC Provider             │
                    │  - Permissions: EC2, SSM, Pricing   │
                    └─────────────────┬───────────────────┘
                                      │
                                      │ 3. AssumeRoleWithWebIdentity
                                      ▼
                    ┌─────────────────────────────────────┐
                    │     AWS STS                         │
                    │  Temporary Credentials              │
                    │  - Access Key ID                    │
                    │  - Secret Access Key                │
                    │  - Session Token                    │
                    └─────────────────┬───────────────────┘
                                      │
                                      │ 4. Credentials injected to Pod
                                      ▼
                    ┌─────────────────────────────────────┐
                    │     AWS SDK in Pod                  │
                    │  Automatic credential discovery     │
                    └─────────────────────────────────────┘
```

---

## Modules Summary

### IAM Module

**Path:** [`./iam/`](./iam/README.md)

**Purpose:** Creates and manages IAM roles, policies, and OIDC configuration for EKS clusters, Karpenter, and workload identity.

**Key Resources:**

| Resource                          | Description                                                   |
| --------------------------------- | ------------------------------------------------------------- |
| `aws_iam_role`                    | EKS cluster role, nodegroup role, OIDC roles, Karpenter roles |
| `aws_iam_role_policy_attachment`  | Managed policy attachments for roles                          |
| `aws_iam_openid_connect_provider` | OIDC provider for IRSA                                        |
| `aws_iam_policy`                  | Custom policies (S3 access, Karpenter controller)             |
| `aws_iam_instance_profile`        | Instance profile for Karpenter nodes                          |
| `random_integer`                  | Random suffix for unique resource naming                      |

**Primary Outputs:**

```hcl
# EKS Cluster
eks_cluster_role_arn          # ARN of EKS cluster IAM role
eks_cluster_role_name         # Name of EKS cluster IAM role

# EKS Nodegroup
eks_nodegroup_role_arn        # ARN of EKS nodegroup IAM role
eks_nodegroup_role_name       # Name of EKS nodegroup IAM role

# OIDC Provider
eks_oidc_provider_arn         # ARN of OIDC provider
eks_oidc_provider_url         # URL of OIDC provider

# OIDC Role
eks_oidc_role_arn             # ARN of OIDC IAM role
eks_oidc_role_name            # Name of OIDC IAM role

# S3 Access
s3_oidc_policy_arn            # ARN of S3 access policy
s3_oidc_policy_name           # Name of S3 access policy

# Karpenter Controller
karpenter_controller_role_arn # ARN of Karpenter controller role
karpenter_controller_role_name # Name of Karpenter controller role
karpenter_controller_policy_arn # ARN of Karpenter controller policy

# Karpenter Node
karpenter_node_role_arn       # ARN of Karpenter node IAM role
karpenter_node_role_name      # Name of Karpenter node IAM role
karpenter_node_instance_profile_arn  # ARN of instance profile
karpenter_node_instance_profile_name # Name of instance profile

# Service Account IAM (IRSA)
karpenter_service_account_iam # Map with role ARN, namespace, service account
eks_oidc_service_account_iam  # Map for generic OIDC service account IAM

# EBS CSI Driver
ebs_csi_driver_role_arn       # ARN of EBS CSI driver IAM role
ebs_csi_driver_role_name      # Name of EBS CSI driver IAM role
```

**Use When:**

- Setting up EKS cluster IAM roles
- Configuring IRSA for Kubernetes service accounts
- Enabling Karpenter for node autoscaling
- Granting S3 access to Kubernetes workloads
- Setting up EBS CSI driver for dynamic volumes

---

### Key Pair Module

**Path:** [`./key_pair/`](./key_pair/README.md)

**Purpose:** Generates RSA 4096-bit SSH key pairs and registers the public key with AWS EC2 for instance access.

**Key Resources:**

| Resource          | Description                                |
| ----------------- | ------------------------------------------ |
| `tls_private_key` | Generates RSA 4096-bit private key         |
| `aws_key_pair`    | Registers public key with AWS EC2          |
| `local_file`      | Saves private key to local filesystem      |
| `null_resource`   | Outputs security warnings and instructions |

**Primary Outputs:**

```hcl
key_name            # Name of the key pair
key_pair_id         # Key pair ID
private_key_path    # Local path where private key is stored
public_key          # Public key in OpenSSH format
```

**Use When:**

- Creating SSH access for EC2 instances
- Setting up bastion/jumphost access
- Managing SSH keys for EKS nodes (if not using SSM)
- Secure key generation with proper file permissions

---

## Module Relationships

### Dependency Chain

```
┌──────────────────────────────────────────────────────────────────┐
│                     Module Dependency Graph                       │
└──────────────────────────────────────────────────────────────────┘

                    ┌─────────────┐
                    │  Key Pair   │
                    │   Module    │
                    │ (Independent)│
                    └─────────────┘

                    ┌─────────────┐
                    │     IAM     │
                    │   Module    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
        ┌───────────┐ ┌───────────┐ ┌───────────┐
        │   EKS     │ │ Karpenter │ │   EKS     │
        │  Cluster  │ │  Nodes    │ │  Nodes    │
        │   Role    │ │   Role    │ │  Nodegroup│
        └───────────┘ └───────────┘ └───────────┘
              │            │            │
              └────────────┴────────────┘
                           │
                           ▼
                    ┌─────────────────┐
                    │  OIDC Provider  │
                    │   (for IRSA)    │
                    └────────┬────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
                ▼            ▼            ▼
          ┌───────────┐ ┌───────────┐ ┌───────────┐
          │ Karpenter │ │  EBS CSI  │ │  Custom   │
          │ Controller│ │  Driver   │ │ Workloads │
          └───────────┘ └───────────┘ └───────────┘
```

### Data Flow Between Modules

```hcl
# Step 1: Create IAM roles for EKS
module "iam" {
  source = "./modules/security/iam"

  project_name             = "finishline"
  environment              = "prod"
  managed_by               = "platform-team"
  aws_region               = "us-west-2"
  cluster_name             = "finishline-prod-eks"

  # Enable EKS cluster role
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true

  # OIDC configuration (populated after EKS creation)
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]
  eks_oidc_subject         = "system:serviceaccount:karpenter:karpenter-controller"
  eks_oidc_namespace       = "karpenter"
  eks_oidc_service_account = "karpenter-controller"

  # Enable Karpenter
  is_karpenter_enabled     = true
  karpenter_cluster_name   = "finishline-prod-eks"
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"

  # Enable EBS CSI Driver
  is_ebs_csi_driver_enabled = true
}

# Step 2: Create EKS Cluster (uses IAM role)
resource "aws_eks_cluster" "main" {
  name     = "${module.iam.cluster_name}"
  role_arn = module.iam.eks_cluster_role_arn

  # ... cluster configuration
}

# Step 3: Create EKS Nodegroup (uses nodegroup role)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "managed-nodes"
  node_role_arn   = module.iam.eks_nodegroup_role_arn
  subnet_ids      = module.vpc.private_subnets_ids

  # ... nodegroup configuration
}

# Step 4: Create Key Pair for SSH access
module "key_pair" {
  source = "./modules/security/key_pair"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"

  key_name        = "finishline-prod-ssh-key"
  key_algorithm   = "RSA"
  rsa_bits        = 4096
}

# Step 5: Launch EC2 instances with key pair
resource "aws_instance" "bastion" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = module.key_pair.key_name

  # ... instance configuration
}
```

### Shared Variables Pattern

```hcl
# Common variables used across all modules
locals {
  project_name = "finishline"
  environment  = "prod"
  managed_by   = "platform-team"
  aws_region   = "us-west-2"
  cluster_name = "finishline-prod-eks"
}

# IAM Module
module "iam" {
  source         = "./modules/security/iam"
  project_name   = local.project_name
  environment    = local.environment
  managed_by     = local.managed_by
  aws_region     = local.aws_region
  cluster_name   = local.cluster_name
  # ...
}

# Key Pair Module
module "key_pair" {
  source         = "./modules/security/key_pair"
  project_name   = local.project_name
  environment    = local.environment
  managed_by     = local.managed_by
  aws_region     = local.aws_region
  # ...
}
```

---

## Security Architecture

### IAM Security Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1: AWS Account Boundary                                        │
│ - Root account protection                                            │
│ - Service Control Policies (SCPs)                                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│ Layer 2: IAM Policies (Permissions)                                  │
│ - Managed policies (AWS managed, Customer managed)                   │
│ - Inline policies                                                    │
│ - Permission boundaries                                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│ Layer 3: IAM Roles (Trust Relationships)                             │
│ - Role trust policies (who can assume)                               │
│ - Temporary credentials via STS                                      │
│ - Session duration limits                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│ Layer 4: IRSA (Kubernetes Integration)                               │
│ - Service account annotations                                        │
│ - OIDC provider trust                                                │
│ - Namespace isolation                                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────────┐
│ Layer 5: Resource-Level Permissions                                  │
│ - S3 bucket policies                                                 │
│ - KMS key policies                                                   │
│ - Security group rules                                               │
└─────────────────────────────────────────────────────────────────────┘
```

### Principle of Least Privilege

The IAM module implements least-privilege access:

| Component                | Permissions                                                                               | Scope                        |
| ------------------------ | ----------------------------------------------------------------------------------------- | ---------------------------- |
| **EKS Cluster Role**     | `AmazonEKSClusterPolicy`                                                                  | Cluster management only      |
| **EKS Nodegroup Role**   | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` | Node operations only         |
| **Karpenter Controller** | EC2 run/terminate, IAM passRole, SSM parameters                                           | Scoped to tagged resources   |
| **Karpenter Node Role**  | EKS worker + SSM Managed Instance Core                                                    | Node operations + SSM access |
| **EBS CSI Driver**       | `AmazonEBSCSIDriverPolicy`                                                                | EBS volume management only   |
| **S3 OIDC Policy**       | GetObject, PutObject, DeleteObject                                                        | Single bucket/prefix only    |

---

## Complete Usage Example

### Production EKS with Karpenter and IRSA

```hcl
# ============================================================
# Provider and Terraform Configuration
# ============================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# ============================================================
# Local Variables
# ============================================================

locals {
  project_name   = "finishline"
  environment    = "prod"
  managed_by     = "platform-team"
  aws_region     = "us-west-2"
  cluster_name   = "finishline-prod-eks"

  # Karpenter configuration
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"

  # EBS CSI Driver configuration
  ebs_csi_driver_namespace = "kube-system"
  ebs_csi_driver_service_account = "ebs-csi-controller-sa"

  # S3 bucket for application data
  s3_bucket_arn = "arn:aws:s3:::finishline-prod-data"
  s3_prefix     = "app-data"
  s3_access_type = "readwrite"
}

# ============================================================
# Get OIDC Thumbprint (required for OIDC provider)
# ============================================================

data "tls_certificate" "eks" {
  url = "https://oidc.eks.${local.aws_region}.amazonaws.com"
}

# ============================================================
# IAM Module - EKS and Karpenter Roles
# ============================================================

module "iam" {
  source = "./modules/security/iam"

  # Required variables
  project_name             = local.project_name
  environment              = local.environment
  managed_by               = local.managed_by
  aws_region               = local.aws_region
  cluster_name             = local.cluster_name

  # EKS Cluster configuration
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true

  # OIDC configuration (use EKS cluster outputs)
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]
  eks_oidc_namespace       = local.karpenter_namespace
  eks_oidc_service_account = local.karpenter_service_account
  eks_oidc_subject         = "system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_service_account}"

  # Karpenter configuration
  is_karpenter_enabled     = true
  karpenter_cluster_name   = local.cluster_name
  karpenter_namespace      = local.karpenter_namespace
  karpenter_service_account = local.karpenter_service_account
  karpenter_node_instance_profile_name = ""  # Use module-created profile

  # EBS CSI Driver configuration
  is_ebs_csi_driver_enabled = true
  ebs_csi_driver_namespace = local.ebs_csi_driver_namespace
  ebs_csi_driver_service_account = local.ebs_csi_driver_service_account

  # S3 access for workloads
  s3_bucket_arn            = local.s3_bucket_arn
  s3_prefix                = local.s3_prefix
  s3_access_type           = local.s3_access_type

  # Naming
  name_suffix              = ""  # Empty for deterministic naming
  enable_deterministic_naming = true
}

# ============================================================
# EKS Cluster
# ============================================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = module.iam.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = module.vpc.private_subnets_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = module.iam.eks_cluster_role_name
}

# ============================================================
# Key Pair Module - SSH Access
# ============================================================

module "key_pair" {
  source = "./modules/security/key_pair"

  project_name    = local.project_name
  environment     = local.environment
  managed_by      = local.managed_by
  aws_region      = local.aws_region

  key_name        = "${local.project_name}-${local.environment}-ssh-key"
  key_algorithm   = "RSA"
  rsa_bits        = 4096
}

# ============================================================
# Bastion Host (using key pair)
# ============================================================

resource "aws_instance" "bastion" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = module.key_pair.key_name

  subnet_id              = module.vpc.public_subnets_ids[0]
  vpc_security_group_ids = [module.bastion_sg.security_group_id]

  tags = {
    Name        = "${local.project_name}-${local.environment}-bastion"
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = local.managed_by
  }
}
```

---

## IRSA (IAM Roles for Service Accounts)

### What is IRSA?

IRSA (IAM Roles for Service Accounts) allows Kubernetes service accounts to assume IAM roles, providing fine-grained AWS permissions to pods without using node-level credentials.

### How IRSA Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        IRSA Flow Diagram                                 │
└─────────────────────────────────────────────────────────────────────────┘

1. Create Kubernetes Service Account
   └─> Annotate with IAM role ARN

2. Create IAM Role with OIDC Trust
   └─> Trust policy: OIDC provider + service account subject

3. Deploy Pod with Service Account
   └─> Pod inherits service account

4. Pod Requests AWS Credentials
   └─> AWS SDK discovers IRSA environment variables

5. EKS Injects Web Identity Token
   └─> Token mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token

6. Pod Assumes IAM Role
   └─> STS AssumeRoleWithWebIdentity

7. Pod Receives Temporary Credentials
   └─> Access Key, Secret Key, Session Token
```

### Configuring IRSA with the IAM Module

```hcl
# Step 1: Configure IAM module for IRSA
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_cluster_enabled = true
  eks_oidc_url          = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint       = data.tls_certificate.eks.thumbs[0]

  # Generic OIDC role for custom workloads
  eks_oidc_namespace       = "my-app"
  eks_oidc_service_account = "my-app-sa"
  eks_oidc_subject         = "system:serviceaccount:my-app:my-app-sa"

  # S3 access for the workload
  s3_bucket_arn = "arn:aws:s3:::my-app-bucket"
  s3_prefix     = "data"
  s3_access_type = "readwrite"
}

# Step 2: Create Kubernetes Service Account with annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-app
  annotations:
    eks.amazonaws.com/role-arn: ${module.iam.eks_oidc_role_arn}
---
# Step 3: Deploy Pod using the service account
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: my-app-sa
      containers:
      - name: my-app
        image: my-app:latest
        env:
        - name: AWS_REGION
          value: "us-west-2"
```

### IRSA Environment Variables

When IRSA is configured, EKS automatically injects these environment variables into pods:

```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/my-app-oidc-role
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

The AWS SDK automatically discovers these and uses them for authentication.

---

## Karpenter IAM Integration

### Overview

Karpenter requires two IAM roles:

1. **Controller Role (IRSA)** - For the Karpenter controller to provision EC2 instances
2. **Node Role** - For EC2 instances launched by Karpenter

### Controller Role Permissions

The Karpenter controller role includes permissions for:

| Action                                                 | Resource                                    | Purpose                   |
| ------------------------------------------------------ | ------------------------------------------- | ------------------------- |
| `ec2:RunInstances`, `ec2:CreateFleet`                  | `*`                                         | Launch EC2 instances      |
| `ec2:CreateLaunchTemplate`, `ec2:DeleteLaunchTemplate` | `*`                                         | Manage launch templates   |
| `ec2:Describe*`                                        | `*`                                         | Discover AWS resources    |
| `ec2:CreateTags`                                       | Instance, Volume, Network Interface         | Tag provisioned resources |
| `ec2:TerminateInstances`                               | Instances with `karpenter.sh/discovery` tag | Clean up nodes            |
| `iam:PassRole`                                         | Node role, instance profile                 | Pass role to EC2          |
| `ssm:GetParameter`                                     | `/aws/service/*`                            | Get latest AMI IDs        |
| `pricing:GetProducts`                                  | `*`                                         | Get spot pricing data     |
| `eks:DescribeCluster`                                  | Specific cluster                            | Get cluster details       |

### Node Role Permissions

The Karpenter node role includes:

| Managed Policy                       | Purpose                                 |
| ------------------------------------ | --------------------------------------- |
| `AmazonEKSWorkerNodePolicy`          | EKS node registration and communication |
| `AmazonEKS_CNI_Policy`               | VPC CNI plugin operations               |
| `AmazonEC2ContainerRegistryReadOnly` | Pull container images from ECR          |
| `AmazonSSMManagedInstanceCore`       | SSM Session Manager access              |

### Configuring Karpenter IAM

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  # Enable Karpenter
  is_karpenter_enabled     = true
  is_eks_cluster_enabled   = true
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]

  # Karpenter controller configuration
  karpenter_cluster_name   = local.cluster_name
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"

  # Node configuration
  karpenter_node_instance_profile_name = ""  # Use module-created profile
}

# Outputs for Karpenter Helm chart
output "karpenter_controller_role_arn" {
  value = module.iam.karpenter_controller_role_arn
}

output "karpenter_node_instance_profile_name" {
  value = module.iam.karpenter_node_instance_profile_name
}
```

### Karpenter Helm Values

```yaml
# Karpenter Helm values.yaml
serviceAccount:
  name: karpenter-controller
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/karpenter-controller-role

settings:
  clusterName: finishline-prod-eks
  clusterEndpoint: https://xxx.gr7.us-west-2.eks.amazonaws.com

aws:
  defaultInstanceProfile: karpenter-node-profile
```

---

## Best Practices

### IAM Best Practices

1. **Use IRSA Instead of Node-Level Credentials**
   - Never grant AWS permissions via node IAM roles
   - Use service account-specific roles for each workload

2. **Implement Least Privilege**
   - Scope policies to specific resources (ARNs, tags)
   - Use conditions to restrict access further
   - Avoid `*` resources when possible

3. **Use Managed Policies When Available**
   - AWS managed policies are maintained by AWS
   - Customer managed policies for custom requirements

4. **Enable Deterministic Naming for Production**

   ```hcl
   name_suffix = ""  # Empty for predictable names
   enable_deterministic_naming = true
   ```

5. **Tag Resources for Karpenter Discovery**
   ```hcl
   tags = {
     "karpenter.sh/discovery" = "cluster-name"
   }
   ```

### Key Pair Best Practices

1. **Store Private Keys Securely**

   ```bash
   # Move to secure location
   mv finishline-prod-ssh-key.pem ~/.ssh/

   # Set restrictive permissions
   chmod 400 ~/.ssh/finishline-prod-ssh-key.pem
   ```

2. **Delete from Terraform Directory**
   - Private key is saved in project directory by default
   - Delete after copying to secure location

3. **Use SSM Session Manager When Possible**
   - No SSH keys required
   - Audit logging built-in
   - No open ports needed

4. **Rotate Keys Periodically**
   - Generate new keys every 90 days
   - Update all instances with new key
   - Revoke old key pair

---

## Troubleshooting Guide

### Issue: IRSA Pod Cannot Assume Role

**Symptoms**: Pod receives `AccessDenied` when trying to access AWS services.

**Possible Causes**:

1. Service account annotation missing or incorrect
2. OIDC provider not configured correctly
3. Trust policy doesn't match service account

**Resolution**:

```bash
# Check service account annotation
kubectl get sa my-app-sa -n my-app -o yaml

# Verify annotation matches IAM role
# eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/my-app-role

# Check OIDC provider exists
aws iam list-open-id-connect-providers

# Verify trust policy
aws iam get-role --role-name my-app-role
```

### Issue: Karpenter Cannot Launch Instances

**Symptoms**: Karpenter logs show `AccessDenied` for EC2 operations.

**Possible Causes**:

1. Controller role missing permissions
2. Instance profile not configured
3. Resource tags don't match conditions

**Resolution**:

```bash
# Check controller role policy
aws iam get-role-policy --role-name karpenter-controller-role --policy-name karpenter-controller-policy

# Verify instance profile
aws iam get-instance-profile --instance-profile-name karpenter-node-profile

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

### Issue: SSH Connection Refused

**Symptoms**: Cannot SSH to EC2 instance using key pair.

**Possible Causes**:

1. Wrong key file or permissions
2. Security group blocking SSH
3. Instance not in public subnet

**Resolution**:

```bash
# Check key file permissions
chmod 400 ~/.ssh/finishline-ssh-key.pem

# Verify security group allows SSH
aws ec2 describe-security-groups --group-ids sg-xxx

# Check instance public IP
aws ec2 describe-instances --instance-ids i-xxx

# Test SSH connection
ssh -i ~/.ssh/finishline-ssh-key.pem ec2-user@<public-ip> -v
```

### Issue: S3 Access Denied for Pod

**Symptoms**: Pod cannot access S3 bucket despite IRSA configuration.

**Possible Causes**:

1. S3 policy not attached to OIDC role
2. Bucket policy denies access
3. Wrong bucket ARN or prefix

**Resolution**:

```bash
# Check attached policies
aws iam list-attached-role-policies --role-name oidc-role

# Verify S3 policy
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT:policy/s3-oidc-policy

# Check bucket policy
aws s3api get-bucket-policy --bucket my-bucket
```

---

## AWS CLI Troubleshooting Commands

### IAM Role Inspection

```bash
# List IAM roles with project tag
aws iam list-roles --query "Roles[?contains(Tags[?Key=='Project'].Value, 'finishline')].[RoleName,Arn]" --output table

# Get role details
aws iam get-role --role-name finishline-prod-eks-cluster-role

# Get role trust policy
aws iam get-role --role-name finishline-prod-eks-cluster-role --query "Role.AssumeRolePolicyDocument"

# List attached policies
aws iam list-attached-role-policies --role-name finishline-prod-eks-cluster-role

# Get inline policy
aws iam get-role-policy --role-name finishline-prod-eks-cluster-role --policy-name policy-name
```

### OIDC Provider Inspection

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Get OIDC provider details
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXX

# Get thumbprint
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:xxx --query "ThumbprintList"
```

### Karpenter IAM Resources

```bash
# Get Karpenter controller role
aws iam get-role --role-name karpenter-controller-role

# Get Karpenter controller policy
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT:policy/karpenter-controller-policy

# Get Karpenter node role
aws iam get-role --role-name karpenter-node-role

# Get instance profile
aws iam get-instance-profile --instance-profile-name karpenter-node-profile
```

### Service Account IAM (IRSA)

```bash
# Get service account annotation
kubectl get sa karpenter-controller -n karpenter -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# Verify IAM role trust policy
aws iam get-role --role-name karpenter-controller-role --query 'Role.AssumeRolePolicyDocument' --output json
```

### Key Pair Inspection

```bash
# List EC2 key pairs
aws ec2 describe-key-pairs --query "KeyPairs[*].[KeyName,KeyPairId,KeyFingerprint]" --output table

# Get specific key pair
aws ec2 describe-key-pairs --key-names finishline-prod-ssh-key

# Find instances using key pair
aws ec2 describe-instances --filters "Name=key-name,Values=finishline-prod-ssh-key" --query "Reservations[*].Instances[*].[InstanceId,KeyName,State.Name]" --output table
```

---

## Related Documentation

- [IAM Module](./iam/README.md) - Detailed IAM module documentation
- [Key Pair Module](./key_pair/README.md) - Detailed key pair module documentation
- [Networking Modules](../networking/README.md) - VPC, Security Groups, ALB
- [EKS Cluster Setup](../../docs/Finishline_Karpenter_Project.pdf) - Karpenter project documentation
- [AWS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Karpenter IAM Setup](https://karpenter.sh/docs/getting-started/)
