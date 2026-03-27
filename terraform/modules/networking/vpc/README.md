# VPC Module

This Terraform module creates and configures a complete AWS VPC (Virtual Private Cloud) infrastructure for the Finishline project. It includes public and private subnets, internet gateway, NAT gateway, route tables, and network ACL's with optional Karpenter integration for EKS cluster autoscaling.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Required Variables](#required-variables)
  - [Optional Variables](#optional-variables)
  - [CIDR Planning](#cidr-planning)
  - [Availability Zones](#availability-zones)
- [Outputs](#outputs)
- [Karpenter Integration](#karpenter-integration)
- [Tags](#tags)
- [Network Security](#network-security)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [AWS CLI Troubleshooting Commands](#aws-cli-troubleshooting-commands)
- [Module Structure](#module-structure)

---

## Overview

The VPC module provisions a production-ready network infrastructure on AWS with the following components:

- **VPC**: Main network container with configurable CIDR block
- **Internet Gateway**: Enables internet access for public subnets
- **NAT Gateway**: Enables outbound internet access for private subnets
- **Public Subnets**: For resources requiring direct internet access (load balancers, bastion hosts)
- **Private Subnets**: For internal resources (application servers, databases)
- **Route Tables**: Separate routing for public and private subnets
- **Network ACLs**: Stateless firewall rules for public subnets

This module follows AWS best practices for high availability, security, and scalability.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC                                         │
│                        10.0.0.0/16                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      Internet Gateway                              │  │
│  │                           │                                        │  │
│  │  ┌────────────────────────┴────────────────────────────────┐      │  │
│  │  │                   Public Route Table                     │      │  │
│  │  │              0.0.0.0/0 → IGW                             │      │  │
│  │  └────────────────────────┬────────────────────────────────┘      │  │
│  │                           │                                        │  │
│  │  ┌─────────────┐  ┌───────┴────────┐  ┌─────────────┐             │  │
│  │  │  Public     │  │   Public       │  │  Public     │             │  │
│  │  │  Subnet 1   │  │   Subnet 2     │  │  Subnet N   │             │  │
│  │  │  (AZ-a)     │  │   (AZ-b)       │  │  (AZ-n)     │             │  │
│  │  └──────┬──────┘  └────────┬───────┘  └──────┬──────┘             │  │
│  │         │                  │                  │                     │  │
│  │         └──────────────────┼──────────────────┘                     │  │
│  │                            │                                        │  │
│  │                    ┌───────┴───────┐                                │  │
│  │                    │  NAT Gateway  │                                │  │
│  │                    └───────┬───────┘                                │  │
│  │                            │                                        │  │
│  │  ┌─────────────────────────┴────────────────────────────────┐      │  │
│  │  │                  Private Route Table                      │      │  │
│  │  │             0.0.0.0/0 → NAT GW                            │      │  │
│  │  └─────────────────────────┬────────────────────────────────┘      │  │
│  │                            │                                        │  │
│  │  ┌─────────────┐  ┌────────┴────────┐  ┌─────────────┐             │  │
│  │  │  Private    │  │   Private       │  │  Private    │             │  │
│  │  │  Subnet 1   │  │   Subnet 2      │  │  Subnet N   │             │  │
│  │  │  (AZ-a)     │  │   (AZ-b)        │  │  (AZ-n)     │             │  │
│  │  └─────────────┘  └─────────────────┘  └─────────────┘             │  │
│  │                                                                    │  │
│  │  ┌────────────────────────────────────────────────────────────┐   │  │
│  │  │              Network ACL (Public Subnets)                   │   │  │
│  │  │         Stateful Ingress/Egress Rules                       │   │  │
│  │  └────────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Traffic Flow

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnet (Load Balancer, Bastion)
    │
    ▼
Private Subnet (Application Servers)
    │
    ▼
Database / Cache (Private Subnet)
    │
    ▼
NAT Gateway (for outbound traffic)
    │
    ▼
Internet
```

---

## Features

| Feature                       | Description                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------- |
| **Multi-AZ Deployment**       | Subnets distributed across multiple availability zones for high availability |
| **Public/Private Separation** | Clear network segmentation for security                                      |
| **NAT Gateway**               | Outbound internet access for private subnets                                 |
| **Route Tables**              | Separate routing for public and private traffic                              |
| **Network ACLs**              | Additional layer of security for public subnets                              |
| **Karpenter Support**         | Optional discovery tags for EKS cluster autoscaling                          |
| **DNS Support**               | Enabled DNS resolution and hostnames                                         |
| **Elastic IP**                | Dedicated public IPs for NAT gateways                                        |

---

## Usage

### Basic Example

```hcl
module "vpc" {
  source = "./modules/networking/vpc"

  # Required variables
  project_name             = "finishline"
  environment              = "prod"
  managed_by               = "platform-team"
  aws_region               = "us-west-2"
  vpc_cidr                 = "10.0.0.0/16"
  availability_zones       = ["us-west-2a", "us-west-2b"]
  public_subnets_cidr      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr     = ["10.0.10.0/24", "10.0.11.0/24"]

  # Network ACL rules (required)
  ingress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 120
      from_port  = 22
      to_port    = 22
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    },
    {
      rule_no    = 32767
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "deny"
      cidr_block = "0.0.0.0/0"
    }
  ]

  egress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]

  # Optional: Karpenter integration
  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-prod"
}
```

---

## Configuration

### Required Variables

| Variable                  | Type           | Description                                                          | Example                            |
| ------------------------- | -------------- | -------------------------------------------------------------------- | ---------------------------------- |
| `project_name`            | `string`       | Name of the project. Used in resource naming and tagging.            | `"finishline"`                     |
| `environment`             | `string`       | Environment name. Determines resource naming and access levels.      | `"dev"`, `"stage"`, `"prod"`       |
| `managed_by`              | `string`       | Team or department managing this resource. Used for cost allocation. | `"platform-team"`                  |
| `aws_region`              | `string`       | AWS region where resources will be created.                          | `"us-west-2"`                      |
| `vpc_cidr`                | `string`       | CIDR block for the VPC. Should be a private IP range.                | `"10.0.0.0/16"`                    |
| `public_subnets_cidr`     | `list(string)` | List of CIDR blocks for public subnets. Must be within VPC CIDR.     | `["10.0.1.0/24", "10.0.2.0/24"]`   |
| `private_subnets_cidr`    | `list(string)` | List of CIDR blocks for private subnets. Must be within VPC CIDR.    | `["10.0.10.0/24", "10.0.11.0/24"]` |
| `availability_zones`      | `list(string)` | List of availability zones. Must match the number of subnets.        | `["us-west-2a", "us-west-2b"]`     |
| `ingress_rules_transform` | `list(object)` | Network ACL ingress rules for public subnets.                        | See [NACL Rules](#nacl-rules)      |
| `egress_rules_transform`  | `list(object)` | Network ACL egress rules for public subnets.                         | See [NACL Rules](#nacl-rules)      |

### Optional Variables

| Variable                     | Type          | Default | Description                                |
| ---------------------------- | ------------- | ------- | ------------------------------------------ |
| `enable_dns_support`         | `bool`        | `true`  | Enable DNS resolution in the VPC           |
| `enable_dns_hostnames`       | `bool`        | `true`  | Enable DNS hostnames in the VPC            |
| `enable_karpenter_discovery` | `bool`        | `false` | Enable Karpenter discovery tags on subnets |
| `karpenter_cluster_name`     | `string`      | `""`    | EKS cluster name for Karpenter discovery   |
| `computed_tags`              | `map(string)` | `{}`    | Additional tags to apply to all resources  |

### CIDR Planning

Proper CIDR planning is crucial for network scalability. Here's a recommended structure:

```
VPC: 10.0.0.0/16 (65,536 IPs)
│
├── Public Subnets: 10.0.1.0/24 - 10.0.4.0/24 (256 IPs each)
│   ├── 10.0.1.0/24 - AZ-a (Load Balancers, Bastion)
│   ├── 10.0.2.0/24 - AZ-b (Load Balancers, Bastion)
│   └── 10.0.3.0/24 - AZ-c (Load Balancers, Bastion)
│
├── Private Subnets: 10.0.10.0/24 - 10.0.49.0/24 (256 IPs each)
│   ├── Application: 10.0.10.0/24 - 10.0.19.0/24
│   ├── Database:    10.0.20.0/24 - 10.0.29.0/24
│   ├── Cache:       10.0.30.0/24 - 10.0.39.0/24
│   └── EKS Nodes:   10.0.40.0/24 - 10.0.49.0/24
│
└── Reserved: 10.0.50.0/24 - 10.0.255.0/24 (Future expansion)
```

### Subnet Sizing Guide

| CIDR | Available IPs | Use Case                            |
| ---- | ------------- | ----------------------------------- |
| /24  | 251           | Small subnets, bastion hosts        |
| /23  | 507           | Medium subnets, application servers |
| /22  | 1,019         | Large subnets, EKS nodes            |
| /21  | 2,043         | Very large subnets, databases       |
| /20  | 4,091         | Extra large subnets, multi-tenant   |

> **Note**: AWS reserves 5 IP addresses in each subnet (first 4 and last 1).

### Availability Zones

For production environments, always deploy across multiple AZs:

```hcl
# Production (3 AZs for high availability)
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Development (2 AZs for cost savings)
availability_zones = ["us-west-2a", "us-west-2b"]

# Single AZ (testing only)
availability_zones = ["us-west-2a"]
```

### NACL Rules

Network ACLs provide stateless filtering at the subnet level. Example rules:

```hcl
# Ingress Rules
ingress_rules_transform = [
  # Allow HTTP from internet
  {
    rule_no    = 100
    from_port  = 80
    to_port    = 80
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  },
  # Allow HTTPS from internet
  {
    rule_no    = 110
    from_port  = 443
    to_port    = 443
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  },
  # Allow SSH from VPC only
  {
    rule_no    = 120
    from_port  = 22
    to_port    = 22
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "10.0.0.0/16"
  },
  # Allow ephemeral ports for return traffic
  {
    rule_no    = 130
    from_port  = 1024
    to_port    = 65535
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  },
  # Deny all other traffic (implicit, but explicit is better)
  {
    rule_no    = 32767
    from_port  = 0
    to_port    = 65535
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
  }
]

# Egress Rules
egress_rules_transform = [
  # Allow all outbound traffic
  {
    rule_no    = 100
    from_port  = 0
    to_port    = 65535
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
  }
]
```

### Protocol Reference for NACL

| Protocol | Number | Description                       |
| -------- | ------ | --------------------------------- |
| TCP      | `6`    | Transmission Control Protocol     |
| UDP      | `17`   | User Datagram Protocol            |
| ICMP     | `1`    | Internet Control Message Protocol |
| All      | `-1`   | All protocols                     |

---

## Outputs

| Output                 | Type           | Description                      |
| ---------------------- | -------------- | -------------------------------- |
| `vpc_id`               | `string`       | The ID of the created VPC        |
| `public_subnets_ids`   | `list(string)` | List of public subnet IDs        |
| `private_subnets_ids`  | `list(string)` | List of private subnet IDs       |
| `nat_gateway_ids`      | `list(string)` | List of NAT gateway IDs          |
| `internet_gateway_ids` | `string`       | The ID of the internet gateway   |
| `route_table_ids`      | `list(string)` | List of route table IDs (public) |

### Using Outputs

```hcl
# Reference VPC ID for other modules
module "vpc" {
  source = "./modules/networking/vpc"
  # ... configuration
}

# Use in security group module
module "security_group" {
  source = "./modules/networking/sg"
  vpc_id = module.vpc.vpc_id
}

# Use in EC2 module
resource "aws_instance" "app" {
  subnet_id = module.vpc.private_subnets_ids[0]
}

# Use in EKS module
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets_ids
}
```

---

## Karpenter Integration

[Karpenter](https://karpenter.sh/) is an open-source node provisioning project for Kubernetes. This module supports Karpenter discovery tags to enable automatic subnet discovery for EKS node provisioning.

### Configuration

```hcl
module "vpc" {
  source = "./modules/networking/vpc"

  project_name             = "finishline"
  environment              = "prod"
  managed_by               = "platform-team"
  aws_region               = "us-west-2"
  vpc_cidr                 = "10.0.0.0/16"
  availability_zones       = ["us-west-2a", "us-west-2b"]
  public_subnets_cidr      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr     = ["10.0.10.0/24", "10.0.11.0/24"]

  # Enable Karpenter discovery
  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-prod"

  # ... NACL rules
}
```

### How It Works

When `enable_karpenter_discovery` is set to `true`:

1. The module adds the tag `karpenter.sh/discovery = <karpenter_cluster_name>` to all subnets
2. Karpenter's AWS provisioner is configured with the same cluster name
3. Karpenter automatically discovers these subnets for node provisioning
4. New nodes are launched in the tagged subnets with appropriate security groups

### Karpenter Provisioner Configuration

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: 'topology.kubernetes.io/zone'
      operator: In
      values: ['us-west-2a', 'us-west-2b']
  provider:
    subnetSelector:
      karpenter.sh/discovery: 'finishline-prod'
    securityGroupSelector:
      karpenter.sh/discovery: 'finishline-prod'
```

---

## Tags

The module automatically applies the following tags to all resources:

| Tag Key                  | Value                                          | Purpose                        |
| ------------------------ | ---------------------------------------------- | ------------------------------ |
| `Name`                   | `{project_name}-{environment}-{resource_type}` | Resource identification        |
| `Project`                | `{project_name}`                               | Cost allocation                |
| `Environment`            | `{environment}`                                | Environment identification     |
| `Managed_By`             | `{managed_by}`                                 | Team ownership                 |
| `Type`                   | `public` or `private`                          | Subnet type (subnets only)     |
| `karpenter.sh/discovery` | `{karpenter_cluster_name}`                     | Karpenter discovery (optional) |

---

## Network Security

### Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: VPC Boundary                                        │
│ - Isolated network environment                               │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│ Layer 2: Network ACLs (Stateless)                              │
│ - Subnet-level firewall                                        │
│ - Ingress/Egress rules                                         │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│ Layer 3: Security Groups (Stateful)                            │
│ - Instance-level firewall                                      │
│ - Ingress/Egress rules                                         │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│ Layer 4: Instance OS Firewall                                  │
│ - iptables/nftables                                            │
│ - Application-level security                                   │
└─────────────────────────────────────────────────────────────┘
```

### Best Practices

1. **Use Private Subnets for Sensitive Workloads**
   - Databases, caches, and application servers should be in private subnets
   - Only load balancers and bastion hosts in public subnets

2. **Implement Least Privilege in NACLs**
   - Start with deny-all rules
   - Allow only required ports and protocols
   - Use specific CIDR blocks instead of 0.0.0.0/0

3. **Enable VPC Flow Logs**
   - Monitor network traffic for security analysis
   - Troubleshoot connectivity issues
   - Meet compliance requirements

4. **Use Security Groups with NACLs**
   - NACLs for coarse-grained filtering
   - Security groups for fine-grained control

---

## Examples

### Development Environment

```hcl
module "vpc_dev" {
  source = "./modules/networking/vpc"

  project_name         = "finishline"
  environment          = "dev"
  managed_by           = "dev-team"
  aws_region           = "us-west-2"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24"]

  ingress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 32767
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "deny"
      cidr_block = "0.0.0.0/0"
    }
  ]

  egress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]
}
```

### Production Environment with Karpenter

```hcl
module "vpc_prod" {
  source = "./modules/networking/vpc"

  project_name         = "finishline"
  environment          = "prod"
  managed_by           = "platform-team"
  aws_region           = "us-west-2"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-prod"

  ingress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 120
      from_port  = 22
      to_port    = 22
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    },
    {
      rule_no    = 130
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 32767
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "deny"
      cidr_block = "0.0.0.0/0"
    }
  ]

  egress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]
}
```

### Multi-Tier Application VPC

```hcl
module "vpc_multitier" {
  source = "./modules/networking/vpc"

