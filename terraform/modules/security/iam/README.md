# IAM Module

This Terraform module creates and manages AWS Identity and Access Management (IAM) resources for the Finishline EKS infrastructure. It provides IAM roles, policies, OIDC provider configuration, and instance profiles for EKS clusters, Karpenter node provisioning, EBS CSI driver, and custom workloads using IRSA (IAM Roles for Service Accounts).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Required Variables](#required-variables)
  - [Optional Variables](#optional-variables)
  - [EKS Cluster Configuration](#eks-cluster-configuration)
  - [OIDC Configuration](#oidc-configuration)
  - [Karpenter Configuration](#karpenter-configuration)
  - [EBS CSI Driver Configuration](#ebs-csi-driver-configuration)
  - [S3 Access Configuration](#s3-access-configuration)
- [Outputs](#outputs)
- [IRSA (IAM Roles for Service Accounts)](#irsa-iam-roles-for-service-accounts)
- [IAM Policies](#iam-policies)
- [Tags](#tags)
- [Security Best Practices](#security-best-practices)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [AWS CLI Troubleshooting Commands](#aws-cli-troubleshooting-commands)
- [Module Structure](#module-structure)

---

## Overview

The IAM module provides a comprehensive identity and access management solution for EKS workloads with the following capabilities:

- **EKS Cluster IAM Role** - Permissions for EKS control plane operations
- **EKS Nodegroup IAM Role** - Permissions for worker nodes
- **OIDC Provider** - OpenID Connect provider for IRSA
- **OIDC IAM Role** - Generic role for custom service accounts
- **Karpenter Controller Role** - IRSA role for Karpenter controller
- **Karpenter Node Role** - Role for EC2 instances launched by Karpenter
- **Karpenter Instance Profile** - Instance profile for Karpenter nodes
- **EBS CSI Driver Role** - IRSA role for dynamic volume provisioning
- **S3 Access Policy** - Scoped S3 bucket access for workloads

This module follows AWS security best practices including least-privilege access, resource-level permissions, and temporary credentials via STS.

---

## Architecture

### IAM Resource Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              IAM Module Architecture                             │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────────┐
                              │   EKS Cluster       │
                              │                     │
                              └──────────┬──────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
          ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
          │ EKS Cluster Role │ │  Nodegroup Role  │ │  OIDC Provider   │
          │                  │ │                  │ │                  │
          │ - Cluster Policy │ │ - Worker Policy  │ │ - Thumbprint     │
          └──────────────────┘ │ - CNI Policy     │ │ - Client ID      │
                               │ - ECR ReadOnly   │ └────────┬─────────┘
                               └──────────────────┘          │
                                                             │ Trust
                                                             ▼
          ┌──────────────────────────────────────────────────────────────────┐
          │                         IRSA Roles                                │
          │                                                                   │
          │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐  │
          │  │ Karpenter        │ │ EBS CSI Driver   │ │ Custom Workload  │  │
          │  │ Controller Role  │ │ Role             │ │ OIDC Role        │  │
          │  │                  │ │                  │ │                  │  │
          │  │ - EC2 Actions    │ │ - EBS Actions    │ │ - S3 Access      │  │
          │  │ - IAM PassRole   │ │ - Volume Mgmt    │ │ - Custom Policy  │  │
          │  │ - SSM Params     │ │                  │ │                  │  │
          │  └──────────────────┘ └──────────────────┘ └──────────────────┘  │
          └──────────────────────────────────────────────────────────────────┘
                                         │
                                         │ Instance Profile
                                         ▼
          ┌──────────────────────────────────────────────────────────────────┐
          │                      Karpenter Node Role                          │
          │                                                                   │
          │  - AmazonEKSWorkerNodePolicy                                      │
          │  - AmazonEKS_CNI_Policy                                           │
          │  - AmazonEC2ContainerRegistryReadOnly                             │
          │  - AmazonSSMManagedInstanceCore                                   │
          └──────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
          ┌──────────────────────────────────────────────────────────────────┐
          │                      EC2 Instances                                │
          │                  (Provisioned by Karpenter)                       │
          └──────────────────────────────────────────────────────────────────┘
```

### IRSA Trust Relationship Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        IRSA Trust Relationship Flow                              │
└─────────────────────────────────────────────────────────────────────────────────┘

1. Kubernetes Service Account
   namespace: karpenter
   name: karpenter-controller
   annotation: eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/karpenter-role
   │
   ▼
2. Pod Scheduled on Node
   serviceAccountName: karpenter-controller
   │
   ▼
3. EKS Injects Web Identity Token
   Path: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
   │
   ▼
4. AWS SDK Discovers Environment Variables
   AWS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/karpenter-role
   AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
   │
   ▼
5. STS AssumeRoleWithWebIdentity Request
   Role: arn:aws:iam::ACCOUNT:role/karpenter-role
   Token: JWT from EKS OIDC provider
   │
   ▼
6. IAM Validates Trust Policy
   Condition: sub = system:serviceaccount:karpenter:karpenter-controller
   Condition: aud = sts.amazonaws.com
   │
   ▼
7. Temporary Credentials Issued
   AccessKeyId: ASIA...
   SecretAccessKey: ...
   SessionToken: ...
   Expiration: 1 hour
   │
   ▼
8. Pod Uses Credentials for AWS API Calls
   ec2:RunInstances, ssm:GetParameter, etc.
```

---

## Features

| Feature                   | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| **EKS Cluster Role**      | IAM role with `AmazonEKSClusterPolicy` for EKS control plane |
| **EKS Nodegroup Role**    | IAM role with managed policies for worker nodes              |
| **OIDC Provider**         | OpenID Connect provider for IRSA trust relationships         |
| **IRSA Support**          | IAM roles for Kubernetes service accounts                    |
| **Karpenter Integration** | Controller and node roles for automated provisioning         |
| **EBS CSI Driver**        | IAM role for dynamic persistent volume management            |
| **S3 Access Policies**    | Scoped bucket access (read, write, delete) for workloads     |
| **Deterministic Naming**  | Optional random suffix for unique resource names             |
| **Conditional Resources** | Enable/disable features via boolean flags                    |
| **Standardized Tags**     | Consistent tagging for cost allocation and management        |

---

## Usage

### Basic EKS Cluster IAM Setup

```hcl
module "iam" {
  source = "./modules/security/iam"

  # Required variables
  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  cluster_name    = "finishline-prod-eks"

  # Enable EKS cluster role
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true

  # Optional: Karpenter
  is_karpenter_enabled     = false

  # Optional: EBS CSI Driver
  is_ebs_csi_driver_enabled = true
}
```

### Complete EKS with Karpenter and IRSA

```hcl
module "iam" {
  source = "./modules/security/iam"

  # Required variables
  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  cluster_name    = "finishline-prod-eks"

  # EKS Cluster configuration
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true

  # OIDC configuration (get from EKS cluster)
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]
  eks_oidc_namespace       = "karpenter"
  eks_oidc_service_account = "karpenter-controller"
  eks_oidc_subject         = "system:serviceaccount:karpenter:karpenter-controller"

  # Karpenter configuration
  is_karpenter_enabled     = true
  karpenter_cluster_name   = "finishline-prod-eks"
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"
  karpenter_node_instance_profile_name = ""

  # EBS CSI Driver configuration
  is_ebs_csi_driver_enabled = true
  ebs_csi_driver_namespace = "kube-system"
  ebs_csi_driver_service_account = "ebs-csi-controller-sa"

  # S3 access for workloads
  s3_bucket_arn            = "arn:aws:s3:::finishline-prod-data"
  s3_prefix                = "app-data"
  s3_access_type           = "readwrite"

  # Naming
  name_suffix              = ""
  enable_deterministic_naming = true
}
```

---

## Configuration

### Required Variables

| Variable       | Type     | Description                                                          | Example                      |
| -------------- | -------- | -------------------------------------------------------------------- | ---------------------------- |
| `project_name` | `string` | Name of the project. Used in resource naming and tagging.            | `"finishline"`               |
| `environment`  | `string` | Environment name. Determines resource naming and access levels.      | `"dev"`, `"stage"`, `"prod"` |
| `managed_by`   | `string` | Team or department managing this resource. Used for cost allocation. | `"platform-team"`            |
| `aws_region`   | `string` | AWS region where resources will be created.                          | `"us-west-2"`                |
| `cluster_name` | `string` | Name of the EKS cluster. Used in IAM role and policy names.          | `"finishline-prod-eks"`      |

### Optional Variables

| Variable                        | Type          | Default | Description                                                                               |
| ------------------------------- | ------------- | ------- | ----------------------------------------------------------------------------------------- |
| `name_suffix`                   | `string`      | `""`    | Suffix for IAM resource names. Use empty string for deterministic naming.                 |
| `is_eks_cluster_enabled`        | `bool`        | `false` | Whether to enable EKS cluster IAM resources (cluster role, nodegroup role, OIDC).         |
| `is_eks_role_enabled`           | `bool`        | `false` | Whether to enable EKS cluster IAM role specifically.                                      |
| `is_eks_nodegroup_role_enabled` | `bool`        | `false` | Whether to enable EKS nodegroup IAM role with managed policies.                           |
| `is_karpenter_enabled`          | `bool`        | `false` | Whether to enable Karpenter IAM resources (controller role, node role, instance profile). |
| `is_ebs_csi_driver_enabled`     | `bool`        | `true`  | Whether to enable EBS CSI driver IAM role for IRSA.                                       |
| `enable_deterministic_naming`   | `bool`        | `false` | Use deterministic naming without random suffix for production environments.               |
| `computed_tags`                 | `map(string)` | `{}`    | Additional tags to apply to all resources.                                                |

### EKS Cluster Configuration

#### EKS Cluster Role

The EKS cluster role allows the EKS control plane to manage your cluster:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_cluster_enabled = true
  is_eks_role_enabled    = true

  # The module automatically attaches AmazonEKSClusterPolicy
}
```

**Attached Managed Policy:**

- `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy`

**Trust Policy:**

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "eks.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
```

#### EKS Nodegroup Role

The nodegroup role allows EC2 instances to join and communicate with the EKS cluster:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_nodegroup_role_enabled = true
}
```

**Attached Managed Policies:**

- `arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`
- `arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`
- `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`

**Trust Policy:**

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "ec2.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
```

### OIDC Configuration

#### OIDC Provider

The OIDC provider enables IRSA by establishing trust between EKS and IAM:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_cluster_enabled = true

  # Get OIDC URL from EKS cluster
  eks_oidc_url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  # Get thumbprint from TLS certificate
  oidc_thumbprint = data.tls_certificate.eks.thumbs[0]
}
```

**Getting OIDC Information:**

```hcl
# Get OIDC issuer URL from EKS cluster
# Format: https://oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX
aws eks describe-cluster --name cluster-name --query "cluster.identity.oidc.issuer" --output text

# Get thumbprint
openssl s_client -showcerts -servername oidc.eks.REGION.amazonaws.com -connect oidc.eks.REGION.amazonaws.com:443 2>/dev/null | openssl x509 -fingerprint -sha256 -noout -inform pem | awk -F= '{gsub(/:/, "", $2); print tolower($2)}'
```

#### OIDC IAM Role

The OIDC role is a generic role that can be assumed by Kubernetes service accounts:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_cluster_enabled = true
  eks_oidc_url          = "https://oidc.eks.us-west-2.amazonaws.com/id/XXXXXXXXXXXXX"
  oidc_thumbprint       = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # Service account configuration
  eks_oidc_namespace       = "my-app"
  eks_oidc_service_account = "my-app-sa"
  eks_oidc_subject         = "system:serviceaccount:my-app:my-app-sa"

  # S3 access
  s3_bucket_arn  = "arn:aws:s3:::my-bucket"
  s3_prefix      = "data"
  s3_access_type = "readwrite"
}
```

**Trust Policy:**

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX"
			},
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Condition": {
				"StringEquals": {
					"oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX:sub": "system:serviceaccount:my-app:my-app-sa",
					"oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX:aud": "sts.amazonaws.com"
				}
			}
		}
	]
}
```

### Karpenter Configuration

#### Controller Role (IRSA)

The Karpenter controller role allows the Karpenter controller to provision EC2 instances:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_karpenter_enabled     = true
  is_eks_cluster_enabled   = true
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]

  karpenter_cluster_name   = "finishline-prod-eks"
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"
}
```

**Permissions:**

| Action                                                 | Resource                                    | Purpose                      |
| ------------------------------------------------------ | ------------------------------------------- | ---------------------------- |
| `ec2:RunInstances`, `ec2:CreateFleet`                  | `*`                                         | Launch EC2 instances         |
| `ec2:CreateLaunchTemplate`, `ec2:DeleteLaunchTemplate` | `*`                                         | Manage launch templates      |
| `ec2:Describe*`                                        | `*`                                         | Discover AWS resources       |
| `ec2:CreateTags`                                       | Instance, Volume, Network Interface         | Tag provisioned resources    |
| `ec2:TerminateInstances`                               | Instances with `karpenter.sh/discovery` tag | Clean up nodes               |
| `iam:PassRole`                                         | Node role, instance profile                 | Pass role to EC2             |
| `ssm:GetParameter`                                     | `/aws/service/*`                            | Get latest AMI IDs           |
| `pricing:GetProducts`                                  | `*`                                         | Get spot pricing data        |
| `eks:DescribeCluster`                                  | Specific cluster                            | Get cluster details          |
| `iam:GetInstanceProfile`                               | Instance profile                            | Get instance profile details |

#### Node Role

The Karpenter node role is attached to EC2 instances launched by Karpenter:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_karpenter_enabled = true
}
```

**Attached Managed Policies:**

- `arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`
- `arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`
- `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`
- `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`

**Tags:**

```
karpenter.sh/discovery = finishline-prod-eks
```

#### Instance Profile

The instance profile associates the node role with EC2 instances:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_karpenter_enabled = true
  karpenter_node_instance_profile_name = ""  # Use module-created profile
}
```

### EBS CSI Driver Configuration

The EBS CSI driver role allows dynamic provisioning of EBS volumes:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_ebs_csi_driver_enabled = true
  is_eks_cluster_enabled    = true
  eks_oidc_url              = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint           = data.tls_certificate.eks.thumbs[0]

  ebs_csi_driver_namespace       = "kube-system"
  ebs_csi_driver_service_account = "ebs-csi-controller-sa"
}
```

**Attached Managed Policy:**

- `arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy`

**Trust Policy:**

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX"
			},
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Condition": {
				"StringEquals": {
					"oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
					"oidc.eks.REGION.amazonaws.com/id/XXXXXXXXXXXXX:aud": "sts.amazonaws.com"
				}
			}
		}
	]
}
```

### S3 Access Configuration

The S3 access policy grants scoped bucket access to OIDC roles:

```hcl
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  s3_bucket_arn  = "arn:aws:s3:::finishline-prod-data"
  s3_prefix      = "app-data"
  s3_access_type = "readwrite"
}
```

**Access Types:**

| Value       | Permissions                                       | Use Case               |
| ----------- | ------------------------------------------------- | ---------------------- |
| `read`      | `s3:GetObject`                                    | Download files from S3 |
| `write`     | `s3:PutObject`                                    | Upload files to S3     |
| `readwrite` | `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | Full object access     |

**Policy Example (readwrite):**

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AllowS3ObjectAccess",
			"Effect": "Allow",
			"Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
			"Resource": "arn:aws:s3:::finishline-prod-data/app-data/*"
		}
	]
}
```

---

## Outputs

| Output                                 | Type     | Description                                                            |
| -------------------------------------- | -------- | ---------------------------------------------------------------------- |
| `eks_cluster_role_arn`                 | `string` | ARN of the EKS cluster IAM role                                        |
| `eks_cluster_role_name`                | `string` | Name of the EKS cluster IAM role                                       |
| `eks_nodegroup_role_arn`               | `string` | ARN of the EKS nodegroup IAM role                                      |
| `eks_nodegroup_role_name`              | `string` | Name of the EKS nodegroup IAM role                                     |
| `eks_oidc_provider_arn`                | `string` | ARN of the EKS OIDC provider                                           |
| `eks_oidc_provider_url`                | `string` | URL of the EKS OIDC provider                                           |
| `eks_oidc_role_arn`                    | `string` | ARN of the EKS OIDC IAM role                                           |
| `eks_oidc_role_name`                   | `string` | Name of the EKS OIDC IAM role                                          |
| `s3_oidc_policy_arn`                   | `string` | ARN of the S3 OIDC policy                                              |
| `s3_oidc_policy_name`                  | `string` | Name of the S3 OIDC policy                                             |
| `karpenter_controller_role_arn`        | `string` | ARN of the Karpenter controller IAM role                               |
| `karpenter_controller_role_name`       | `string` | Name of the Karpenter controller IAM role                              |
| `karpenter_controller_policy_arn`      | `string` | ARN of the Karpenter controller IAM policy                             |
| `karpenter_controller_policy_name`     | `string` | Name of the Karpenter controller IAM policy                            |
| `karpenter_node_role_arn`              | `string` | ARN of the Karpenter node IAM role                                     |
| `karpenter_node_role_name`             | `string` | Name of the Karpenter node IAM role                                    |
| `karpenter_node_instance_profile_arn`  | `string` | ARN of the Karpenter node instance profile                             |
| `karpenter_node_instance_profile_name` | `string` | Name of the Karpenter node instance profile                            |
| `karpenter_service_account_iam`        | `map`    | Map containing Karpenter service account IAM role information for IRSA |
| `eks_oidc_service_account_iam`         | `map`    | Map containing EKS OIDC service account IAM role information for IRSA  |
| `ebs_csi_driver_role_arn`              | `string` | ARN of the EBS CSI driver IAM role for IRSA                            |
| `ebs_csi_driver_role_name`             | `string` | Name of the EBS CSI driver IAM role                                    |
| `random_suffix`                        | `number` | Random suffix generated for resource naming                            |

### Using Outputs

```hcl
# Reference EKS cluster role
resource "aws_eks_cluster" "main" {
  name     = "finishline-prod-eks"
  role_arn = module.iam.eks_cluster_role_arn
}

# Reference nodegroup role
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "managed-nodes"
  node_role_arn   = module.iam.eks_nodegroup_role_arn
}

# Reference Karpenter controller role for Helm chart
output "karpenter_controller_role_arn" {
  value = module.iam.karpenter_controller_role_arn
}

# Reference instance profile for Karpenter
output "karpenter_node_instance_profile_name" {
  value = module.iam.karpenter_node_instance_profile_name
}

# Reference OIDC role for service account annotation
output "oidc_role_arn" {
  value = module.iam.eks_oidc_role_arn
}
```

---

## IRSA (IAM Roles for Service Accounts)

### What is IRSA?

IRSA (IAM Roles for Service Accounts) enables Kubernetes pods to assume IAM roles, providing fine-grained AWS permissions without using node-level credentials.

### How IRSA Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           IRSA Flow                                      │
└─────────────────────────────────────────────────────────────────────────┘

Step 1: Create IAM Role with OIDC Trust
└─> Trust policy allows OIDC provider
└─> Condition: sub = system:serviceaccount:namespace:name
└─> Condition: aud = sts.amazonaws.com

Step 2: Annotate Kubernetes Service Account
└─> kubectl annotate sa my-sa -n my-namespace eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT:role/my-role

Step 3: Deploy Pod with Service Account
└─> spec.serviceAccountName: my-sa

Step 4: EKS Injects Web Identity Token
└─> Token mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token
└─> Environment variables: AWS_ROLE_ARN, AWS_WEB_IDENTITY_TOKEN_FILE

Step 5: AWS SDK Discovers Credentials
└─> Pod calls AWS APIs using temporary credentials
└─> Credentials automatically rotated by STS
```

### Configuring IRSA

```hcl
# Step 1: IAM module configuration
module "iam" {
  source = "./modules/security/iam"

  # ... required variables

  is_eks_cluster_enabled = true
  eks_oidc_url          = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint       = data.tls_certificate.eks.thumbs[0]

  eks_oidc_namespace       = "my-app"
  eks_oidc_service_account = "my-app-sa"
  eks_oidc_subject         = "system:serviceaccount:my-app:my-app-sa"

  s3_bucket_arn  = "arn:aws:s3:::my-app-bucket"
  s3_prefix      = "data"
  s3_access_type = "readwrite"
}

# Step 2: Create Kubernetes Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-app
  annotations:
    eks.amazonaws.com/role-arn: "${module.iam.eks_oidc_role_arn}"
---
# Step 3: Deploy Pod
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

When IRSA is configured, EKS automatically injects these environment variables:

```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/my-app-oidc-role
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

The AWS SDK (boto3, aws-sdk-go, aws-sdk-java, etc.) automatically discovers these variables and uses them for authentication.

### Verifying IRSA

```bash
# Check service account annotation
kubectl get sa my-app-sa -n my-app -o yaml

# Check pod environment variables
kubectl exec -n my-app my-app-pod -- env | grep AWS

# Test AWS access from pod
kubectl exec -n my-app my-app-pod -- aws s3 ls s3://my-app-bucket/data
```

---

## IAM Policies

### Karpenter Controller Policy

The Karpenter controller policy grants permissions for EC2 instance provisioning:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AllowEC2InstanceOperations",
			"Effect": "Allow",
			"Action": [
				"ec2:RunInstances",
				"ec2:CreateFleet",
				"ec2:CreateLaunchTemplate",
				"ec2:DeleteLaunchTemplate",
				"ec2:DescribeLaunchTemplates",
				"ec2:DescribeInstances",
				"ec2:DescribeInstanceTypes",
				"ec2:DescribeInstanceTypeOfferings",
				"ec2:DescribeAvailabilityZones",
				"ec2:DescribeSecurityGroups",
				"ec2:DescribeSubnets",
				"ec2:DescribeVpcs",
				"ec2:DescribeSpotPriceHistory",
				"ec2:DescribeImages",
				"ec2:DescribeCapacityReservations",
				"ec2:DescribeAvailabilityZones"
			],
			"Resource": "*"
		},
		{
			"Sid": "AllowEC2Tagging",
			"Effect": "Allow",
			"Action": ["ec2:CreateTags"],
			"Resource": [
				"arn:aws:ec2:*:*:instance/*",
				"arn:aws:ec2:*:*:volume/*",
				"arn:aws:ec2:*:*:network-interface/*",
				"arn:aws:ec2:*:*:launch-template/*",
				"arn:aws:ec2:*:*:spot-instances-request/*"
			]
		},
		{
			"Sid": "AllowEC2Termination",
			"Effect": "Allow",
			"Action": ["ec2:TerminateInstances"],
			"Resource": "arn:aws:ec2:*:*:instance/*",
			"Condition": {
				"StringLike": {
					"ec2:ResourceTag/karpenter.sh/discovery": "finishline-prod-eks"
				}
			}
		},
		{
			"Sid": "AllowIAMPassRole",
			"Effect": "Allow",
			"Action": ["iam:PassRole"],
			"Resource": [
				"arn:aws:iam::ACCOUNT:role/finishline-prod-eks-nodegroup-role",
				"arn:aws:iam::ACCOUNT:role/finishline-prod-eks-karpenter-node-role"
			],
			"Condition": {
				"StringLike": {
					"iam:PassedToService": "ec2.amazonaws.com"
				}
			}
		},
		{
			"Sid": "AllowSSMParameterAccess",
			"Effect": "Allow",
			"Action": ["ssm:GetParameter"],
			"Resource": "arn:aws:ssm:*:*:parameter/aws/service/*"
		},
		{
			"Sid": "AllowPricingDataAccess",
			"Effect": "Allow",
			"Action": ["pricing:GetProducts"],
			"Resource": "*"
		},
		{
			"Sid": "AllowEKSClusterAccess",
			"Effect": "Allow",
			"Action": ["eks:DescribeCluster"],
			"Resource": "arn:aws:eks:*:*:cluster/finishline-prod-eks"
		},
		{
			"Sid": "AllowInstanceProfileOperations",
			"Effect": "Allow",
			"Action": ["iam:GetInstanceProfile"],
			"Resource": "arn:aws:iam::*:instance-profile/*"
		}
	]
}
```

### S3 OIDC Policy

The S3 OIDC policy grants scoped bucket access:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AllowS3ObjectAccess",
			"Effect": "Allow",
			"Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
			"Resource": "arn:aws:s3:::finishline-prod-data/app-data/*"
		}
	]
}
```

---

## Tags

The module automatically applies the following tags to all resources:

| Tag Key                  | Value                                          | Purpose                                        |
| ------------------------ | ---------------------------------------------- | ---------------------------------------------- |
| `Name`                   | `{project_name}-{environment}-{resource_type}` | Resource identification                        |
| `Project`                | `{project_name}`                               | Cost allocation                                |
| `Environment`            | `{environment}`                                | Environment identification                     |
| `Managed_By`             | `{managed_by}`                                 | Team ownership                                 |
| `karpenter.sh/discovery` | `{karpenter_cluster_name}`                     | Karpenter discovery (Karpenter resources only) |

---

## Security Best Practices

### 1. Use IRSA Instead of Node Credentials

```hcl
# ❌ Bad: Granting permissions via node role
# All pods inherit node permissions

