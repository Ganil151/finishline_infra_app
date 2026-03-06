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

Provisions the core networking layer for the Finishline AWS environment. This module creates a VPC with public and private subnets distributed across multiple availability zones.

#### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Internet Gateway (IGW)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         │                                      │
│         ┌──────────────┴──────────────┐                       │
│         │                             │                        │
│  ┌──────▼──────┐              ┌───────▼───────┐                │
│  │ Public RT  │              │  Private RT   │                │
│  └──────┬──────┘              └───────┬───────┘                │
│         │                             │                        │
│  ┌──────┼──────┐              ┌───────┼───────┐               │
│  │ Pubsubnet1 │              │ Privsubnet1 │               │
│  │ 10.0.1.0/24│              │ 10.0.4.0/24 │               │
│  │ us-east-1a │              │ us-east-1a  │               │
│  └─────────────┘              └─────────────┘               │
│  ┌─────────────┐              ┌─────────────┐               │
│  │ Pubsubnet2  │              │ Privsubnet2 │               │
│  │ 10.0.2.0/24│              │ 10.0.5.0/24 │               │
│  │ us-east-1b │              │ us-east-1b  │               │
│  └─────────────┘              └─────────────┘               │
│  ┌─────────────┐              ┌─────────────┐               │
│  │ Pubsubnet3  │              │ Privsubnet3 │               │
│  │ 10.0.3.0/24│              │ 10.0.6.0/24 │               │
│  │ us-east-1c │              │ us-east-1c  │               │
│  └─────────────┘              └─────────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

#### Resources Created

| Resource                      | Description                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------ |
| `aws_vpc`                     | Main VPC with configurable CIDR, DNS hostnames and support enabled                         |
| `aws_subnet` (public)         | Public subnets across availability zones, `map_public_ip_on_launch = true`, tagged for EKS |
| `aws_subnet` (private)        | Private subnets across availability zones, tagged for EKS                                  |
| `aws_internet_gateway`        | Internet Gateway attached to VPC for outbound internet access                              |
| `aws_eip`                     | Elastic IP allocated for potential NAT Gateway usage                                       |
| `aws_route_table` (public)    | Public route table with default route (0.0.0.0/0) via IGW                                  |
| `aws_route_table` (private)   | Private route table with default route (0.0.0.0/0) via IGW                                 |
| `aws_route_table_association` | Associates public and private subnets with their respective route tables                   |

#### Configuration Variables

| Variable                | Type         | Description                                       |
| ----------------------- | ------------ | ------------------------------------------------- |
| `project_name`          | string       | The name of the project (used in resource naming) |
| `environment`           | string       | The environment name (dev/staging/prod)           |
| `manage_by`             | string       | The entity responsible for managing resources     |
| `vpc_cidr`              | string       | The CIDR block for the VPC (e.g., `10.0.0.0/16`)  |
| `enable_dns_hostnames`  | bool         | Whether to enable DNS hostnames (default: `true`) |
| `enable_dns_support`    | bool         | Whether to enable DNS support (default: `true`)   |
| `availability_zones`    | list(string) | List of availability zones for subnet placement   |
| `public_subnets_cidrs`  | list(string) | CIDR blocks for public subnets                    |
| `private_subnets_cidrs` | list(string) | CIDR blocks for private subnets                   |

#### Outputs

| Output                    | Description                         |
| ------------------------- | ----------------------------------- |
| `main_vpc_id`             | The ID of the created VPC           |
| `main_public_subnet_ids`  | List of IDs for all public subnets  |
| `main_private_subnet_ids` | List of IDs for all private subnets |

#### Security Considerations

- **CIDR Range Selection**: Ensure the VPC CIDR does not overlap with any existing networks (on-premises VPN, other VPCs, etc.)
- **Public Subnet Access**: Resources in public subnets are directly accessible from the internet. Only place load balancers, NAT gateways, or bastion hosts in public subnets.
- **Private Subnet Isolation**: Resources in private subnets cannot be accessed directly from the internet.
- **Availability Zones**: For high availability, distribute subnets across multiple AZs (recommended: 3 for production).

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

### `modules/eks`

EKS cluster, OIDC identity provider, and managed node groups (on-demand + spot).

| Resource                              | Condition Variable          | Description                                            |
| ------------------------------------- | --------------------------- | ------------------------------------------------------ |
| `data.tls_certificate.eks_cert`       | `is_eks_cluster_enabled`    | Fetches TLS thumbprint for OIDC provider registration  |
| `aws_eks_cluster.eks`                 | `is_eks_cluster_enabled`    | EKS control plane with configurable Kubernetes version |
| `aws_iam_openid_connect_provider`     | `is_eks_cluster_enabled`    | OIDC identity provider derived from cluster issuer     |
| `aws_eks_node_group.ondemand-node`    | `is_eks_node_group_enabled` | On-demand managed node group with configurable scaling |
| `aws_eks_node_group.spot-node`        | `is_eks_node_group_enabled` | Spot managed node group with configurable scaling      |
| `aws_eks_addon.eks-addons` (for_each) | `is_eks_addons_enabled`     | EKS add-ons (CoreDNS, kube-proxy, vpc-cni, etc.)       |

**Key Variables**:

| Variable                    | Type         | Description                                               |
| --------------------------- | ------------ | --------------------------------------------------------- |
| `cluster_name`              | string       | EKS cluster name                                          |
| `cluster_version`           | string       | Kubernetes version (≥ 1.35 required for AWS provider 6.x) |
| `cluster_role_arn`          | string       | ARN of the EKS control-plane IAM role (from `secret/iam`) |
| `node_role_arn`             | string       | ARN of the EC2 node group IAM role (from `secret/iam`)    |
| `subnet_ids`                | list(string) | Private subnet IDs for cluster and node placement         |
| `security_group_ids`        | list(string) | Additional security group IDs attached to the cluster     |
| `endpoint_private_access`   | bool         | Enable private API endpoint access                        |
| `endpoint_public_access`    | bool         | Enable public API endpoint access                         |
| `cluster_enabled_log_types` | list(string) | Control plane logs: api, audit, authenticator, etc.       |
| `addons`                    | map(any)     | Add-on name → `{ version, service_account_role_arn? }`    |

**Outputs**: `cluster_id`, `cluster_arn`, `cluster_endpoint`, `cluster_version`, `cluster_certificate_authority_data`, `cluster_security_group_id`, `cluster_oidc_issuer`, `cluster_oidc_provider_arn`, `ondemand_node_group_id`, `ondemand_node_group_arn`, `spot_node_group_id`, `spot_node_group_arn`

> **Auto Mode note**: The module explicitly sets `compute_config { enabled = false }`, `storage_config { block_storage { enabled = false } }`, and `kubernetes_network_config { elastic_load_balancing { enabled = false } }` to opt out of EKS Auto Mode and use traditional managed node groups (required with AWS provider ≥ 6.x).

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