  project_name         = "finishline"
  environment          = "prod"
  managed_by           = "platform-team"
  aws_region           = "us-west-2"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = [
    # Web tier
    "10.0.10.0/24", "10.0.11.0/24",
    # App tier
    "10.0.20.0/24", "10.0.21.0/24",
    # Data tier
    "10.0.30.0/24", "10.0.31.0/24"
  ]

  ingress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 110
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    },
    {
      rule_no    = 32767
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "deny"
      cidr_block = "0.0.0.0/0"
    }
  ]

  egress_rules_transform = [
    {
      rule_no    = 100
      from_port  = 0
      to_port    = 65535
      protocol   = "-1"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  ]
}
```

---

## Troubleshooting

### Issue: Cannot Access Resources in Public Subnet

**Symptoms**: Instances in public subnet cannot be accessed from the internet.

**Possible Causes**:

1. Internet gateway not attached to VPC
2. Route table missing default route to IGW
3. Security group blocking traffic
4. NACL blocking traffic

**Resolution**:

```hcl
# Verify internet gateway is attached
# Check route table has 0.0.0.0/0 → IGW
# Review security group ingress rules
# Review NACL ingress rules
```

### Issue: Private Subnet Cannot Access Internet

**Symptoms**: Instances in private subnet cannot download packages or access external APIs.

**Possible Causes**:

1. NAT gateway not created
2. Route table missing default route to NAT
3. NAT gateway in wrong subnet
4. Security group blocking outbound traffic

**Resolution**:

```hcl
# Verify NAT gateway exists and is in public subnet
# Check private route table has 0.0.0.0/0 → NAT
# Review security group egress rules
```

### Issue: Subnets Running Out of IP Addresses

**Symptoms**: Cannot launch new instances in subnet.

**Possible Causes**:

1. Subnet CIDR too small
2. Too many resources in subnet

**Resolution**:

- Deploy additional subnets with larger CIDR
- Use multiple subnets across AZs
- Consider using /20 or /19 instead of /24

### Issue: Karpenter Cannot Discover Subnets

**Symptoms**: Karpenter fails to provision nodes.

**Possible Causes**:

1. Karpenter discovery tag missing
2. Cluster name mismatch
3. Provisioner configuration incorrect

**Resolution**:

```hcl
# Verify enable_karpenter_discovery = true
# Verify karpenter_cluster_name matches provisioner config
# Check subnet tags with AWS CLI
```

---

## AWS CLI Troubleshooting Commands

### VPC Inspection

#### List All VPCs

```bash
# List all VPCs with details
aws ec2 describe-vpcs \
  --query "Vpcs[*].[VpcId,CidrBlock,State,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# List VPCs with specific tag
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=finishline" \
  --query "Vpcs[*].[VpcId,CidrBlock,State]" \
  --output table