# ✅ Good: Use IRSA for pod-specific permissions
# Each service account has scoped permissions
```

### 2. Implement Least Privilege

```hcl
# ❌ Bad: Overly permissive S3 access
s3_bucket_arn  = "arn:aws:s3:::*"
s3_prefix      = ""
s3_access_type = "readwrite"

# ✅ Good: Scoped to specific bucket and prefix
s3_bucket_arn  = "arn:aws:s3:::finishline-prod-data"
s3_prefix      = "app-data"
s3_access_type = "read"
```

### 3. Use Deterministic Naming for Production

```hcl
# ✅ Good: Predictable resource names
name_suffix = ""
enable_deterministic_naming = true

# This creates roles like:
# - finishline-prod-eks-cluster-role
# - finishline-prod-eks-nodegroup-role
# - finishline-prod-eks-karpenter-controller-role
```

### 4. Scope Karpenter Permissions

```hcl
# The module automatically scopes TerminateInstances to tagged resources:
# Condition: ec2:ResourceTag/karpenter.sh/discovery = cluster-name

# Ensure Karpenter node role is passed:
karpenter_node_instance_profile_name = ""
```

### 5. Rotate OIDC Thumbprint

```hcl
# Use data source to automatically get current thumbprint
data "tls_certificate" "eks" {
  url = "https://oidc.eks.${var.aws_region}.amazonaws.com"
}

