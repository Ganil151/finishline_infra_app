# Application Load Balancer (ALB) Module

This Terraform module creates and configures an AWS Application Load Balancer (ALB) for the Finishline infrastructure project. It includes the ALB, target group, listener, and health check configurations with support for access logs, stickiness, and cross-zone load balancing.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Required Variables](#required-variables)
  - [Optional Variables](#optional-variables)
  - [ALB Configuration Reference](#alb-configuration-reference)
  - [Health Check Configuration](#health-check-configuration)
  - [Listener Configuration](#listener-configuration)
  - [Stickiness Configuration](#stickiness-configuration)
- [Outputs](#outputs)
- [Access Logs](#access-logs)
- [Security Best Practices](#security-best-practices)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [AWS CLI Troubleshooting Commands](#aws-cli-troubleshooting-commands)
- [Module Structure](#module-structure)

---

## Overview

The Application Load Balancer module provides a production-ready load balancing solution for HTTP/HTTPS traffic. ALB operates at Layer 7 (application layer) of the OSI model and offers:

- **Content-based routing** - Route requests based on URL path, host headers, or query parameters
- **Health checks** - Automatic detection and routing away from unhealthy targets
- **SSL/TLS termination** - Offload encryption/decryption from backend servers
- **WebSocket support** - Native support for WebSocket and gRPC protocols
- **Access logs** - Detailed logging of all requests for analysis and compliance

This module provisions:

- Application Load Balancer
- Target Group with health checks
- Listener with default action
- Optional access logs to S3

---

## Architecture

```
                                    Internet
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │   Application Load Balancer   │
                        │          (ALB)                │
                        │   DNS: alb-xyz.us-west-2.elb.amazonaws.com  │
                        └───────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
        ┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
        │   Target Group    │ │   Target Group    │ │   Target Group    │
        │   (Web App)       │ │   (API)           │ │   (Admin)         │
        │   Port: 8080      │ │   Port: 8081      │ │   Port: 8082      │
        └─────────┬─────────┘ └─────────┬─────────┘ └─────────┬─────────┘
                  │                     │                     │
        ┌─────────┴─────────┐ ┌─────────┴─────────┐ ┌─────────┴─────────┐
        │  EC2 Instance 1   │ │  EC2 Instance 3   │ │  EC2 Instance 5   │
        │  (AZ-a)           │ │  (AZ-a)           │ │  (AZ-a)           │
        └───────────────────┘ └───────────────────┘ └───────────────────┘
        ┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
        │  EC2 Instance 2   │ │  EC2 Instance 4   │ │  EC2 Instance 6   │
        │  (AZ-b)           │ │  (AZ-b)           │ │  (AZ-b)           │
        └───────────────────┘ └───────────────────┘ └───────────────────┘
```

### Request Flow

```
Client Request
      │
      ▼
┌─────────────────────────┐
│  Route 53 (DNS)         │
│  app.example.com ───────┤
└─────────────────────────┘
      │
      ▼
┌─────────────────────────┐
│  Application Load       │
│  Balancer (ALB)         │
│  - SSL Termination      │
│  - Listener Rules       │
└─────────────────────────┘
      │
      ▼
┌─────────────────────────┐
│  Target Group           │
│  - Health Checks        │
│  - Load Balancing       │
│  - Stickiness           │
└─────────────────────────┘
      │
      ▼
┌─────────────────────────┐
│  EC2 / ECS / EKS        │
│  (Application Server)   │
└─────────────────────────┘
```

---

## Features

| Feature                       | Description                                                 |
| ----------------------------- | ----------------------------------------------------------- |
| **Layer 7 Load Balancing**    | HTTP/HTTPS traffic routing with content-based rules         |
| **Health Checks**             | Automatic target health monitoring and failover             |
| **Cross-Zone Load Balancing** | Distribute traffic across all registered targets in all AZs |
| **HTTP/2 Support**            | Modern protocol support for improved performance            |
| **Access Logs**               | S3 integration for detailed request logging                 |
| **Session Stickiness**        | Route requests from same client to same target              |
| **Deletion Protection**       | Prevent accidental ALB deletion                             |
| **Multiple Target Types**     | Support for EC2 instances, IP addresses, and Lambda         |

---

## Usage

### Basic Example

```hcl
module "alb" {
  source = "./modules/networking/alb"

  # Required variables
  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = module.vpc.public_subnets_ids
  security_group_id = module.alb_sg.security_group_id

  # ALB configuration
  alb_name                         = "finishline-prod"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # Access logs
  enable_access_logs      = true
  access_logs_s3_bucket   = "finishline-prod-alb-logs"
  access_logs_s3_prefix   = "alb-logs"

  # Target group configuration
  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  # Health check configuration
  health_check_enabled      = true
  health_check_path         = "/health"
  health_check_interval     = 30
  health_check_timeout      = 5
  healthy_threshold         = 2
  unhealthy_threshold       = 3
  health_check_matcher      = "200"

  # Stickiness configuration
  stickiness_type            = "lb_cookie"
  stickiness_enabled         = true
  stickiness_cookie_duration = 86400

  # Listener configuration
  listener_port              = 80
  listener_protocol          = "HTTP"
  listener_default_action    = "forward"
}
```

### HTTPS Example with ACM Certificate

```hcl
module "alb_https" {
  source = "./modules/networking/alb"

  project_name      = "finishline"
  environment       = "prod"
  managed_by        = "platform-team"
  aws_region        = "us-west-2"
  vpc_id            = aws_vpc.main.id
  subnet_ids        = module.vpc.public_subnets_ids
  security_group_id = module.alb_sg.security_group_id

  alb_name                         = "finishline-prod"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # HTTPS listener
  listener_port     = 443
  listener_protocol = "HTTPS"

  # Target group
  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  # Health checks
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3
  health_check_matcher  = "200"
}

# SSL Certificate
resource "aws_lb_listener_certificate" "https" {
  listener_arn    = module.alb.listener_arn
  certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/abc-123"
}
```

---

## Configuration

### Required Variables

| Variable                  | Type           | Description                                                       | Example                      |
| ------------------------- | -------------- | ----------------------------------------------------------------- | ---------------------------- |
| `project_name`            | `string`       | Name of the project. Used in resource naming and tagging.         | `"finishline"`               |
| `environment`             | `string`       | Environment name. Determines resource naming and access levels.   | `"dev"`, `"stage"`, `"prod"` |
| `managed_by`              | `string`       | Team or department managing this resource.                        | `"platform-team"`            |
| `aws_region`              | `string`       | AWS region where resources will be created.                       | `"us-west-2"`                |
| `vpc_id`                  | `string`       | ID of the VPC for the ALB and target group.                       | `"vpc-0abc123def456"`        |
| `subnet_ids`              | `list(string)` | List of subnet IDs for the ALB. Must be in different AZs for HA.  | `["subnet-a", "subnet-b"]`   |
| `security_group_id`       | `string`       | Security group ID to associate with the ALB.                      | `"sg-0abc123def456"`         |
| `alb_name`                | `string`       | Name of the Application Load Balancer. Must be unique per region. | `"finishline-prod"`          |
| `alb_internal`            | `bool`         | Whether the ALB is internal (private) or internet-facing.         | `false`                      |
| `alb_type`                | `string`       | Type of load balancer. Use `"application"` for ALB.               | `"application"`              |
| `target_group_port`       | `number`       | Port on which targets receive traffic.                            | `8080`                       |
| `target_group_protocol`   | `string`       | Protocol for target group. HTTP, HTTPS, TCP, TLS, UDP, TCP_UDP.   | `"HTTP"`                     |
| `target_type`             | `string`       | Type of target. `instance`, `ip`, or `lambda`.                    | `"instance"`                 |
| `listener_port`           | `number`       | Port on which the listener accepts traffic.                       | `80` or `443`                |
| `listener_protocol`       | `string`       | Protocol for the listener. HTTP or HTTPS.                         | `"HTTP"`                     |
| `listener_default_action` | `string`       | Default action for unmatched requests. Usually `"forward"`.       | `"forward"`                  |

### Optional Variables

| Variable                           | Type     | Default       | Description                              |
| ---------------------------------- | -------- | ------------- | ---------------------------------------- |
| `enable_deletion_protection`       | `bool`   | `false`       | Prevent accidental ALB deletion          |
| `enable_http2`                     | `bool`   | `true`        | Enable HTTP/2 support                    |
| `enable_cross_zone_load_balancing` | `bool`   | `true`        | Distribute traffic across all AZs        |
| `enable_access_logs`               | `bool`   | `false`       | Enable request logging to S3             |
| `access_logs_s3_bucket`            | `string` | `""`          | S3 bucket name for access logs           |
| `access_logs_s3_prefix`            | `string` | `""`          | Prefix for log files in S3 bucket        |
| `health_check_enabled`             | `bool`   | `true`        | Enable health checks                     |
| `health_check_path`                | `string` | `"/"`         | URL path for health checks               |
| `health_check_interval`            | `number` | `30`          | Seconds between health checks            |
| `health_check_timeout`             | `number` | `5`           | Health check timeout in seconds          |
| `healthy_threshold`                | `number` | `2`           | Consecutive healthy responses required   |
| `unhealthy_threshold`              | `number` | `3`           | Consecutive unhealthy responses required |
| `health_check_matcher`             | `string` | `"200"`       | HTTP codes considered healthy            |
| `stickiness_enabled`               | `bool`   | `false`       | Enable session stickiness                |
| `stickiness_type`                  | `string` | `"lb_cookie"` | Type of stickiness                       |
| `stickiness_cookie_duration`       | `number` | `86400`       | Cookie duration in seconds               |

### ALB Configuration Reference

#### ALB Type (Internal vs Internet-Facing)

```hcl
# Internet-facing ALB (public)
alb_internal = false
# Accessible from the internet
# Requires public subnets
# Use for public-facing applications

# Internal ALB (private)
alb_internal = true
# Accessible only within VPC
# Use for internal services, microservices
```

#### ALB Type Options

| Type          | Description                          | Use Case                      |
| ------------- | ------------------------------------ | ----------------------------- |
| `application` | Layer 7 load balancer for HTTP/HTTPS | Web applications, APIs        |
| `network`     | Layer 4 load balancer for TCP/TLS    | High-performance, low-latency |

#### Deletion Protection

```hcl
# Production - Enable deletion protection
enable_deletion_protection = true

# Development - Can disable for easier management
enable_deletion_protection = false
```

### Health Check Configuration

#### Health Check Parameters

```hcl
# Web application health check
health_check_enabled      = true
health_check_path         = "/health"
health_check_interval     = 30
health_check_timeout      = 5
healthy_threshold         = 2
unhealthy_threshold       = 3
health_check_matcher      = "200"

# API with multiple healthy codes
health_check_matcher = "200-299"

# Multiple healthy codes
health_check_matcher = "200,301,302"
```

#### Health Check Best Practices

| Parameter               | Recommended Value       | Description                                 |
| ----------------------- | ----------------------- | ------------------------------------------- |
| `health_check_path`     | `/health` or `/healthz` | Dedicated health endpoint                   |
| `health_check_interval` | `30` seconds            | Balance between responsiveness and overhead |
| `health_check_timeout`  | `5` seconds             | Less than interval                          |
| `healthy_threshold`     | `2`                     | Quick recovery                              |
| `unhealthy_threshold`   | `3`                     | Avoid false positives                       |
| `health_check_matcher`  | `200` or `200-299`      | Expected response codes                     |

#### Health Check Path Examples

```hcl
# Simple health endpoint
health_check_path = "/health"

# Kubernetes-style liveness probe
health_check_path = "/healthz"

# Readiness probe
health_check_path = "/ready"

# Application-specific health
health_check_path = "/api/health"

# Deep health check (database connectivity)
health_check_path = "/health/deep"
```

### Listener Configuration

#### Listener Ports and Protocols

```hcl
# HTTP listener
listener_port     = 80
listener_protocol = "HTTP"

# HTTPS listener
listener_port     = 443
listener_protocol = "HTTPS"

# HTTP to HTTPS redirect (requires listener rule)
listener_port     = 80
listener_protocol = "HTTP"
```

#### Listener Default Actions

| Action           | Description               |
| ---------------- | ------------------------- |
| `forward`        | Forward to target group   |
| `redirect`       | Redirect to different URL |
| `fixed-response` | Return fixed response     |

### Stickiness Configuration

#### Stickiness Types

```hcl
# Load balancer cookie-based stickiness
stickiness_type            = "lb_cookie"
stickiness_enabled         = true
stickiness_cookie_duration = 86400  # 24 hours

# Application-based cookie stickiness
stickiness_type            = "app_cookie"
stickiness_enabled         = true
stickiness_cookie_duration = 86400

# No stickiness
stickiness_enabled = false
```

#### Stickiness Duration Guidelines

| Duration           | Use Case              |
| ------------------ | --------------------- |
| `3600` (1 hour)    | Short sessions        |
| `86400` (24 hours) | Standard web sessions |
| `604800` (7 days)  | Long-term sessions    |

---

## Outputs

| Output                    | Type     | Description                                  |
| ------------------------- | -------- | -------------------------------------------- |
| `alb_arn`                 | `string` | The ARN of the Application Load Balancer     |
| `alb_arn_suffix`          | `string` | The ARN suffix of the ALB (for IAM policies) |
| `alb_dns_name`            | `string` | The DNS name of the ALB                      |
| `alb_zone_id`             | `string` | The zone ID for Route53 alias records        |
| `alb_id`                  | `string` | The ID of the ALB                            |
| `target_group_arn`        | `string` | The ARN of the Target Group                  |
| `target_group_arn_suffix` | `string` | The ARN suffix of the target group           |
| `target_group_id`         | `string` | The ID of the target group                   |
| `target_group_name`       | `string` | The name of the target group                 |
| `listener_arn`            | `string` | The ARN of the Listener                      |
| `listener_id`             | `string` | The ID of the listener                       |

### Using Outputs

```hcl
# Reference ALB DNS name for Route53
resource "aws_route53_record" "app" {
  zone_id = "Z1234567890"
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Reference target group for auto scaling
resource "aws_autoscaling_group" "app" {
  target_group_arns = [module.alb.target_group_arn]
}

# Reference listener for rules
resource "aws_lb_listener_rule" "api" {
  listener_arn = module.alb.listener_arn
  # ... rule configuration
}
```

---

## Access Logs

### S3 Bucket Configuration

```hcl
# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "finishline-prod-alb-logs"
}

# Bucket policy for ALB access logs
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ALBAccessLogs"
        Effect    = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "123456789012"
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/*"
          }
        }
      }
    ]
  })
}
```

### Module Configuration

```hcl
module "alb" {
  source = "./modules/networking/alb"

  # ... other configuration

  enable_access_logs    = true
  access_logs_s3_bucket = "finishline-prod-alb-logs"
  access_logs_s3_prefix = "alb-logs"
}
```

### Access Log Format

ALB access logs include:

- Timestamp
- Client IP and port
- Target IP and port
- Request processing time
- ALB processing time
- Response codes
- Request method and URL
- User agent

---

## Security Best Practices

### 1. Use HTTPS for Production

```hcl
# ✅ Good: HTTPS listener with ACM certificate
listener_port     = 443
listener_protocol = "HTTPS"

# Configure SSL policy
# (Requires additional listener configuration)
```

### 2. Enable Deletion Protection

```hcl
# ✅ Good: Prevent accidental deletion
enable_deletion_protection = true
```

### 3. Restrict Security Group

```hcl
# ALB Security Group - Allow only required ports
ingress_rules = [
  {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "HTTP from internet (for redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

# Egress - Only to target instances
egress_rules = [
  {
    description = "To application servers"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
]
```

### 4. Enable Access Logs

```hcl
# ✅ Good: Enable for audit and troubleshooting
enable_access_logs      = true
access_logs_s3_bucket   = "finishline-prod-alb-logs"
access_logs_s3_prefix   = "alb-logs"
```

### 5. Use Health Check Endpoints

```hcl
# ✅ Good: Dedicated health endpoint
health_check_path = "/health"

# ❌ Bad: Check root endpoint
health_check_path = "/"
```

### 6. Cross-Zone Load Balancing

```hcl
# ✅ Good: Enable for even distribution
enable_cross_zone_load_balancing = true
```

---

## Examples

### Development ALB

```hcl
module "alb_dev" {
  source = "./modules/networking/alb"

  project_name    = "finishline"
  environment     = "dev"
  managed_by      = "dev-team"
  aws_region      = "us-west-2"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = module.vpc.public_subnets_ids
  security_group_id = module.alb_sg.security_group_id

  alb_name                         = "finishline-dev"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # No access logs for dev
  enable_access_logs = false

  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3
  health_check_matcher  = "200"

  listener_port           = 80
  listener_protocol       = "HTTP"
  listener_default_action = "forward"
}
```

### Production HTTPS ALB

```hcl
module "alb_prod" {
  source = "./modules/networking/alb"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = module.vpc.public_subnets_ids
  security_group_id = module.alb_sg_prod.security_group_id

  alb_name                         = "finishline-prod"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  enable_access_logs      = true
  access_logs_s3_bucket   = "finishline-prod-logs"
  access_logs_s3_prefix   = "alb"

  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  health_check_path     = "/healthz"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3
  health_check_matcher  = "200"

  listener_port           = 443
  listener_protocol       = "HTTPS"
  listener_default_action = "forward"
}

# SSL Certificate
resource "aws_acm_certificate" "prod" {
  domain_name       = "app.finishline.com"
  validation_method = "DNS"
}

resource "aws_lb_listener_certificate" "prod" {
  listener_arn    = module.alb_prod.listener_arn
  certificate_arn = aws_acm_certificate.prod.arn
}
```

### Internal ALB for Microservices

```hcl
module "alb_internal" {
  source = "./modules/networking/alb"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = module.vpc.private_subnets_ids
  security_group_id = module.alb_sg_internal.security_group_id

  alb_name                         = "finishline-internal"
  alb_internal                     = true
  alb_type                         = "application"
  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  enable_access_logs      = true
  access_logs_s3_bucket   = "finishline-prod-logs"
  access_logs_s3_prefix   = "alb-internal"

  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3
  health_check_matcher  = "200"

  listener_port           = 80
  listener_protocol       = "HTTP"
  listener_default_action = "forward"

  stickiness_enabled         = true
  stickiness_type            = "lb_cookie"
  stickiness_cookie_duration = 3600
}
```

### ALB with Multiple Target Groups (Listener Rules)

```hcl
module "alb" {
  source = "./modules/networking/alb"

  project_name    = "finishline"
  environment     = "prod"
  managed_by      = "platform-team"
  aws_region      = "us-west-2"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = module.vpc.public_subnets_ids
  security_group_id = module.alb_sg.security_group_id

  alb_name                         = "finishline-prod"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = true

  target_group_port     = 8080
  target_group_protocol = "HTTP"
  target_type           = "instance"

  health_check_path     = "/health"
  health_check_interval = 30

  listener_port           = 443
  listener_protocol       = "HTTPS"
  listener_default_action = "forward"
}

# Additional target group for API
resource "aws_lb_target_group" "api" {
  name     = "finishline-prod-api-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/api/health"
  }
}

# Listener rule for API paths
resource "aws_lb_listener_rule" "api" {
  listener_arn = module.alb.listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Listener rule for static content
resource "aws_lb_listener_rule" "static" {
  listener_arn = module.alb.listener_arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = module.alb.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/static/*", "/assets/*"]
    }
  }
}
```

---

## Troubleshooting

### Issue: 502 Bad Gateway

**Symptoms**: ALB returns 502 errors to clients.

**Possible Causes**:

1. Target instances are unhealthy
2. Security group blocking ALB to target traffic
3. Target application not responding
4. Health check misconfiguration

**Resolution**:

```hcl
# Check health check configuration
health_check_path     = "/health"
health_check_interval = 30
health_check_timeout  = 5
health_check_matcher  = "200"

# Verify security group allows ALB to target communication
# Check target application is running and responding
```

### Issue: 503 Service Unavailable

**Symptoms**: ALB returns 503 errors.

**Possible Causes**:

1. No registered targets
2. All targets unhealthy
3. Target group misconfiguration

**Resolution**:

```hcl
# Verify targets are registered
# Check target group port matches application port
target_group_port = 8080

# Verify health check path is correct
health_check_path = "/health"
```

### Issue: 504 Gateway Timeout

**Symptoms**: ALB returns 504 errors.

**Possible Causes**:

1. Target application response time exceeds timeout
2. Network latency between ALB and targets
3. Target application hanging

**Resolution**:

```hcl
# Increase idle timeout (requires additional configuration)
# Optimize target application response time
# Check network connectivity between ALB and targets
```

### Issue: Health Checks Failing

**Symptoms**: Targets marked as unhealthy.

**Possible Causes**:

1. Health check path doesn't exist
2. Application returns non-200 status
3. Health check timeout too short
4. Security group blocking health checks

**Resolution**:

```hcl
# Verify health endpoint exists and returns 200
health_check_path = "/health"
health_check_matcher = "200"

# Adjust timeout if needed
health_check_timeout = 10

# Check security group allows health check traffic
```

### Issue: SSL/TLS Handshake Failures

**Symptoms**: HTTPS connections fail.

**Possible Causes**:

1. Certificate expired
2. Certificate domain mismatch
3. SSL policy too restrictive

**Resolution**:

```hcl
# Verify certificate is valid and matches domain
# Check certificate is associated with listener
# Use appropriate SSL policy
```

---

## AWS CLI Troubleshooting Commands

### ALB Inspection

#### List All Load Balancers

```bash
# List all ALBs in region
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].[LoadBalancerArn,LoadBalancerName,DNSName,State,Type]" \
  --output table

# List ALBs with specific tag
aws elbv2 describe-load-balancers \
  --filters "Name=tag:Project,Values=finishline" \
  --query "LoadBalancers[*].[LoadBalancerArn,LoadBalancerName,DNSName]" \
  --output table

# Describe specific ALB
aws elbv2 describe-load-balancers \
  --names finishline-prod \
  --query "LoadBalancers[0]" \
  --output json
```

#### Check ALB Attributes

```bash
# Check ALB attributes (deletion protection, cross-zone, etc.)
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "Attributes[*].[Key,Value]" \
  --output table

# Check if deletion protection is enabled
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "Attributes[?Key=='deletion_protection.enabled'].Value" \
  --output text
```

### Target Group Diagnostics

#### List Target Groups

```bash
# List all target groups
aws elbv2 describe-target-groups \
  --query "TargetGroups[*].[TargetGroupArn,TargetGroupName,Protocol,Port,VpcId]" \
  --output table

# List target groups for specific ALB
aws elbv2 describe-target-groups \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "TargetGroups[*].[TargetGroupArn,TargetGroupName,Protocol,Port]" \
  --output table

# Describe specific target group
aws elbv2 describe-target-groups \
  --names finishline-prod-tg \
  --query "TargetGroups[0]" \
  --output json
```

#### Check Target Health

```bash
# Check health of all targets in target group
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/finishline-prod-tg/abc123 \
  --query "TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]" \
  --output table

# Check specific target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/finishline-prod-tg/abc123 \
  --targets Id=i-0abc123def456,Port=8080 \
  --query "TargetHealthDescriptions[0]" \
  --output json

# Check targets in unhealthy state
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/finishline-prod-tg/abc123 \
  --query "TargetHealthDescriptions[?TargetHealth.State=='unhealthy'].[Target.Id,TargetHealth.Reason,TargetHealth.Description]" \
  --output table
```

#### Target Group Health Check Configuration

```bash
# Check health check configuration
aws elbv2 describe-target-groups \
  --names finishline-prod-tg \
  --query "TargetGroups[0].{HealthCheckProtocol:HealthCheckProtocol,HealthCheckPort:HealthCheckPort,HealthCheckPath:HealthCheckPath,HealthCheckInterval:HealthCheckInterval,HealthCheckTimeout:HealthCheckTimeout,HealthyThreshold:HealthyThreshold,UnhealthyThreshold:UnhealthyThreshold,Matcher:Matcher}" \
  --output json
```

### Listener Diagnostics

#### List Listeners

```bash
# List all listeners for ALB
aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "Listeners[*].[ListenerArn,Port,Protocol,DefaultActions[0].Type,SslPolicy]" \
  --output table

# Describe specific listener
aws elbv2 describe-listeners \
  --listener-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/finishline-prod/abc123/def456 \
  --query "Listeners[0]" \
  --output json
```

#### Listener Rules

```bash
# List listener rules
aws elbv2 describe-rules \
  --listener-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/finishline-prod/abc123/def456 \
  --query "Rules[*].[RuleArn,Priority,Conditions,Actions[0].Type,Actions[0].TargetGroupArn]" \
  --output table

# Check rule for specific path
aws elbv2 describe-rules \
  --listener-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/finishline-prod/abc123/def456 \
  --query "Rules[?Conditions[0].PathPatternConfig.Values[0]=='/api/*']" \
  --output json
```

### SSL/TLS Diagnostics

#### Check Certificates

```bash
# List certificates attached to listener
aws elbv2 describe-listener-certificates \
  --listener-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/finishline-prod/abc123/def456 \
  --query "Certificates[*].[CertificateArn,IsDefault]" \
  --output table

# Check ACM certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-west-2:123456789012:certificate/abc-123 \
  --query "Certificate.{DomainName:DomainName,Status:Status,NotAfter:NotAfter,InUseBy:InUseBy}" \
  --output json
```

### Access Logs Diagnostics

#### Check Access Log Configuration

```bash
# Check access log settings
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "Attributes[?starts_with(Key, 'access_logs')].[Key,Value]" \
  --output table
```

#### Query Access Logs from S3

```bash
# List access log files (last 24 hours)
aws s3 ls s3://finishline-prod-logs/alb-logs/ \
  --recursive \
  --human-readable \
  --sort-by date \
  | tail -20

# Download and analyze recent logs
aws s3 cp s3://finishline-prod-logs/alb-logs/AWSLogs/123456789012/elasticloadbalancing/us-west-2/2026/03/25/ \
  ./alb-logs/ \
  --recursive \
  --exclude "*" \
  --include "*.gz" \
  --quiet

# Decompress and search for errors
gunzip -c ./alb-logs/*.gz | grep -i "502\|503\|504" | head -20
```

### CloudWatch Metrics

#### ALB Metrics

```bash
# Get ALB request count metric
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/finishline-prod/abc123 \
  --start-time $(date -d "1 hour ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum \
  --query "Datapoints[*].[Timestamp,Sum]" \
  --output table

# Get target response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/finishline-prod/abc123 \
  --start-time $(date -d "1 hour ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average \
  --query "Datapoints[*].[Timestamp,Average]" \
  --output table

# Get HTTP 5XX errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/finishline-prod/abc123 \
  --start-time $(date -d "1 hour ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum \
  --query "Datapoints[*].[Timestamp,Sum]" \
  --output table

# Get unhealthy host count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name UnHealthyHostCount \
  --dimensions Name=LoadBalancer,Value=app/finishline-prod/abc123,Name=TargetGroup,Value=targetgroup/finishline-prod-tg/abc123 \
  --start-time $(date -d "1 hour ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average \
  --query "Datapoints[*].[Timestamp,Average]" \
  --output table
```

### Connectivity Testing

#### Test ALB Endpoint

```bash
# Test HTTP endpoint
curl -v http://finishline-prod-123456789.us-west-2.elb.amazonaws.com/

# Test HTTPS endpoint
curl -v https://finishline-prod-123456789.us-west-2.elb.amazonaws.com/

# Test health check endpoint
curl -v http://finishline-prod-123456789.us-west-2.elb.amazonaws.com/health

# Test with specific host header
curl -v -H "Host: app.finishline.com" http://finishline-prod-123456789.us-west-2.elb.amazonaws.com/

# Test response time
curl -w "@curl-format.txt" -o /dev/null -s https://finishline-prod-123456789.us-west-2.elb.amazonaws.com/
```

#### Test from Target Instance

```bash
# SSH to target and test connectivity to ALB
ssh -i key.pem ec2-user@<target-ip> "
  echo 'Testing ALB connectivity...'
  curl -I http://<alb-dns-name>/health
  echo 'Testing localhost application...'
  curl -I http://localhost:8080/health
"
```

### Automation Scripts

#### ALB Health Check Script

```bash
#!/bin/bash
# alb_health_check.sh

ALB_NAME="finishline-prod"
REGION="us-west-2"

echo "=== ALB Health Check: $ALB_NAME ==="
echo

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names $ALB_NAME \
  --region $REGION \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)

echo "ALB ARN: $ALBARN"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names $ALB_NAME \
  --region $REGION \
  --query "LoadBalancers[0].DNSName" \
  --output text)

echo "ALB DNS: $ALB_DNS"

# Get target groups
echo -e "\nTarget Groups:"
aws elbv2 describe-target-groups \
  --load-balancer-arn $ALB_ARN \
  --region $REGION \
  --query "TargetGroups[*].[TargetGroupName,Protocol,Port,HealthCheckPath]" \
  --output table

# Check target health for each target group
echo -e "\nTarget Health:"
for TG_ARN in $(aws elbv2 describe-target-groups \
  --load-balancer-arn $ALB_ARN \
  --region $REGION \
  --query "TargetGroups[*].TargetGroupArn" \
  --output text); do

  TG_NAME=$(aws elbv2 describe-target-groups \
    --target-group-arns $TG_ARN \
    --region $REGION \
    --query "TargetGroups[0].TargetGroupName" \
    --output text)

  echo -e "\nTarget Group: $TG_NAME"
  aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region $REGION \
    --query "TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]" \
    --output table
done

# Check CloudWatch metrics (5XX errors in last hour)
echo -e "\n5XX Errors (last hour):"
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value=$ALB_ARN \
  --start-time $(date -d "1 hour ago" -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum \
  --query "Datapoints[*].[Timestamp,Sum]" \
  --output table

echo -e "\n=== Health Check Complete ==="
```

#### ALB Access Log Analyzer

```bash
#!/bin/bash
# alb_log_analyzer.sh

S3_BUCKET="finishline-prod-logs"
S3_PREFIX="alb-logs"
REGION="us-west-2"

echo "=== ALB Access Log Analyzer ==="
echo

# Get latest log file
LATEST_LOG=$(aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/AWSLogs/ \
  --recursive \
  --region $REGION \
  --sort-by date \
  | tail -1 \
  | awk '{print $4}')

echo "Latest log: $LATEST_LOG"

# Download and analyze
TEMP_FILE="/tmp/alb-log-$(date +%s).gz"
aws s3 cp s3://$S3_BUCKET/$LATEST_LOG $TEMP_FILE --region $REGION

echo -e "\nAnalyzing logs..."
echo

# Count status codes
echo "HTTP Status Codes:"
gunzip -c $TEMP_FILE | awk '{print $9}' | sort | uniq -c | sort -rn | head -10

# Top URLs
echo -e "\nTop 10 URLs:"
gunzip -c $TEMP_FILE | awk '{print $7}' | sort | uniq -c | sort -rn | head -10

# Top client IPs
echo -e "\nTop 10 Client IPs:"
gunzip -c $TEMP_FILE | awk '{print $3}' | sort | uniq -c | sort -rn | head -10

# 5XX errors
echo -e "\n5XX Errors:"
gunzip -c $TEMP_FILE | awk '$9 ~ /^5/ {print $0}' | head -10

# Cleanup
rm -f $TEMP_FILE

echo -e "\n=== Analysis Complete ==="
```

### Quick Reference Commands

```bash
# Get ALB ARN by name
aws elbv2 describe-load-balancers \
  --names finishline-prod \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text

# Get target group ARN by name
aws elbv2 describe-target-groups \
  --names finishline-prod-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text

# Get listener ARN by ALB ARN
aws elbv2 describe-listeners \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/finishline-prod/abc123 \
  --query "Listeners[0].ListenerArn" \
  --output text

# Count registered targets
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/finishline-prod-tg/abc123 \
  --query "length(TargetHealthDescriptions)" \
  --output text

# Check ALB scheme (internal vs internet-facing)
aws elbv2 describe-load-balancers \
  --names finishline-prod \
  --query "LoadBalancers[0].Scheme" \
  --output text

# List all ALB-related resources
echo "Load Balancers:"
aws elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerName" --output table
echo -e "\nTarget Groups:"
aws elbv2 describe-target-groups --query "TargetGroups[*].TargetGroupName" --output table
echo -e "\nListeners:"
aws elbv2 describe-listeners --query "Listeners[*].ListenerArn" --output table
```

---

## Module Structure

```
alb/
├── main.tf         # ALB, target group, listener resources
├── variables.tf    # Input variables
├── outputs.tf      # Output values
└── README.md       # This documentation
```

### Related Modules

- [`../sg/`](../sg/README.md) - Security group module for ALB
- [`../vpc/`](../vpc/README.md) - VPC module for network infrastructure
- [`../../compute/`](../../compute/README.md) - Compute modules for targets

---

## Version History

| Version | Date       | Changes                                                      |
| ------- | ---------- | ------------------------------------------------------------ |
| 1.0.0   | 2026-03-25 | Initial release with ALB, target group, and listener support |

---

## Support

For issues, questions, or contributions, please contact the **platform-team** or refer to the [Finishline Infrastructure Documentation](../../../docs/README.md).