# Describe specific VPC
aws ec2 describe-vpcs \
  --vpc-ids vpc-0abc123def456 \
  --query "Vpcs[0]" \
  --output json
```

#### Check VPC Attributes

```bash
# Check DNS support
aws ec2 describe-vpc-attribute \
  --vpc-id vpc-0abc123def456 \
  --attribute enableDnsSupport

# Check DNS hostnames
aws ec2 describe-vpc-attribute \
  --vpc-id vpc-0abc123def456 \
  --attribute enableDnsHostnames
```

### Subnet Diagnostics

#### List Subnets

```bash
# List all subnets in VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,State.AvailableIpAddressCount,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# List public subnets only
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" "Name=tag:Type,Values=public" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]" \
  --output table

# List private subnets only
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" "Name=tag:Type,Values=private" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]" \
  --output table

# Check subnet IP availability
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "Subnets[*].[SubnetId,CidrBlock,State.AvailableIpAddressCount]" \
  --output table
```

#### Check Subnet Tags (Karpenter)

```bash
# List subnets with Karpenter discovery tag
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=finishline-prod" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags]" \
  --output table

# Verify Karpenter tag on all subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "Subnets[*].[SubnetId,Tags[?Key=='karpenter.sh/discovery'].Value|[0]]" \
  --output table