# Reference in module
oidc_thumbprint = data.tls_certificate.eks.thumbs[0]
```

---

## Examples

### Development Environment

```hcl
module "iam_dev" {
  source = "./modules/security/iam"

  project_name    = "finishline"
  environment     = "dev"
  managed_by      = "dev-team"
  aws_region      = "us-west-2"
  cluster_name    = "finishline-dev-eks"

  # Enable EKS roles
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true

  # Disable Karpenter for dev
  is_karpenter_enabled = false

  # Enable EBS CSI Driver
  is_ebs_csi_driver_enabled = true
}
```

### Production with Karpenter

```hcl
module "iam_prod" {
  source = "./modules/security/iam"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  cluster_name    = "finishline-prod-eks"

  # Enable all features
  is_eks_cluster_enabled   = true
  is_eks_role_enabled      = true
  is_eks_nodegroup_role_enabled = true
  is_karpenter_enabled     = true
  is_ebs_csi_driver_enabled = true

  # OIDC configuration
  eks_oidc_url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint          = data.tls_certificate.eks.thumbs[0]
  eks_oidc_namespace       = "karpenter"
  eks_oidc_service_account = "karpenter-controller"
  eks_oidc_subject         = "system:serviceaccount:karpenter:karpenter-controller"

  # Karpenter configuration
  karpenter_cluster_name   = "finishline-prod-eks"
  karpenter_namespace      = "karpenter"
  karpenter_service_account = "karpenter-controller"

