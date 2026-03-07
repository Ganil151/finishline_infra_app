# ALB Module

This Terraform module provides an Application Load Balancer (ALB) for distributing traffic across multiple targets.

## Overview

The ALB module is designed to create:

- AWS Application Load Balancer
- Target Groups for routing traffic
- Listeners for HTTP/HTTPS
- Security group for ALB access

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ HTTPS/HTTP
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                     │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Listener (443 HTTPS / 80 HTTP)                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐      │
│  │ Target Group 1│  │ Target Group 2│  │ Target Group N│      │
│  │ (e.g., /api) │  │ (e.g., /web)  │  │ (e.g., /admin)│      │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘      │
│          │                   │                   │               │
└──────────┼───────────────────┼───────────────────┼──────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
    ┌────────────┐     ┌────────────┐      ┌────────────┐
    │  EC2       │     │  ECS       │      │  Lambda    │
    │  Instances │     │  Tasks     │      │  Functions │
    └────────────┘     └────────────┘      └────────────┘
```

## Current Status

⚠️ **This module is currently empty** and requires implementation.

## Expected Configuration

### Required Variables

```hcl
variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
```

## Relationship to VPC

The ALB module will require the following from the VPC module:

### Connection Flow

```
VPC Module                           ALB Module
┌─────────────────────┐            ┌─────────────────────────┐
│                     │            │                         │
│ Creates:           │            │ Requires:               │
│ - VPC             │            │ - vpc_id               │
│ - Public Subnets  │──────────▶│ - public_subnet_ids    │
│ - Private Subnets │            │ - security_group_ids   │
│                     │            │                         │
└─────────────────────┘            └─────────────────────────┘
```

### How ALB Uses VPC

1. **VPC ID**: Required to create ALB within the VPC
2. **Public Subnets**: ALB must be deployed in at least 2 public subnets in different AZs
3. **Security Groups**: Control access to the ALB

### Example Integration

```hcl
# VPC Module
module "vpc" {
  source = "../vpc"
  # ... configuration
}

# ALB Module
module "alb" {
  source = "../alb"

  # VPC connections
  vpc_id              = module.vpc.main_vpc_id
  public_subnet_ids   = module.vpc.main_public_subnet_ids
  security_group_ids = [module.security_group.finishline_sg_id]

  # ... other configuration
}
```

## Expected Resources

When implemented, this module should create:

### 1. Security Group (`aws_security_group`)

- Allow HTTP (80) and HTTPS (443) from 0.0.0.0/0
- Allow all outbound

### 2. Application Load Balancer (`aws_lb`)

- Type: application
- Scheme: internet-facing
- Enable deletion protection (optional)

### 3. Target Groups (`aws_lb_target_group`)

- Health checks configuration
- Target type: instance, ip, or lambda

### 4. Listener (`aws_lb_listener`)

- HTTP (port 80)
- HTTPS (port 443) with certificate

### 5. Listener Rules (`aws_lb_listener_rule`)

- Path-based routing
- Host-based routing

## Usage Example (When Implemented)

```hcl
module "alb" {
  source = "./modules/alb"

  project_name          = "finishline"
  environment           = "dev"
  manage_by             = "terraform"

  # VPC connections
  vpc_id                = module.vpc.main_vpc_id
  public_subnet_ids     = module.vpc.main_public_subnet_ids
  security_group_ids    = [module.security_group.finishline_sg_id]

  # ALB configuration
  alb_name              = "finishline-alb"
  internal              = false

  # Listener
  http_port             = 80
  https_port            = 443
  ssl_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/abc123"

  # Target groups
  target_groups = [
    {
      name     = "api"
      port     = 80
      path     = "/api/*"
    },
    {
      name     = "web"
      port     = 80
      path     = "/*"
    }
  ]
}
```

## Expected Variables

| Variable              | Description         | Type           | Required |
| --------------------- | ------------------- | -------------- | -------- |
| `project_name`        | Project name        | `string`       | Yes      |
| `environment`         | Environment         | `string`       | Yes      |
| `manage_by`           | Management entity   | `string`       | Yes      |
| `vpc_id`              | VPC ID              | `string`       | Yes      |
| `public_subnet_ids`   | Public subnet IDs   | `list(string)` | Yes      |
| `security_group_ids`  | Security group IDs  | `list(string)` | Yes      |
| `alb_name`            | ALB name            | `string`       | No       |
| `internal`            | Internal ALB        | `bool`         | No       |
| `http_port`           | HTTP listener port  | `number`       | No       |
| `https_port`          | HTTPS listener port | `number`       | No       |
| `ssl_certificate_arn` | SSL certificate ARN | `string`       | No       |

## Expected Outputs

| Output              | Description       |
| ------------------- | ----------------- |
| `alb_id`            | ALB ID            |
| `alb_arn`           | ALB ARN           |
| `alb_dns_name`      | ALB DNS name      |
| `alb_zone_id`       | ALB zone ID       |
| `target_group_arns` | Target group ARNs |

## Integration with Other Modules

### With VPC Module

```hcl
module "vpc" {
  source = "../vpc"
  # ... configuration
}

module "alb" {
  source = "../alb"

  vpc_id              = module.vpc.main_vpc_id
  public_subnet_ids   = module.vpc.main_public_subnet_ids
}
```

### With EKS (Using AWS Load Balancer Controller)

```hcl
module "eks" {
  source = "../eks"
  # ... configuration
}

module "alb" {
  source = "../alb"

  vpc_id            = module.eks.vpc_id
  # ALB for ingress resources
}
```

### With EC2

```hcl
module "ec2" {
  source = "../ec2"
  # ... configuration
}

module "alb" {
  source = "../alb"

  # Route traffic to EC2 instances
  target_instance_ids = [module.ec2.instance_id]
}
```

## Requirements (When Implemented)

- Terraform >= 1.0.0
- AWS Provider >= 5.0

## Dependencies

- VPC Module: Must provide VPC ID and public subnet IDs
- Security Group Module: Must provide security group IDs

## Security Considerations

1. **HTTPS Only**: Use SSL/TLS certificates for production
2. **Restrict Access**: Configure security groups to limit access
3. **Enable Logging**: Enable ALB access logs for auditing
4. **Deletion Protection**: Enable for production workloads

## Next Steps

To implement this module:

1. Add the required variables to `variables.tf`
2. Create ALB resource in `main.tf`
3. Add target groups and listeners
4. Create outputs in `output.tf`
5. Test with VPC and EC2/EKS modules
