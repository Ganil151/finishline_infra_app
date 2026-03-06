# Finishline Infrastructure — Runbook

**Version**: 1.1
**Last Updated**: 2026-03-06
**Owner**: Platform / Infrastructure Team

---

## Table of Contents

- [Finishline Infrastructure — Runbook](#finishline-infrastructure--runbook)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Prerequisites](#2-prerequisites)
    - [Tools](#tools)
    - [AWS Permissions](#aws-permissions)
    - [AWS CLI Configuration](#aws-cli-configuration)
  - [3. Repository Structure](#3-repository-structure)
  - [4. Bootstrap — Remote State Setup](#4-bootstrap--remote-state-setup)
    - [4.1 Create the S3 State Bucket (one-time)](#41-create-the-s3-state-bucket-one-time)
    - [4.2 Backend Configuration (`backend.tf`)](#42-backend-configuration-backendtf)
  - [5. First-Time Deployment (dev)](#5-first-time-deployment-dev)
    - [Step 1 — Clone the repository](#step-1--clone-the-repository)
    - [Step 2 — Change to the dev environment](#step-2--change-to-the-dev-environment)
    - [Step 3 — Create a `terraform.tfvars` file](#step-3--create-a-terraformtfvars-file)
    - [Step 4 — Initialise Terraform](#step-4--initialise-terraform)
    - [Step 5 — Validate configuration](#step-5--validate-configuration)
    - [Step 6 — Review the plan](#step-6--review-the-plan)
    - [Step 7 — Apply](#step-7--apply)
    - [Step 8 — Verify outputs](#step-8--verify-outputs)
  - [6. Day-2 Operations](#6-day-2-operations)
    - [6.1 Applying Changes](#61-applying-changes)
    - [6.2 Targeted Resource Updates](#62-targeted-resource-updates)
    - [6.3 Adding a New Module](#63-adding-a-new-module)
    - [6.4 Rotating the EC2 Key Pair](#64-rotating-the-ec2-key-pair)
  - [7. Deploying to Staging \& Production](#7-deploying-to-staging--production)
    - [Step 1 — Configure the backend](#step-1--configure-the-backend)
    - [Step 2 — Add `providers.tf`](#step-2--add-providerstf)
    - [Step 3 — Copy and customise `variables.tf` and `main.tf` from dev](#step-3--copy-and-customise-variablestf-and-maintf-from-dev)
    - [Step 4 — Create `terraform.tfvars` for the environment](#step-4--create-terraformtfvars-for-the-environment)
    - [Step 5 — Deploy](#step-5--deploy)
  - [8. Destroying an Environment](#8-destroying-an-environment)
  - [9. Module Reference](#9-module-reference)
    - [9.1 VPC Module](#91-vpc-module)
    - [9.2 Security Group Module](#92-security-group-module)
    - [9.3 Key Pair Module](#93-key-pair-module)
    - [9.4 IAM (EKS) Module](#94-iam-eks-module)
    - [9.5 EKS Module](#95-eks-module)
      - [Retrieve kubeconfig after apply](#retrieve-kubeconfig-after-apply)
  - [11. Static Analysis \& Cost Estimation](#11-static-analysis--cost-estimation)
    - [11.1 tfsec — IaC Security Scanner](#111-tfsec--iac-security-scanner)
    - [11.2 Checkov — Policy-as-Code Scanner](#112-checkov--policy-as-code-scanner)
    - [11.3 Infracost — Cloud Cost Estimation](#113-infracost--cloud-cost-estimation)
    - [11.4 Recommended Workflow](#114-recommended-workflow)
  - [10. State Management](#10-state-management)
    - [View current state](#view-current-state)
    - [Inspect a specific resource](#inspect-a-specific-resource)
    - [Move a resource (refactoring)](#move-a-resource-refactoring)
    - [Remove a resource from state (without destroying it)](#remove-a-resource-from-state-without-destroying-it)
    - [Pull remote state locally](#pull-remote-state-locally)
    - [Unlock state (if a lock is stuck)](#unlock-state-if-a-lock-is-stuck)
  - [11. Troubleshooting](#11-troubleshooting)
    - [`Error: No declaration found for "var.X"`](#error-no-declaration-found-for-varx)
    - [`Error: Reference to undeclared resource`](#error-reference-to-undeclared-resource)
    - [`Error acquiring the state lock`](#error-acquiring-the-state-lock)
    - [`Error: InvalidKeyPair.Duplicate`](#error-invalidkeypairduplicate)
    - [`Error: creating IAM Role: EntityAlreadyExists`](#error-creating-iam-role-entityalreadyexists)
    - [`terraform plan` shows unexpected changes after no code change](#terraform-plan-shows-unexpected-changes-after-no-code-change)
  - [12. Security Checklist](#12-security-checklist)

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
project_name = "finishline-infra"
environment  = "dev"
manage_by    = "finishline-dev-team"
aws_region   = "us-east-1"

# VPC
vpc_cidr                = "10.0.0.0/16"
enable_dns_hostnames    = true
enable_dns_support      = true
map_public_ip_on_launch = true
availability_zones      = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets_cidrs    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets_cidrs   = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

# Security Group
security_group_name = "finishline-sg"
ingress_rules = [
  {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # restrict to a known CIDR in production
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

# IAM
is_eks_role_enabled           = true
is_eks_nodegroup_role_enabled = true

# EKS Cluster
cluster_name              = "finishline-eks-cluster"
is_eks_cluster_enabled    = true
is_eks_node_group_enabled = true
is_eks_addons_enabled     = true
cluster_version           = "1.29"   # must be >= 1.29 with AWS provider 6.x
endpoint_private_access   = true
endpoint_public_access    = false
cluster_enabled_log_types = ["api", "audit", "authenticator"]

addons = {
  coredns    = { version = "v1.11.1-eksbuild.9" }
  kube-proxy = { version = "v1.29.3-eksbuild.2" }
  vpc-cni    = { version = "v1.18.1-eksbuild.3" }
}

# On-demand node group
desired_capacity_on_demand = 2
min_capacity_on_demand     = 1
max_capacity_on_demand     = 4
ondemand_instance_types    = ["t3.medium"]

# Spot node group
desired_capacity_spot  = 1
min_capacity_spot      = 0
max_capacity_spot      = 3
spot_instance_types    = ["t3.medium", "t3.large"]
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

| Target                 | Description                                 |
| ---------------------- | ------------------------------------------- |
| `module.vpc`           | VPC and all networking resources            |
| `module.finishline_sg` | Security group                              |
| `module.key_pair`      | EC2 key pair                                |
| `module.iam`           | EKS IAM roles and OIDC provider             |
| `module.eks`           | EKS cluster, OIDC provider, and node groups |

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

### 9.5 EKS Module

**Path**: `terraform/modules/eks/`

Creates the EKS control plane, OpenID Connect ( OIDC ) identity provider, on-demand and spot managed node groups, and optional add-ons.

| Variable                     | Type         | Default                           | Description                                                    |
| ---------------------------- | ------------ | --------------------------------- | -------------------------------------------------------------- |
| `cluster_name`               | string       | —                                 | EKS cluster name                                               |
| `cluster_version`            | string       | —                                 | Kubernetes version (≥ 1.29 required with AWS provider ≥ 6.x)   |
| `cluster_role_arn`           | string       | —                                 | IAM role ARN for the EKS control plane (from `module.iam`)     |
| `node_role_arn`              | string       | —                                 | IAM role ARN for node groups (from `module.iam`)               |
| `subnet_ids`                 | list(string) | —                                 | Private subnet IDs (from `module.vpc`)                         |
| `security_group_ids`         | list(string) | —                                 | Security group IDs to attach to the cluster                    |
| `is_eks_cluster_enabled`     | bool         | —                                 | Create the EKS cluster and OIDC provider                       |
| `is_eks_node_group_enabled`  | bool         | —                                 | Create on-demand and spot node groups                          |
| `is_eks_addons_enabled`      | bool         | —                                 | Install add-ons via `aws_eks_addon`                            |
| `endpoint_private_access`    | bool         | `true`                            | Enable private API server endpoint                             |
| `endpoint_public_access`     | bool         | `false`                           | Enable public API server endpoint                              |
| `cluster_enabled_log_types`  | list(string) | `["api","audit","authenticator"]` | Control plane log types forwarded to CloudWatch                |
| `addons`                     | map(any)     | `{}`                              | Map of `addon_name → { version, service_account_role_arn? }`   |
| `desired_capacity_on_demand` | number       | `2`                               | On-demand desired node count                                   |
| `min_capacity_on_demand`     | number       | `1`                               | On-demand minimum node count                                   |
| `max_capacity_on_demand`     | number       | `4`                               | On-demand maximum node count                                   |
| `ondemand_instance_types`    | list(string) | `["t3.medium"]`                   | EC2 instance types for on-demand nodes                         |
| `desired_capacity_spot`      | number       | `1`                               | Spot desired node count                                        |
| `min_capacity_spot`          | number       | `0`                               | Spot minimum node count                                        |
| `max_capacity_spot`          | number       | `3`                               | Spot maximum node count                                        |
| `spot_instance_types`        | list(string) | `["t3.medium","t3.large"]`        | EC2 instance types for spot nodes (multiple = better capacity) |

**Outputs**: `cluster_id`, `cluster_arn`, `cluster_endpoint`, `cluster_version`, `cluster_certificate_authority_data`, `cluster_security_group_id`, `cluster_oidc_issuer`, `cluster_oidc_provider_arn`, `ondemand_node_group_id`, `ondemand_node_group_arn`, `spot_node_group_id`, `spot_node_group_arn`

> **Dependency flow**: `module.iam` creates IAM roles → `module.eks` uses those roles and creates the cluster + OIDC provider → Terraform feeds `module.eks.cluster_oidc_issuer` back to `module.iam` to create the OIDC IAM role/policy. Terraform's dependency graph resolves this automatically without a circular module dependency.

#### Retrieve kubeconfig after apply

```bash
aws eks update-kubeconfig \
  --name finishline-eks-cluster \
  --region us-east-1

kubectl get nodes
```

---

## 11. Static Analysis & Cost Estimation

Run these tools **before every `terraform plan`** in your local workflow and **in CI/CD as mandatory gates** before merging infrastructure changes.

### 11.1 tfsec — IaC Security Scanner

**What it does:** Scans Terraform source code for known security misconfigurations using built-in rules (AWS, Azure, GCP) and custom checks.

**When to use:**

- Locally: before opening a pull request
- CI/CD: as a required check on every push to any branch touching `terraform/`
- Pre-release: before promoting changes from dev → staging → prod

**Install:**

```bash
# Homebrew (macOS / Linux)
brew install tfsec

# or download binary
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

**Run against the whole project:**

```bash
tfsec terraform/
```

**Run against a single environment:**

```bash
tfsec terraform/environments/dev/
```

**Run against a single module:**

```bash
tfsec terraform/modules/eks/
```

**Common flags:**

```bash
# Show only HIGH and CRITICAL
tfsec terraform/ --minimum-severity HIGH

# Output as JUnit XML (for CI)
tfsec terraform/ --format junit --out tfsec-results.xml

# Ignore a specific check with a comment in code:
# tfsec:ignore:aws-eks-no-public-cluster-access
```

**Key EKS checks this project addresses:**

| tfsec Rule                             | Status | How                                      |
| -------------------------------------- | ------ | ---------------------------------------- |
| `aws-eks-no-public-cluster-access`     | ✅     | `endpoint_public_access = false`         |
| `aws-eks-enable-control-plane-logging` | ✅     | `cluster_enabled_log_types` set          |
| `aws-iam-no-policy-wildcards`          | ✅     | IAM module uses scoped managed policies  |
| `aws-vpc-no-public-egress-sgr`         | ⚠️     | Dev allows all egress — restrict in prod |

---

### 11.2 Checkov — Policy-as-Code Scanner

**What it does:** Scans Terraform, CloudFormation, Dockerfiles, Kubernetes manifests, and more against 1000+ security and compliance policies (CIS, HIPAA, PCI-DSS, NIST).

**When to use:**

- Locally: during development, especially when adding new resources
- CI/CD: as a required check in the same pipeline step as tfsec (they complement each other)
- Compliance reviews: generate reports before audits

**Install:**

```bash
pip install checkov
# or via brew
brew install checkov
```

**Run against the whole project:**

```bash
checkov -d terraform/
```

**Run against a single environment:**

```bash
checkov -d terraform/environments/dev/
```

**Run against a single module:**

```bash
checkov -d terraform/modules/eks/
```

**Common flags:**

```bash
# Output as JUnit XML (for CI)
checkov -d terraform/ --output junitxml > checkov-results.xml

# Output as GitHub Actions annotations
checkov -d terraform/ --output github_failed_only

# Skip a specific check
checkov -d terraform/ --skip-check CKV_AWS_58

# Run only EKS-related checks
checkov -d terraform/ --check CKV_AWS_58,CKV_AWS_37,CKV_AWS_38,CKV_AWS_39,CKV_AWS_185
```

**Key EKS / IAM Checkov checks:**

| Check ID      | Description                                        | Status |
| ------------- | -------------------------------------------------- | ------ |
| `CKV_AWS_37`  | EKS API server should not be publicly accessible   | ✅     |
| `CKV_AWS_38`  | EKS should have private endpoint enabled           | ✅     |
| `CKV_AWS_39`  | EKS should have cluster logging enabled            | ✅     |
| `CKV_AWS_58`  | EKS cluster should use encrypted secrets           | ⚠️     |
| `CKV_AWS_185` | EKS cluster should not use deprecated API versions | ✅     |
| `CKV_AWS_111` | IAM policies should not allow `*` on all resources | ✅     |
| `CKV_AWS_382` | Security group should not have unrestricted egress | ⚠️     |

> **Note on `CKV_AWS_58`**: EKS secrets encryption requires a KMS key configured via the `encryption_config` block. This is not yet implemented — add it before using staging/prod.

---

### 11.3 Infracost — Cloud Cost Estimation

**What it does:** Parses Terraform plan output and estimates the monthly AWS cost of all resources, showing a line-item breakdown and the cost delta for changes.

**When to use:**

- Before `terraform apply` to understand the cost impact of new resources
- During code review — show the monthly cost diff in pull request comments
- Budget planning — before provisioning new environments (staging, prod)
- Evaluating instance type trade-offs (e.g., `t3.medium` vs `t3.large`)

**Install:**

```bash
brew install infracost
# or
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Register for a free API key
infracost auth login
```

**Generate a cost estimate (requires a terraform plan JSON):**

```bash
cd terraform/environments/dev

# Step 1 — generate a plan
terraform plan -out=tfplan

# Step 2 — convert plan to JSON
terraform show -json tfplan > plan.json

# Step 3 — estimate cost
infracost breakdown --path plan.json
```

**Show cost diff for a change:**

```bash
# Baseline (main branch)
infracost breakdown --path plan.json --format json --out-file infracost-base.json

# After your change
infracost diff --path plan.json --compare-to infracost-base.json
```

**Typical monthly cost drivers in this project (dev):**

| Resource                          | Approx Monthly Cost      |
| --------------------------------- | ------------------------ |
| EKS Control Plane                 | ~$73 (fixed per cluster) |
| On-demand nodes (2× t3.medium)    | ~$60                     |
| Spot nodes (1× t3.medium at ~70%) | ~$10                     |
| NAT Gateway (if enabled)          | ~$32 + data transfer     |
| EKS Add-ons (CoreDNS, vpc-cni)    | $0 (no extra charge)     |
| S3 state bucket                   | < $1                     |

> 🔔 Run `infracost breakdown` before provisioning staging/prod to avoid unexpected costs. EKS clusters are billed per hour even when idle.

---

### 11.4 Recommended Workflow

Use all three tools together in this order before every `terraform apply`:

```bash
cd terraform/environments/dev

# 1. Format check
terraform fmt -check -recursive ../../

# 2. Validate HCL syntax and variable references
terraform validate

# 3. Security scan (fast, no AWS credentials needed)
tfsec ../../modules/eks/ ../../modules/secret/iam/ .

# 4. Policy-as-code compliance scan
checkov -d . --quiet

# 5. Cost estimate (requires terraform plan)
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
infracost breakdown --path plan.json

# 6. Apply only after reviewing all outputs
terraform apply tfplan
```

**CI/CD pipeline gate (GitHub Actions example):**

```yaml
# .github/workflows/terraform.yml
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: terraform/

      - name: Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
          output_format: github_failed_only
          soft_fail: false

      - name: Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}
      - run: |
          cd terraform/environments/dev
          terraform init -backend=false
          infracost breakdown --path . \
            --format github-comment \
            --out-file /tmp/infracost.md
      - uses: infracost/actions/comment@v3
        with:
          path: /tmp/infracost.md
          behavior: update
```

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

| #   | Check                                                               | Status                                    |
| --- | ------------------------------------------------------------------- | ----------------------------------------- |
| 1   | S3 state bucket has versioning enabled                              | ✅                                        |
| 2   | S3 state bucket has SSE encryption enabled                          | ✅                                        |
| 3   | S3 state bucket blocks all public access                            | ✅                                        |
| 4   | State locking is enabled (`use_lockfile = true`)                    | ✅                                        |
| 5   | `.pem` private key file is excluded from git (`.gitignore`)         | ✅                                        |
| 6   | `terraform.tfvars` is excluded from git                             | ⚠️ Verify `.gitignore`                    |
| 7   | IAM policies follow least-privilege (no `*` resources)              | ✅ (fixed in IAM module)                  |
| 8   | OIDC policy scoped to specific S3 bucket via `s3_bucket_arn`        | ✅                                        |
| 9   | EC2 SSH ingress restricted to known CIDRs in prod                   | ⚠️ Review SG rules                        |
| 10  | Private subnets do not have a direct route to IGW                   | ⚠️ Review VPC private route table         |
| 11  | EKS node group does not use `AdministratorAccess` policy            | ✅ (uses scoped AWS managed policies)     |
| 12  | OIDC thumbprint derived from live TLS cert (`data.tls_certificate`) | ✅ (EKS module uses data source)          |
| 13  | EKS API endpoint public access disabled in dev/prod                 | ✅ (`endpoint_public_access = false`)     |
| 14  | EKS Auto Mode explicitly disabled (managed node groups used)        | ✅ (`compute_config { enabled = false }`) |
| 15  | EKS cluster version ≥ 1.29 for AWS provider 6.x compatibility       | ✅ (`cluster_version = "1.29"`)           |

> ⚠️ Items: ensure `terraform.tfvars` is listed in `.gitignore`, restrict SSH CIDR in production ingress rules, and verify the private route table does not route directly through the IGW (currently it does — consider adding a NAT Gateway for production environments).