  # Deterministic naming
  name_suffix = ""
  enable_deterministic_naming = true
}
```

### Custom Workload with S3 Access

```hcl
module "iam_workload" {
  source = "./modules/security/iam"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "app-team"
  aws_region      = "us-west-2"
  cluster_name    = "finishline-prod-eks"

  is_eks_cluster_enabled = true
  eks_oidc_url          = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_thumbprint       = data.tls_certificate.eks.thumbs[0]

  # Custom workload service account
  eks_oidc_namespace       = "data-processor"
  eks_oidc_service_account = "data-processor-sa"
  eks_oidc_subject         = "system:serviceaccount:data-processor:data-processor-sa"

  # S3 access for data processing
  s3_bucket_arn  = "arn:aws:s3:::finishline-data-lake"
  s3_prefix      = "processed"
  s3_access_type = "write"
}
```

---

## Troubleshooting

### Issue: OIDC Provider Not Created

**Symptoms**: `eks_oidc_provider_arn` output is empty.

**Possible Causes**:

1. `is_eks_cluster_enabled` is `false`
2. `eks_oidc_url` is empty
3. `oidc_thumbprint` is missing

**Resolution**:

```hcl
# Ensure EKS cluster is enabled
is_eks_cluster_enabled = true

# Get OIDC URL from EKS cluster
eks_oidc_url = aws_eks_cluster.main.identity[0].oidc[0].issuer

