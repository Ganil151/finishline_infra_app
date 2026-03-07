# VPC Module

This Terraform module creates a Virtual Private Cloud (VPC) infrastructure on AWS with public and private subnets, internet gateway, and route tables.

## Overview

The VPC module provisions a complete network infrastructure including:

- VPC with configurable CIDR block
- Internet Gateway for public internet access
- Public subnets with automatic IP assignment
- Private subnets for isolated resources
- Route tables for both public and private subnets
- Elastic IP (EIP) allocation

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC                                     │
│                    10.0.0.0/16                                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                 Internet Gateway (IGW)                    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│         ┌────────────────────┴────────────────────┐            │
│         │                                         │            │
│  ┌──────▼──────┐                          ┌───────▼───────┐     │
│  │ Public RT   │                          │  Private RT   │     │
│  │ 0.0.0.0/0   │                          │  0.0.0.0/0    │     │
│  └──────┬──────┘                          └───────┬───────┘     │
│         │                                         │             │
│  ┌──────┴──────┐                          ┌───────┴───────┐     │
│  │  Public    │                          │   Private     │     │
│  │ Subnets   Subnets        │                          │ │     │
│  │ (az1, az2) │                          │  (az1, az2, az3)   │     │
│  └─────────────┘                          └───────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name          = "finishline"
  environment           = "dev"
  manage_by             = "terraform"

  vpc_cidr              = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true

  availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24]
}
```

### Complete Example with All Outputs

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name          = "finishline"
  environment           = "prod"
  manage_by             = "terraform"

  vpc_cidr              = "172.16.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true

  availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets_cidrs = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  private_subnets_cidrs = ["172.16.10.0/24", "172.16.20.0/24", "172.16.30.0/24"]
}

# Use the VPC outputs
output "vpc_id" {
  value = module.vpc.main_vpc_id
}

output "public_subnets" {
  value = module.vpc.main_public_subnet_ids
}

output "private_subnets" {
  value = module.vpc.main_private_subnet_ids
}
```

## Variables

| Variable                | Description                                 | Type           | Required |
| ----------------------- | ------------------------------------------- | -------------- | -------- |
| `project_name`          | The name of the project                     | `string`       | Yes      |
| `environment`           | The environment (dev, staging, prod)        | `string`       | Yes      |
| `manage_by`             | The entity responsible for managing the VPC | `string`       | Yes      |
| `vpc_cidr`              | The CIDR block for the VPC                  | `string`       | Yes      |
| `enable_dns_hostnames`  | Whether to enable DNS hostnames             | `bool`         | Yes      |
| `enable_dns_support`    | Whether to enable DNS support               | `bool`         | Yes      |
| `public_subnets_cidrs`  | List of CIDR blocks for public subnets      | `list(string)` | Yes      |
| `private_subnets_cidrs` | List of CIDR blocks for private subnets     | `list(string)` | Yes      |
| `availability_zones`    | List of availability zones                  | `list(string)` | Yes      |

## Outputs

| Output                    | Description                     |
| ------------------------- | ------------------------------- |
| `main_vpc_id`             | The ID of the created VPC       |
| `main_public_subnet_ids`  | List of IDs for public subnets  |
| `main_private_subnet_ids` | List of IDs for private subnets |

## Resources Created

### 1. VPC (`aws_vpc`)

- Creates the main VPC with specified CIDR block
- Enables DNS hostnames and support

### 2. Internet Gateway (`aws_internet_gateway`)

- Provides internet access for public subnets
- Attached to the VPC

### 3. Public Subnets (`aws_subnet`)

- Created based on `public_subnets_cidrs` variable
- Auto-assign public IP enabled (`map_public_ip_on_launch = true`)
- Tagged for Kubernetes cluster auto-discovery

### 4. Private Subnets (`aws_subnet`)

- Created based on `private_subnets_cidrs` variable
- Auto-assign public IP enabled (configurable)
- Tagged for Kubernetes cluster auto-discovery

