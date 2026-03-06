# Finishline Infrastructure App

Terraform infrastructure-as-code project for the Finishline application. It provisions a full AWS environment including networking, compute security, key management, and EKS IAM roles using a reusable modular structure.

---

## Project File Tree

```
finishline_infra_app/
├── README.md
├── .gitignore
├── docs/
│   ├── Finishline_Infra_Project_Assignment.pdf
│   └── script/
│       └── terraInfra_1.sh
└── terraform/
    ├── environments/
    │   ├── dev/
    │   │   ├── backend.tf          # S3 remote state backend (dev)
    │   │   ├── main.tf             # Module orchestration for dev
    │   │   ├── providers.tf        # AWS provider with default tags
    │   │   ├── variables.tf        # Environment-level variable declarations
    │   │   ├── version.tf          # Terraform & provider version constraints
    │   │   └── finishline-key-pair.pem  # (gitignored) Generated EC2 key pair
    │   ├── staging/
    │   │   ├── backend.tf
    │   │   ├── main.tf
    │   │   ├── output.tf
    │   │   ├── providers.tf
    │   │   └── variables.tf
    │   └── prod/
    │       ├── backend.tf
    │       ├── main.tf
    │       ├── output.tf
    │       ├── providers.tf
    │       └── variables.tf
    └── modules/
        ├── vpc/
        │   ├── main.tf             # VPC, subnets, IGW, NAT, route tables
        │   ├── variables.tf
        │   └── output.tf
        ├── security_group/
        │   ├── main.tf             # Dynamic ingress/egress security group
        │   ├── variables.tf
        │   └── output.tf
        ├── secret/
        │   ├── iam/
        │   │   ├── main.tf         # EKS cluster role, node group role, OIDC provider & role
        │   │   ├── variables.tf
        │   │   └── output.tf
        │   └── key_pair/
        │       ├── main.tf         # RSA-4096 TLS key + AWS key pair + local .pem file
        │       ├── variables.tf
        │       └── output.tf
        ├── alb/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── output.tf
        ├── ec2/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── output.tf
        ├── eks/
        │   ├── main.tf
        │   ├── addons.tf
        │   ├── variables.tf
        │   └── output.tf
        └── bootstrap/
            └── {versions}.tf
```

---

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────────┐
                          │                    AWS Account                       │
                          │                                                      │
                          │   ┌──────────────────────────────────────────────┐  │
                          │   │                  VPC Module                  │  │
                          │   │                                              │  │
                          │   │  ┌───────────────┐    ┌───────────────┐     │  │
                          │   │  │ Public Subnets│    │Private Subnets│     │  │
                          │   │  │  (x AZs)      │    │  (x AZs)      │     │  │
                          │   │  └──────┬────────┘    └───────┬───────┘     │  │
                          │   │         │                      │             │  │
                          │   │   Internet Gateway          NAT EIP          │  │
                          │   └─────────────────────────────────────────────┘  │
                          │                                                      │
                          │   ┌──────────────┐    ┌───────────────────────────┐ │
                          │   │ Security     │    │   Secrets Module          │ │
                          │   │ Group Module │    │                           │ │
                          │   │ (dynamic SG) │    │  ┌──────────┐ ┌────────┐ │ │
                          │   └──────────────┘    │  │  IAM     │ │Key Pair│ │ │
                          │                       │  │ (EKS/    │ │(RSA    │ │ │
                          │                       │  │  OIDC)   │ │ 4096)  │ │ │
                          │                       │  └──────────┘ └────────┘ │ │
                          │                       └───────────────────────────┘ │
                          │                                                      │
                          │   ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
                          │   │   EKS    │  │   ALB    │  │       EC2        │  │
                          │   │  Module  │  │  Module  │  │      Module      │  │
                          │   └──────────┘  └──────────┘  └──────────────────┘  │
                          └─────────────────────────────────────────────────────┘