```

### Internet Gateway Diagnostics

```bash
# List internet gateways attached to VPC
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-0abc123def456" \
  --query "InternetGateways[*].[InternetGatewayId,Attachments[0].State]" \
  --output table

# Check IGW status
aws ec2 describe-internet-gateways \
  --internet-gateway-ids igw-0abc123def456 \
  --query "InternetGateways[0].{IGW:InternetGatewayId,State:Attachments[0].State,VPC:Attachments[0].VpcId}" \
  --output table
```

### NAT Gateway Diagnostics

```bash
# List NAT gateways in VPC
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "NatGateways[*].[NatGatewayId,State,NatGatewayAddresses[0].{PublicIp:PublicIp,AllocationId:AllocationId},SubnetId]" \
  --output table

# Check NAT gateway status details
aws ec2 describe-nat-gateways \
  --nat-gateway-ids nat-0abc123def456 \
  --query "NatGateways[0].{State:State,CreateTime:CreateTime,SubnetId:SubnetId,VpcId:VpcId}" \
  --output json

# Check NAT gateway connectivity
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "NatGateways[*].[NatGatewayId,State,ConnectivityType]" \
  --output table
```

### Route Table Diagnostics

```bash
# List all route tables in VPC
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "RouteTables[*].[RouteTableId,Associations[*].SubnetId,Routes[*].[DestinationCidrBlock,GatewayId,State,Origin]]" \
  --output table