# Get thumbprint
data "tls_certificate" "eks" {
  url = "https://oidc.eks.${var.aws_region}.amazonaws.com"
}
oidc_thumbprint = data.tls_certificate.eks.thumbs[0]
```

### Issue: IRSA Pod Cannot Assume Role

**Symptoms**: Pod receives `AccessDenied` error.

**Possible Causes**:

1. Service account annotation missing
2. Trust policy doesn't match service account
3. OIDC provider URL mismatch

**Resolution**:

```bash
# Check service account annotation
kubectl get sa my-sa -n my-namespace -o yaml

# Verify annotation
# eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/my-role

# Check trust policy
aws iam get-role --role-name my-role --query 'Role.AssumeRolePolicyDocument'

# Verify OIDC provider
aws iam list-open-id-connect-providers
```

### Issue: Karpenter Cannot Launch Instances

**Symptoms**: Karpenter logs show `AccessDenied: User is not authorized to perform ec2:RunInstances`.

**Possible Causes**:

1. Controller role missing permissions
2. Instance profile not configured
3. PassRole condition not met

**Resolution**:

```bash
# Check controller role policy
aws iam get-role-policy --role-name karpenter-controller-role --policy-name karpenter-controller-policy

# Verify instance profile exists
aws iam get-instance-profile --instance-profile-name karpenter-node-profile