```

---

## Modules

### `modules/vpc`

Provisions the core networking layer.

| Resource                      | Description                                               |
| ----------------------------- | --------------------------------------------------------- |
| `aws_vpc`                     | Main VPC with configurable CIDR                           |
| `aws_subnet` (public)         | Public subnets across availability zones, tagged for EKS  |
| `aws_subnet` (private)        | Private subnets across availability zones, tagged for EKS |
| `aws_internet_gateway`        | Internet Gateway attached to VPC                          |
| `aws_eip`                     | Elastic IP for NAT gateway                                |
| `aws_route_table` (public)    | Routes public traffic via IGW                             |
| `aws_route_table` (private)   | Private route table                                       |
| `aws_route_table_association` | Associates subnets to route tables                        |

**Outputs**: `main_vpc_id`, subnet IDs

---

### `modules/security_group`

Creates a dynamic security group with user-supplied ingress/egress rules.

| Resource             | Description                             |
| -------------------- | --------------------------------------- |
| `aws_security_group` | Dynamic inbound rules, allow-all egress |

---

### `modules/secret/key_pair`

Generates and stores an RSA-4096 EC2 key pair.

| Resource          | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| `tls_private_key` | RSA 4096-bit key generated by Terraform                         |
| `aws_key_pair`    | Registers the public key in AWS                                 |
| `local_file`      | Writes the private key to a `.pem` file with `0400` permissions |

**Outputs**: `key_name`

---

### `modules/secret/iam`

Manages EKS IAM roles and OIDC identity federation. All resources are conditional via boolean variables.

| Resource                                                | Condition Variable              | Description                                      |
| ------------------------------------------------------- | ------------------------------- | ------------------------------------------------ |
| `aws_iam_role.eks-cluster-role`                         | `is_eks_role_enabled`           | EKS cluster service role                         |
| `aws_iam_role_policy_attachment.AmazonEKSClusterPolicy` | `is_eks_role_enabled`           | Attaches `AmazonEKSClusterPolicy`                |
| `aws_iam_role.eks-nodegroup-role`                       | `is_eks_nodegroup_role_enabled` | EC2 node group role                              |
| `aws_iam_role_policy_attachment.node-policies`          | `is_eks_nodegroup_role_enabled` | Attaches Worker Node, CNI, ECR, EBS CSI policies |
| `aws_iam_openid_connect_provider.eks-oidc-provider`     | `is_eks_cluster_enabled`        | OIDC identity provider for EKS                   |
| `aws_iam_role.eks_oidc`                                 | `is_eks_cluster_enabled`        | IAM role for workload identity via OIDC          |
| `aws_iam_policy.eks-oidc-policy`                        | `is_eks_cluster_enabled`        | Scoped S3 access policy for OIDC role            |
| `aws_iam_role_policy_attachment.eks-oidc-policy-attach` | `is_eks_cluster_enabled`        | Attaches OIDC S3 policy to the OIDC role         |

**Variables**:

| Variable                        | Type           | Description                                                         |
| ------------------------------- | -------------- | ------------------------------------------------------------------- |
| `cluster_name`                  | `string`       | EKS cluster name (used as name prefix)                              |
| `is_eks_role_enabled`           | `bool`         | Enable EKS cluster role                                             |
| `is_eks_nodegroup_role_enabled` | `bool`         | Enable EKS node group role                                          |
| `is_eks_cluster_enabled`        | `bool`         | Enable OIDC provider and OIDC IAM role                              |
| `eks_oidc_url`                  | `string`       | OIDC issuer URL from the EKS cluster                                |
| `oidc_thumbprint`               | `list(string)` | TLS thumbprints for OIDC provider (default: AWS root CA)            |
| `s3_bucket_arn`                 | `string`       | S3 bucket name to scope the OIDC policy (leave empty = all buckets) |

**Outputs**: `eks_cluster_role_arn`, `eks_cluster_role_name`, `eks_nodegroup_role_arn`, `eks_nodegroup_role_name`, `eks_oidc_role_arn`, `eks_oidc_role_name`, `eks_oidc_policy_arn`, `eks_oidc_provider_arn`, `eks_oidc_provider_url`

---

### `modules/alb` _(pending implementation)_

Application Load Balancer configuration.

### `modules/ec2` _(pending implementation)_

EC2 instance configuration.

### `modules/eks` _(pending implementation)_

EKS cluster and managed node group configuration.

---

## Environments

| Environment | State Backend                                                 | Status  |
| ----------- | ------------------------------------------------------------- | ------- |
| `dev`       | S3: `finishline-infra-app-9e1f6284` / `dev/terraform.tfstate` | Active  |
| `staging`   | _(not configured)_                                            | Pending |
| `prod`      | _(not configured)_                                            | Pending |

---

## Remote State

State is stored in S3 with native locking (`use_lockfile = true`) and server-side encryption enabled:

```hcl
backend "s3" {
  bucket       = "finishline-infra-app-9e1f6284"
  key          = "dev/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
  encrypt      = true
}
```

---

## Usage

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- S3 bucket for remote state already bootstrapped (see `modules/bootstrap/`)

### Deploy (dev)

```bash
cd terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Destroy

```bash
cd terraform/environments/dev
terraform destroy
```

---

## Tagging Strategy

All resources are tagged via the AWS provider `default_tags` block:

| Tag           | Value                                             |
| ------------- | ------------------------------------------------- |
| `Environment` | `var.environment` (e.g. `dev`, `staging`, `prod`) |
| `Project`     | `var.project_name`                                |
| `ManagedBy`   | `var.manage_by` (e.g. `Terraform`)                |