# Check public route table
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" "Name=tag:Name,Values=*public*" \
  --query "RouteTables[*].[RouteTableId,Routes[*].[DestinationCidrBlock,GatewayId]]" \
  --output table

# Check private route table
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" "Name=tag:Name,Values=*private*" \
  --query "RouteTables[*].[RouteTableId,Routes[*].[DestinationCidrBlock,GatewayId]]" \
  --output table

# Verify route to internet gateway
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "RouteTables[*].{RT:RouteTableId,Routes:Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId}" \
  --output table
```

### Network ACL Diagnostics

```bash
# List all NACLs in VPC
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "NetworkAcls[*].[NetworkAclId,Entries[?RuleNumber<=`32000`].[RuleNumber,FromPort,ToPort,Protocol,Action,CidrBlock]]" \
  --output table

# Check NACL associations
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "NetworkAcls[*].[NetworkAclId,Associations[*].SubnetId]" \
  --output table

# Check specific NACL rules
aws ec2 describe-network-acls \
  --network-acl-id nacl-0abc123def456 \
  --query "NetworkAcls[0].{Ingress:Entries[?Egress==`false`],Egress:Entries[?Egress==`true`]}" \
  --output table
```

### Connectivity Testing

#### Test Internet Connectivity from Instance

```bash
# SSH to instance in public subnet and test
ssh -i key.pem ec2-user@<public-ip> "curl -I https://www.google.com"