# Check PassRole permissions
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::ACCOUNT:role/karpenter-controller-role --action-names iam:PassRole --resource-arns arn:aws:iam::ACCOUNT:role/karpenter-node-role
```

### Issue: S3 Access Denied

**Symptoms**: Pod cannot access S3 despite IRSA configuration.

**Possible Causes**:

1. S3 policy not attached to role
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

# Test from pod
kubectl exec -n my-namespace my-pod -- aws s3 ls s3://my-bucket/prefix
```

---

## AWS CLI Troubleshooting Commands

### IAM Role Inspection

```bash
# List IAM roles with project tag
aws iam list-roles --query "Roles[?contains(Tags[?Key=='Project'].Value, 'finishline')].[RoleName,Arn]" --output table

# Get role details
aws iam get-role --role-name finishline-prod-eks-cluster-role

# Get trust policy
aws iam get-role --role-name finishline-prod-eks-cluster-role --query "Role.AssumeRolePolicyDocument" --output json

# List attached policies
aws iam list-attached-role-policies --role-name finishline-prod-eks-cluster-role

# Get inline policy document
aws iam get-role-policy --role-name finishline-prod-eks-cluster-role --policy-name policy-name --query "PolicyDocument" --output json
```

### OIDC Provider Inspection

```bash
# List OIDC providers
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[*].[Arn,Tags]" --output table

# Get OIDC provider details
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXX

# Get thumbprint list
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:xxx --query "ThumbprintList"
```

