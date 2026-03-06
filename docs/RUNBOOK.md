# Finishline Infrastructure — Runbook

**Version**: 1.0  
**Last Updated**: 2026-03-05  
**Owner**: Platform / Infrastructure Team

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Repository Structure](#3-repository-structure)
4. [Bootstrap — Remote State Setup](#4-bootstrap--remote-state-setup)
5. [First-Time Deployment (dev)](#5-first-time-deployment-dev)
6. [Day-2 Operations](#6-day-2-operations)
   - [Applying Changes](#61-applying-changes)
   - [Targeted Resource Updates](#62-targeted-resource-updates)
   - [Adding a New Module](#63-adding-a-new-module)
   - [Rotating the EC2 Key Pair](#64-rotating-the-ec2-key-pair)
7. [Deploying to Staging & Production](#7-deploying-to-staging--production)
8. [Destroying an Environment](#8-destroying-an-environment)
9. [Module Reference](#9-module-reference)
   - [VPC](#91-vpc-module)
   - [Security Group](#92-security-group-module)
   - [Key Pair](#93-key-pair-module)
   - [IAM (EKS)](#94-iam-eks-module)
10. [State Management](#10-state-management)
11. [Troubleshooting](#11-troubleshooting)
12. [Security Checklist](#12-security-checklist)

---

## 1. Overview

This runbook covers the full lifecycle of the **Finishline** AWS infrastructure managed via Terraform. The project uses a **modular, environment-scoped** layout where:

- `terraform/modules/` — reusable, parameterised resource modules
- `terraform/environments/<env>/` — per-environment root modules that call shared modules

Current environments:

| Environment | State      | Notes                     |
| ----------- | ---------- | ------------------------- |
| `dev`       | ✅ Active  | S3 backend configured     |
| `staging`   | 🔲 Pending | Needs backend + variables |
| `prod`      | 🔲 Pending | Needs backend + variables |

---

## 2. Prerequisites

### Tools

| Tool      | Minimum Version | Install                                                             |
| --------- | --------------- | ------------------------------------------------------------------- |
| Terraform | `>= 1.6.0`      | https://developer.hashicorp.com/terraform/install                   |
| AWS CLI   | `>= 2.x`        | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Git       | any             | https://git-scm.com/downloads                                       |

### AWS Permissions

The IAM principal running Terraform requires permissions for all resources being managed. At a minimum:

- `ec2:*` (VPC, subnets, IGW, EIP, security groups, key pairs)
- `iam:*` (roles, policies, OIDC providers)
- `s3:*` (remote state bucket)
- `eks:*` (when EKS modules are active)
- `elasticloadbalancing:*` (when ALB module is active)

Recommended: attach the managed policy `AdministratorAccess` in non-production developer accounts, and use a scoped custom policy in staging/prod.

### AWS CLI Configuration

```bash
aws configure
# or use SSO:
aws sso login --profile <profile>
export AWS_PROFILE=<profile>
```

Verify:

```bash
aws sts get-caller-identity
```

---

## 3. Repository Structure

```
finishline_infra_app/
├── docs/
│   ├── RUNBOOK.md                  ← this file
│   └── Finishline_Infra_Project_Assignment.pdf
└── terraform/
    ├── environments/
    │   ├── dev/                    ← active environment
    │   ├── staging/
    │   └── prod/
    └── modules/
        ├── vpc/
        ├── security_group/
        ├── secret/
        │   ├── iam/
        │   └── key_pair/
        ├── alb/
        ├── ec2/
        ├── eks/
        └── bootstrap/
```

---

## 4. Bootstrap — Remote State Setup

The S3 remote state bucket must exist **before** running `terraform init` in any environment.

### 4.1 Create the S3 State Bucket (one-time)

```bash
# Replace <BUCKET_NAME> and <REGION> with your values
aws s3api create-bucket \
  --bucket finishline-infra-app-9e1f6284 \
  --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket finishline-infra-app-9e1f6284 \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket finishline-infra-app-9e1f6284 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket finishline-infra-app-9e1f6284 \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 4.2 Backend Configuration (`backend.tf`)

Each environment's `backend.tf` specifies its own state key:

```hcl
terraform {
  backend "s3" {
    bucket       = "finishline-infra-app-9e1f6284"
    key          = "dev/terraform.tfstate"   # change per environment
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

> **Note**: `use_lockfile = true` uses S3 native locking (no DynamoDB required — requires AWS provider ≥ 6.x and Terraform ≥ 1.6).

---

## 5. First-Time Deployment (dev)

### Step 1 — Clone the repository

```bash
git clone <repo-url>
cd finishline_infra_app
```

### Step 2 — Change to the dev environment

```bash
cd terraform/environments/dev
```

### Step 3 — Create a `terraform.tfvars` file

Create `terraform/environments/dev/terraform.tfvars` (never commit secrets):

```hcl
# General
project_name = "finishline"
environment  = "dev"
manage_by    = "Terraform"
aws_region   = "us-east-1"

# VPC
vpc_cidr              = "10.0.0.0/16"
enable_dns_hostnames  = true
enable_dns_support    = true
map_public_ip_on_launch = true
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnets_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Security Group
security_group_name = "finishline-dev-sg"
ingress_rules = [
  {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # restrict to a known CIDR in production
  },
  {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# Key Pair
key_name = "finishline-key-pair"
```

### Step 4 — Initialise Terraform

```bash
terraform init
```

Expected output:

```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

### Step 5 — Validate configuration

```bash
terraform validate
```

### Step 6 — Review the plan

```bash
terraform plan -out=tfplan
```

Review all resources marked `+` (create). Verify:

- VPC CIDR does not overlap with existing networks
- Subnets are distributed across the specified AZs
- Key pair name is unique

### Step 7 — Apply

```bash
terraform apply tfplan
```

Type `yes` when prompted (or use `-auto-approve` for CI pipelines).

### Step 8 — Verify outputs

```bash
terraform output
```

---

## 6. Day-2 Operations

### 6.1 Applying Changes

For any configuration change:

```bash
cd terraform/environments/dev

# Review what will change
terraform plan -out=tfplan

# Apply only after review
terraform apply tfplan
```

> Always run `plan` before `apply`. Never apply without reviewing the diff.

### 6.2 Targeted Resource Updates

To update a single resource without touching others:

```bash
terraform plan -target=module.vpc -out=tfplan
terraform apply tfplan
```

Common targets:

| Target                 | Description                      |
| ---------------------- | -------------------------------- |
| `module.vpc`           | VPC and all networking resources |
| `module.finishline_sg` | Security group                   |
| `module.key_pair`      | EC2 key pair                     |
| `module.iam`           | EKS IAM roles and OIDC provider  |

### 6.3 Adding a New Module

1. Create the module directory under `terraform/modules/<name>/`
2. Add `main.tf`, `variables.tf`, `output.tf`
3. Reference it in the environment's `main.tf`:

```hcl
module "my_new_module" {
  source = "../../modules/<name>"
  # pass variables
}
```

4. Add any new variables to `variables.tf` in the environment
5. Run `terraform init` (to register the new module), then `plan` and `apply`

### 6.4 Rotating the EC2 Key Pair

The key pair is managed by the `secret/key_pair` module. To rotate:

1. **Delete the existing key pair** from all running EC2 instances (update instances to use a new key, or ensure no live instances depend on it).
2. Taint the Terraform resource to force recreation:

```bash
terraform taint module.key_pair.aws_key_pair.finishline_key_pair
terraform taint module.key_pair.tls_private_key.rsa_4096
```

3. Plan and apply:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

4. The new `.pem` file will be written to the environment directory. Secure it immediately:

```bash
chmod 400 finishline-key-pair.pem
```

> ⚠️ The private key is stored in Terraform state. Ensure your state backend (S3) has encryption and strict bucket policies.

---

## 7. Deploying to Staging & Production

### Step 1 — Configure the backend

Edit `terraform/environments/<env>/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "finishline-infra-app-9e1f6284"
    key          = "staging/terraform.tfstate"   # or prod/terraform.tfstate
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

### Step 2 — Add `providers.tf`

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = var.manage_by
    }
  }
}
```

### Step 3 — Copy and customise `variables.tf` and `main.tf` from dev

Adjust CIDRs, AZs, and resource names for the new environment. Ensure no CIDR overlap exists between environments if they share a network.

### Step 4 — Create `terraform.tfvars` for the environment

Set `environment = "staging"` or `environment = "prod"`.

### Step 5 — Deploy

```bash
cd terraform/environments/staging
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 8. Destroying an Environment

> ⚠️ **Destructive operation** — this permanently deletes all managed resources.

```bash
cd terraform/environments/dev

# Preview what will be destroyed
terraform plan -destroy -out=destroy.tfplan

# Destroy (requires confirmation)
terraform apply destroy.tfplan
```

Or interactively:

```bash
terraform destroy
```

After destroy, the state file in S3 will contain an empty state. The S3 bucket itself is **not** managed by Terraform and must be deleted manually if no longer needed.

---

## 9. Module Reference

### 9.1 VPC Module

**Path**: `terraform/modules/vpc/`

| Variable                | Type         | Description                        |
| ----------------------- | ------------ | ---------------------------------- |
| `project_name`          | string       | Used in resource naming and tags   |
| `environment`           | string       | Used in resource naming and tags   |
| `manage_by`             | string       | `ManageBy` tag value               |
| `vpc_cidr`              | string       | VPC CIDR block, e.g. `10.0.0.0/16` |
| `availability_zones`    | list(string) | AZs for subnet distribution        |
| `public_subnets_cidrs`  | list(string) | CIDR blocks for public subnets     |
| `private_subnets_cidrs` | list(string) | CIDR blocks for private subnets    |
| `enable_dns_hostnames`  | bool         | Enable DNS hostnames in VPC        |
| `enable_dns_support`    | bool         | Enable DNS resolution in VPC       |

**Outputs**: `main_vpc_id`, public/private subnet IDs.

---

### 9.2 Security Group Module

**Path**: `terraform/modules/security_group/`

| Variable              | Type         | Description             |
| --------------------- | ------------ | ----------------------- |
| `project_name`        | string       | Used in tags            |
| `environment`         | string       | Used in tags            |
| `vpc_id`              | string       | VPC to attach the SG to |
| `manage_by`           | string       | `ManageBy` tag value    |
| `security_group_name` | string       | SG name                 |
| `ingress_rules`       | list(object) | List of inbound rules   |
| `egress_rules`        | list(object) | List of outbound rules  |

Each rule object: `{ description, from_port, to_port, protocol, cidr_blocks }`.

---

### 9.3 Key Pair Module

**Path**: `terraform/modules/secret/key_pair/`

| Variable       | Type   | Description                           |
| -------------- | ------ | ------------------------------------- |
| `project_name` | string | Used in tags                          |
| `environment`  | string | Used in tags                          |
| `manage_by`    | string | `ManagedBy` tag value                 |
| `key_name`     | string | AWS key pair name and `.pem` filename |

**Output**: `key_name`

> The private key PEM file is written to the **working directory** where `terraform apply` is run.

---

### 9.4 IAM (EKS) Module

**Path**: `terraform/modules/secret/iam/`

| Variable                        | Type         | Default     | Description                         |
| ------------------------------- | ------------ | ----------- | ----------------------------------- |
| `cluster_name`                  | string       | —           | EKS cluster name prefix             |
| `is_eks_role_enabled`           | bool         | —           | Create EKS cluster role             |
| `is_eks_nodegroup_role_enabled` | bool         | —           | Create EKS node group role          |
| `is_eks_cluster_enabled`        | bool         | —           | Create OIDC provider and OIDC role  |
| `eks_oidc_url`                  | string       | `""`        | OIDC issuer URL from EKS cluster    |
| `oidc_thumbprint`               | list(string) | AWS root CA | TLS thumbprints for OIDC provider   |
| `s3_bucket_arn`                 | string       | `""`        | S3 bucket name to scope OIDC policy |

**To retrieve the OIDC URL** after cluster creation:

```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query "cluster.identity.oidc.issuer" \
  --output text
```

Pass this value as `eks_oidc_url`.

**Outputs**: `eks_cluster_role_arn`, `eks_nodegroup_role_arn`, `eks_oidc_role_arn`, `eks_oidc_policy_arn`, `eks_oidc_provider_arn`, `eks_oidc_provider_url`

---

## 10. State Management

### View current state

```bash
terraform state list
```

### Inspect a specific resource

```bash
terraform state show module.vpc.aws_vpc.finishline_vpc
```

### Move a resource (refactoring)

```bash
terraform state mv \
  module.old_name.aws_vpc.finishline_vpc \
  module.new_name.aws_vpc.finishline_vpc
```

### Remove a resource from state (without destroying it)

```bash
terraform state rm module.key_pair.local_file.private_key
```

### Pull remote state locally

```bash
terraform state pull > local-backup.tfstate
```

### Unlock state (if a lock is stuck)

```bash
# For S3 native locking (Terraform >= 1.6 / AWS provider >= 6)
# Delete the lock file from S3:
aws s3 rm s3://finishline-infra-app-9e1f6284/dev/terraform.tfstate.tflock
```

---

## 11. Troubleshooting

### `Error: No declaration found for "var.X"`

A variable referenced in a module has no corresponding `variable` block. Add it to `variables.tf` in the module.

### `Error: Reference to undeclared resource`

A resource is referenced before it is defined (e.g. the OIDC provider issue). Ensure all referenced resources exist in `main.tf` or are passed in as variables.

### `Error acquiring the state lock`

Another process holds the lock. Wait for it to complete, or unlock manually (see [§10](#10-state-management)).

### `Error: InvalidKeyPair.Duplicate`

An EC2 key pair with the same name already exists. Either import it into state or rename it:

```bash
terraform import module.key_pair.aws_key_pair.finishline_key_pair <key-name>
```

### `Error: creating IAM Role: EntityAlreadyExists`

An IAM role with the same name exists outside of Terraform state. Import it:

```bash
terraform import module.iam.aws_iam_role.eks-cluster-role[0] <role-name>
```

### `terraform plan` shows unexpected changes after no code change

This can happen with `random_integer` resources on re-plan if the seed changes. The `random_integer.random_suffix` is always created and its value is stable after the first `apply`.

---

## 12. Security Checklist

| #   | Check                                                        | Status                                |
| --- | ------------------------------------------------------------ | ------------------------------------- |
| 1   | S3 state bucket has versioning enabled                       | ✅                                    |
| 2   | S3 state bucket has SSE encryption enabled                   | ✅                                    |
| 3   | S3 state bucket blocks all public access                     | ✅                                    |
| 4   | State locking is enabled (`use_lockfile = true`)             | ✅                                    |
| 5   | `.pem` private key file is excluded from git (`.gitignore`)  | ✅                                    |
| 6   | `terraform.tfvars` is excluded from git                      | ⚠️ Verify `.gitignore`                |
| 7   | IAM policies follow least-privilege (no `*` resources)       | ✅ (fixed in IAM module)              |
| 8   | OIDC policy scoped to specific S3 bucket via `s3_bucket_arn` | ✅                                    |
| 9   | EC2 SSH ingress restricted to known CIDRs in prod            | ⚠️ Review SG rules                    |
| 10  | Private subnets do not have a direct route to IGW            | ⚠️ Review VPC private route table     |
| 11  | EKS node group does not use `AdministratorAccess` policy     | ✅ (uses scoped AWS managed policies) |
| 12  | OIDC thumbprint list kept up-to-date                         | ⚠️ Rotate when AWS root CA changes    |

> ⚠️ Items: ensure `terraform.tfvars` is listed in `.gitignore`, restrict SSH CIDR in production ingress rules, and verify the private route table does not route directly through the IGW (currently it does — consider adding a NAT Gateway for production environments).