# SSH to instance in private subnet (via bastion) and test
ssh -i key.pem -o ProxyJump="ec2-user@<bastion-ip>" ec2-user@<private-ip> "curl -I https://www.google.com"

# Test DNS resolution
ssh -i key.pem ec2-user@<public-ip> "nslookup www.google.com"
```

#### Test NAT Gateway Connectivity

```bash
# From instance in private subnet, check public IP
ssh -i key.pem -o ProxyJump="ec2-user@<bastion-ip>" ec2-user@<private-ip> "curl -s https://checkip.amazonaws.com"

# Verify NAT gateway IP matches
aws ec2 describe-nat-gateways \
  --nat-gateway-ids nat-0abc123def456 \
  --query "NatGateways[0].NatGatewayAddresses[0].PublicIp" \
  --output text
```

### VPC Flow Logs

#### Enable Flow Logs

```bash
# Create CloudWatch log group
aws logs create-log-group \
  --log-group-name "/aws/vpc/flow-logs"

# Create IAM role for flow logs (requires trust policy and permissions)

# Enable flow logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-0abc123def456 \
  --traffic-type ALL \
  --log-group-name "/aws/vpc/flow-logs" \
  --deliver-logs-permission-arn "arn:aws:iam::ACCOUNT_ID:role/vpc-flow-logs-role"
```

#### Query Flow Logs

```bash
# Query rejected traffic
aws logs filter-log-events \
  --log-group-name "/aws/vpc/flow-logs" \
  --filter-pattern "REJECT" \
  --start-time $(date -d "1 hour ago" +%s)000 \
  --query "events[*].message" \
  --output table