### Karpenter IAM Resources

```bash
# Get Karpenter controller role
aws iam get-role --role-name karpenter-controller-role

# Get controller policy
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT:policy/karpenter-controller-policy

# Get policy document
aws iam get-policy-version --policy-arn arn:aws:iam::ACCOUNT:policy/karpenter-controller-policy --version-id v1

# Get Karpenter node role
aws iam get-role --role-name karpenter-node-role

# Get instance profile
aws iam get-instance-profile --instance-profile-name karpenter-node-profile

# List instance profiles
aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, 'karpenter')].[InstanceProfileName,Arn,Roles[].RoleName]" --output table
```

### Policy Simulation

```bash
# Simulate IAM permissions
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::ACCOUNT:role/karpenter-controller-role --action-names ec2:RunInstances,ec2:TerminateInstances --resource-arns arn:aws:ec2:REGION:ACCOUNT:instance/*

# Check specific action
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::ACCOUNT:role/karpenter-controller-role --action-names iam:PassRole --resource-arns arn:aws:iam::ACCOUNT:role/karpenter-node-role
```

### Service Account IAM (IRSA)

```bash
# Get service account annotation
kubectl get sa karpenter-controller -n karpenter -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# Verify IAM role trust policy
aws iam get-role --role-name karpenter-controller-role --query 'Role.AssumeRolePolicyDocument' --output json | jq

# Test IRSA from pod
kubectl run test-irsa --image=amazon/aws-cli --rm -it --env="AWS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/my-role" --env="AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token" -- aws sts get-caller-identity
```