### 5. Elastic IP (`aws_eip`)

- Allocated for NAT Gateway (future use)
- Domain set to "vpc"

### 6. Route Tables

- **Public Route Table**: Routes 0.0.0.0/0 through Internet Gateway
- **Private Route Table**: Routes 0.0.0.0/0 through Internet Gateway (for NAT Gateway - future)

### 7. Route Table Associations

- Associates public subnets with public route table
- Associates private subnets with private route table

## Tagging Convention

All resources are tagged consistently:

- `Name`: `{project_name}-{environment}-{resource_type}`
- `ManagedBy`: The value of `manage_by` variable

### Kubernetes Tags

Public and private subnets include Kubernetes cluster tags:

- `kubernetes.io/cluster/{project_name}-{environment} = "owned"`

This allows Kubernetes to automatically discover the subnets for cluster placement.

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0

## Dependencies

This module has no external dependencies and can be run independently.

## Considerations

1. **CIDR Selection**: Ensure the VPC CIDR doesn't overlap with existing networks
2. **Availability Zones**: The number of subnets created equals the length of the availability zones list
3. **Subnet Sizing**: Ensure subnets have enough IP addresses for your workloads
4. **Future NAT Gateway**: The private route table is configured for future NAT Gateway integration

## Troubleshooting

### No Internet Access from Public Subnets

- Check that the Internet Gateway is properly attached
- Verify route table has 0.0.0.0/0 route to IGW
- Ensure security groups allow outbound traffic

### DNS Resolution Issues

- Verify `enable_dns_hostnames` and `enable_dns_support` are set to `true`
- Check VPC DNS settings in AWS Console

### Subnets Not Found by Kubernetes

The VPC module automatically tags subnets with Kubernetes cluster tags to enable EKS subnet discovery. Here's why this is important:

**How Kubernetes Subnet Discovery Works:**

1. **Automatic Discovery**: AWS EKS uses a subnet discovery mechanism to identify which subnets should be used for pod placement, load balancer creation, and ENI/IP allocation

2. **Tag-Based Discovery**: Kubernetes controllers scan for subnets with the tag `kubernetes.io/cluster/<cluster-name>`

3. **Tag Value Significance:**
   - `owned`: The cluster owns these subnets - worker nodes will use them for pod scheduling
   - `shared`: The subnets are shared from another account (less common)

**Tag Format:**

| Tag Key                                | Tag Value | Meaning                             |
| -------------------------------------- | --------- | ----------------------------------- |
| `kubernetes.io/cluster/<cluster-name>` | `owned`   | Cluster owns these subnets          |
| `kubernetes.io/cluster/<cluster-name>` | `shared`  | Subnets shared from another account |

**Example:**
For `project_name = "finishline"` and `environment = "dev"`:

```
Key: kubernetes.io/cluster/finishline-dev
Value: owned
```

**Without These Tags:**

- EKS can't auto-discover subnets for pod placement
- AWS Load Balancer Controller won't create ALBs/NLBs properly
- VPC CNI plugin may fail to allocate IPs to pods

**Troubleshooting Steps:**

- Ensure the Kubernetes cluster tag format matches: `kubernetes.io/cluster/{project_name}-{environment}`
- Verify the EKS cluster name matches the tag (e.g., cluster_name = "finishline-dev")
- Tag value must be "owned" for worker nodes to use the subnets

## Integration with Other Modules

### EKS Module

```hcl
module "eks" {
  source = "../eks"
  # ...
  subnet_ids = module.vpc.main_private_subnet_ids
}
```

### EC2 Module

```hcl
module "ec2" {
  source = "../ec2"
  vpc_id            = module.vpc.main_vpc_id
  public_subnet_ids = module.vpc.main_public_subnet_ids
}
```

### Security Group Module

```hcl
module "security_group" {
  source = "../security_group"
  vpc_id = module.vpc.main_vpc_id
}
```