# Query traffic to specific port
aws logs filter-log-events \
  --log-group-name "/aws/vpc/flow-logs" \
  --filter-pattern "22" \
  --start-time $(date -d "1 hour ago" +%s)000 \
  --query "events[*].message" \
  --output table
```

### Automation Scripts

#### VPC Health Check Script

```bash
#!/bin/bash
# vpc_health_check.sh

VPC_ID="vpc-0abc123def456"
REGION="us-west-2"

echo "=== VPC Health Check: $VPC_ID ==="
echo

# Check VPC exists
VPC_STATUS=$(aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --region $REGION \
  --query "Vpcs[0].State" \
  --output text)
echo "VPC State: $VPC_STATUS"

# Check Internet Gateway
IGW_STATE=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "InternetGateways[0].Attachments[0].State" \
  --output text)
echo "Internet Gateway: $IGW_STATE"

# Check NAT Gateways
echo -e "\nNAT Gateways:"
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "NatGateways[*].[NatGatewayId,State]" \
  --output table

# Check Subnet IP Availability
echo -e "\nSubnet IP Availability:"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "Subnets[*].[SubnetId,CidrBlock,State.AvailableIpAddressCount]" \
  --output table

# Check Route Tables
echo -e "\nRoute Tables:"
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query "RouteTables[*].[RouteTableId,Associations[*].SubnetId,Routes[*].[DestinationCidrBlock,GatewayId]]" \
  --output table

echo -e "\n=== Health Check Complete ==="
```

#### Network Connectivity Test Script

```bash
#!/bin/bash
# network_connectivity_test.sh

VPC_ID="vpc-0abc123def456"
REGION="us-west-2"
BASTION_IP="<bastion-public-ip>"
KEY_PATH="/path/to/key.pem"

echo "=== Network Connectivity Test ==="
echo

# Get public subnet instance
PUBLIC_SUBNET=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=public" \
  --region $REGION \
  --query "Subnets[0].SubnetId" \
  --output text)

# Get private subnet instance
PRIVATE_SUBNET=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=private" \
  --region $REGION \
  --query "Subnets[0].SubnetId" \
  --output text)

echo "Public Subnet: $PUBLIC_SUBNET"
echo "Private Subnet: $PRIVATE_SUBNET"

# Test from bastion (if available)
echo -e "\nTesting from Bastion:"
ssh -i $KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@$BASTION_IP "
  echo '  Public IP: '$(curl -s https://checkip.amazonaws.com)
  echo '  DNS Test: '$(nslookup -query=txt 1.0.0.1 | grep -A1 '1.0.0.1' | tail -1)
  echo '  HTTP Test: '$(curl -s -o /dev/null -w '%{http_code}' https://www.google.com)
" 2>/dev/null || echo "  Cannot connect to bastion"

echo -e "\n=== Test Complete ==="
```

### Quick Reference Commands

```bash
# Get VPC ID by name
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=finishline-prod-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text

# Get all subnets with tags
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags]" \
  --output table

# Count available IPs per subnet
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "Subnets[*].[SubnetId,State.AvailableIpAddressCount]" \
  --output table

# Find unassociated route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-0abc123def456" \
  --query "RouteTables[?length(Associations[?Main==`true`]) == `0` && length(Associations[?Main==`false`]) == `0`].[RouteTableId]" \
  --output text

# Check NACL for specific subnet
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=subnet-0abc123" \
  --query "NetworkAcls[0].NetworkAclId" \
  --output text
```

---

## Module Structure

```
vpc/
├── main.tf         # VPC, subnets, gateways, routes, NACLs
├── variables.tf    # Input variables
├── outputs.tf      # Output values
└── README.md       # This documentation
```

### Related Modules

- [`../sg/`](../sg/README.md) - Security group module
- [`../../compute/jumphost/`](../../compute/jumphost/README.md) - Jumphost instance module
- [`../../eks/`](../../eks/README.md) - EKS cluster module

---

## Version History

| Version | Date       | Changes                                |
| ------- | ---------- | -------------------------------------- |
| 1.0.0   | 2026-03-25 | Initial release with Karpenter support |

---

## Support

For issues, questions, or contributions, please contact the **platform-team** or refer to the [Finishline Infrastructure Documentation](../../../docs/README.md).