---

## Module Structure

```
iam/
├── main.tf          # IAM resources (roles, policies, OIDC provider)
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── data.tf          # Data sources (IAM policy documents, caller identity)
└── README.md        # This documentation
```

### File Descriptions

| File           | Description                                                   |
| -------------- | ------------------------------------------------------------- |
| `main.tf`      | Creates IAM roles, policies, OIDC provider, instance profiles |
| `variables.tf` | Defines input variables with descriptions and defaults        |
| `outputs.tf`   | Exports IAM resource ARNs, names, and IRSA information        |
| `data.tf`      | Defines IAM policy documents for trust relationships          |
| `README.md`    | Comprehensive documentation                                   |

### Resources Created

| Resource                                            | Type                        | Conditional                                                                 |
| --------------------------------------------------- | --------------------------- | --------------------------------------------------------------------------- |
| `random_integer.random_suffix`                      | Random suffix               | Always                                                                      |
| `aws_iam_role.eks_cluster_role`                     | EKS cluster role            | `is_eks_role_enabled`                                                       |
| `aws_iam_role.eks_nodegroup_role`                   | EKS nodegroup role          | `is_eks_nodegroup_role_enabled`                                             |
| `aws_iam_openid_connect_provider.eks_oidc_provider` | OIDC provider               | `is_eks_cluster_enabled && eks_oidc_url != ""`                              |
| `aws_iam_role.eks_oidc_role`                        | OIDC IAM role               | `is_eks_cluster_enabled && eks_oidc_url != ""`                              |
| `aws_iam_policy.s3_oidc_policy`                     | S3 access policy            | `is_eks_cluster_enabled && eks_oidc_url != "" && s3_bucket_arn != ""`       |
| `aws_iam_role.karpenter-controller-role`            | Karpenter controller role   | `is_karpenter_enabled && is_eks_cluster_enabled && eks_oidc_url != ""`      |
| `aws_iam_policy.karpenter-controller-policy`        | Karpenter controller policy | Same as above                                                               |
| `aws_iam_role.karpenter-node-role`                  | Karpenter node role         | `is_karpenter_enabled`                                                      |
| `aws_iam_instance_profile.karpenter-node-profile`   | Karpenter instance profile  | `is_karpenter_enabled`                                                      |
| `aws_iam_role.ebs-csi-driver-role`                  | EBS CSI driver role         | `is_ebs_csi_driver_enabled && is_eks_cluster_enabled && eks_oidc_url != ""` |

---

## Related Documentation

- [Security Modules Parent README](../README.md) - Overview of all security modules
- [Key Pair Module](../key_pair/README.md) - SSH key pair management
- [AWS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Karpenter IAM Setup](https://karpenter.sh/docs/getting-started/)
- [EBS CSI Driver IAM](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
