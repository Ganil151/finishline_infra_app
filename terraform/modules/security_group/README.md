# Security Group Module

This Terraform module creates an AWS Security Group with configurable ingress and egress rules for network traffic control.

## Overview

The Security Group module provides network security by controlling inbound and outbound traffic to AWS resources. It creates a stateful firewall that filters traffic based on:

- Protocol (TCP, UDP, ICMP, etc.)
- Port range
- Source/Destination IP addresses (CIDR blocks)

## Relationship to VPC

The security group is **tightly coupled to the VPC** and cannot exist without a VPC:

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC                                     │
│                    10.0.0.0/16                                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Security Group                                │  │
│  │  - Attached to VPC via vpc_id                            │  │
│  │  - Controls traffic for resources in this VPC            │  │
│  │  - Rules are evaluated in context of the VPC CIDR         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐                 │
│  │   EC2 Instance   │    │   EKS Cluster    │                 │
│  │   (Jump Host)    │    │   (Nodes)        │                 │
│  │                  │    │                  │                 │
│  │  sg-xxxxx        │    │  sg-xxxxx        │                 │
│  └────────┬─────────┘    └────────┬─────────┘                 │
│           │                        │                            │
│           └────────┬───────────────┘                            │
│                    │                                             │
│           Security Group Controls                                │
│           All Network Traffic                                    │
└─────────────────────────────────────────────────────────────────┘
```

### How Security Group Connects to VPC

1. **VPC ID Reference**: The security group is created within a specific VPC using the `vpc_id` variable
2. **Regional Scope**: Security groups are regional - they apply to resources within the same AWS region
3. **VPC-scoped Rules**: All CIDR block rules are interpreted within the VPC's IP address space
4. **Implicit Deny**: All traffic is blocked by default unless explicitly allowed

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │       Security Group (Stateful)     │
                    │                                     │
                    │  ┌─────────────────────────────┐    │
                    │  │     Ingress Rules           │    │
                    │  │  - Allow SSH (22) from 0.0.0.0/0   │    │
                    │  │  - Allow HTTP (80) from ALB        │    │
                    │  │  - Allow HTTPS (443) from ALB      │    │
                    │  └─────────────────────────────┘    │
                    │                                     │
                    │  ┌─────────────────────────────┐    │
                    │  │     Egress Rules            │    │
                    │  │  - Allow All (0.0.0.0/0)    │    │
                    │  └─────────────────────────────┘    │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
      ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
      │  EC2 Jump    │    │     EKS      │    │     ALB      │
      │    Host      │    │    Nodes     │    │   (Future)   │
      └──────────────┘    └──────────────┘    └──────────────┘
```

## Usage

### Basic Example

```hcl
module "security_group" {
  source = "./modules/security_group"

  project_name        = "finishline"
  environment         = "dev"
  manage_by           = "terraform"
  vpc_id              = module.vpc.main_vpc_id

  ingress_rules = [
    {
      description = "SSH from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

> **Note**: The security group name is automatically generated as `finishline_sg_{project_name}`.

### Complete Example with Multiple Rules

```hcl
module "security_group" {
  source = "./modules/security_group"

  project_name        = "finishline"
  environment         = "prod"
  manage_by           = "terraform"
  vpc_id              = module.vpc.main_vpc_id

  ingress_rules = [
    {
      description = "SSH from admin network"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/24"]  # Bastion subnet
    },
    {
      description = "HTTP from ALB"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"]  # Public subnet
    },
    {
      description = "HTTPS from ALB"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"]  # Public subnet
    },
    {
      description = "MySQL from private subnets"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.10.0/24", "10.0.20.0/24"]  # Private subnets
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
```

### Using with VPC Module

```hcl
# First, create the VPC
module "vpc" {
  source = "../vpc"

  project_name          = "finishline"
  environment           = "dev"
  manage_by             = "terraform"

  vpc_cidr              = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true

  availability_zones    = ["us-east-1a", "us-east-1b"]
  public_subnets_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
}

# Then, create the security group within the VPC
module "security_group" {
  source = "../security_group"

  project_name        = "finishline"
  environment         = "dev"
  manage_by           = "terraform"
  vpc_id              = module.vpc.main_vpc_id  # VPC ID from VPC module

  ingress_rules = [
    {
      description = "SSH from public subnet"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"]  # Public subnet CIDR
    }
  ]

  egress_rules = []
}
```

## Variables

| Variable              | Description                                             | Type           | Required |
| --------------------- | ------------------------------------------------------- | -------------- | -------- |
| `project_name`        | The name of the project                                 | `string`       | Yes      |
| `environment`         | The environment (dev, staging, prod)                    | `string`       | Yes      |
| `manage_by`           | The entity responsible for managing the security group  | `string`       | Yes      |
| `vpc_id`              | The ID of the VPC to attach the security group to       | `string`       | Yes      |
| `security_group_name` | The name of the security group                          | `string`       | Yes      |
| `ingress_rules`       | List of ingress rules                                   | `list(object)` | Yes      |
| `egress_rules`        | List of egress rules (optional - defaults to allow all) | `list(object)` | No       |

### Ingress/Egress Rule Object Structure

```hcl
object({
  description = string   # Description of the rule
  from_port   = number   # Start port (0 for all)
  to_port     = number   # End port (0 for all)
  protocol    = string   # tcp, udp, icmp, -1 (all)
  cidr_blocks = list(string)  # List of CIDR blocks
})
```

## Outputs

| Output               | Description                    |
| -------------------- | ------------------------------ |
| `finishline_sg_id`   | The ID of the security group   |
| `finishline_sg_name` | The name of the security group |
| `finishline_sg_arn`  | The ARN of the security group  |

## Resources Created

### Security Group (`aws_security_group`)

- Creates a VPC security group with specified name and description
- Attached to the VPC specified by `vpc_id`
- Contains dynamic ingress rules based on `ingress_rules` variable
- Contains egress rules (default: allow all)
- Tagged with project, environment, and management information

### Ingress Rules

- Dynamically created based on the `ingress_rules` list
- Each rule specifies:
  - Description
  - Protocol (tcp, udp, icmp, -1)
  - Port range (from_port to to_port)
  - Source CIDR blocks

### Egress Rules

- By default, allows all outbound traffic (0.0.0.0/0)
- Can be customized via `egress_rules` variable
- Stateful: return traffic is automatically allowed

## Tagging Convention

All resources are tagged consistently:

- `Name`: `finishline_sg_{project_name}`
- `Project`: The project name
- `Environment`: The environment
- `ManagedBy`: The value of `manage_by` variable
- `Terraform`: Set to "true" for Terraform-managed resources

## Relationship to VPC Module

The security group module requires a VPC to exist before it can be created:

### Dependency Flow

```
VPC Module                    Security Group Module
┌──────────────┐             ┌────────────────────┐
│              │             │                    │
│ Creates:     │             │ Requires:          │
│ - VPC        │────────────▶│ - vpc_id           │
│ - Subnets    │  (output)   │ (from VPC module)  │
│              │             │                    │
└──────────────┘             └────────────────────┘
```

### Integration Example

```hcl
# main.tf in environment directory

# 1. Create VPC first
module "vpc" {
  source = "../../modules/vpc"
  # ... VPC configuration
}

# 2. Create security group using VPC ID
module "security_group" {
  source = "../../modules/security_group"

  vpc_id = module.vpc.main_vpc_id  # Reference VPC output
  # ... other configuration
}

# 3. Use security group with EC2/EKS
module "ec2" {
  source = "../../modules/ec2"

  vpc_security_group_ids = [module.security_group.finishline_sg_id]
  # ... other configuration
}
```

### VPC Considerations

1. **Same VPC Required**: Security groups are VPC-specific and cannot be shared across VPCs
2. **Regional**: Security groups are regional in AWS - create separate SGs for each region
3. **VPC CIDR Context**: When specifying CIDR blocks in rules, they are interpreted relative to the VPC CIDR
4. **Private Subnet Access**: Use private subnet CIDRs in rules to allow traffic from internal resources

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0

## Dependencies

- **Required**: A VPC must exist (typically created by the VPC module)
- **Optional**: Can be used with EC2, EKS, ALB modules

## Considerations

### Security Best Practices

1. **Least Privilege**: Only allow necessary traffic
2. **Avoid 0.0.0.0/0 for Ingress**: Restrict access to specific IP ranges when possible
3. **Use Descriptive Names**: Make rules easily identifiable
4. **Stateful**: Remember that security groups are stateful - return traffic is automatically allowed

### Common Use Cases

1. **Jump Host (Bastion)**: Allow SSH (port 22) from admin IP
2. **Application Servers**: Allow HTTP/HTTPS from ALB subnet
3. **Database**: Allow database port (e.g., 3306) from private subnet
4. **EKS Nodes**: Allow all traffic from nodes within the same security group

### Limitations

- Maximum 60 inbound rules and 60 outbound rules per security group
- Cannot create "deny" rules - use Network ACLs for that
- Cannot filter based on content (use WAF for that)

## Troubleshooting

### Cannot Connect to Resource

- Check that security group allows traffic on the correct port
- Verify protocol (TCP/UDP) matches
- Ensure CIDR blocks include source/destination IP
- Remember: Security groups are stateful - return traffic is allowed automatically

### Security Group Not Found

- Verify `vpc_id` is correct and exists
- Check that the security group was created in the same region

### Rules Not Applied

- Terraform apply may need to be run again after rule changes
- Check for rule limit (60 inbound, 60 outbound)

## Integration with Other Modules

### EC2 Module

```hcl
module "ec2" {
  source = "../ec2"

  vpc_security_group_ids = [module.security_group.finishline_sg_id]
  # ...
}
```

### EKS Module

```hcl
module "eks" {
  source = "../eks"

  security_group_ids = [module.security_group.finishline_sg_id]
  # ...
}
```

### ALB Module (Future)

```hcl
module "alb" {
  source = "../alb"

  security_groups = [module.security_group.finishline_sg_id]
  # ...
}
```
