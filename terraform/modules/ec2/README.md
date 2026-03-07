# EC2 Module

This Terraform module creates an EC2 jump host (bastion) for secure access to private resources within a VPC.

## Overview

The EC2 module provisions:

- EC2 instance in a public subnet (jump host/bastion)
- Security group for the instance
- SSH key pair for access
- Elastic IP for persistent public IP

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC                                     │
│                    10.0.0.0/16                                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                  Public Subnet (AZ1, AZ2)                  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │           Jump Host (Bastion)                        │  │  │
│  │  │  ┌─────────────────────────────────────────────┐   │  │  │
│  │  │  │ EC2 Instance (t3.micro)                    │   │  │  │
│  │  │  │ - Public Subnet                             │   │  │  │
│  │  │  │ - Security Group                            │   │  │  │
│  │  │  │ - Key Pair                                 │   │  │  │
│  │  │  │ - Elastic IP                               │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ SSH Access                        │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                  Private Subnets                          │  │
│  │  ┌──────────────┐    ┌──────────────┐                   │  │
│  │  │ EKS Nodes    │    │ RDS Database │                   │  │
│  │  │ App Servers  │    │ Private Svc  │                   │  │
│  │  └──────────────┘    └──────────────┘                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Relationship to VPC and Security Group

### How EC2 Module Connects to VPC

The EC2 module uses two VPC components:

1. **VPC ID** - Required to create the security group within the VPC
2. **Public Subnet IDs** - Required to place the EC2 instance in a public subnet

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     EC2 Module Connections                       │
│                                                                  │
│  ┌─────────────────┐          ┌─────────────────────────────┐  │
│  │  VPC Module     │          │   EC2 Module                 │  │
│  ├─────────────────┤          ├─────────────────────────────┤  │
│  │                 │          │                             │  │
│  │ Outputs:        │          │ Requires:                   │  │
│  │ - main_vpc_id  │─────────▶│ - vpc_id                   │  │
│  │ - main_public_ │          │ - public_subnet_ids[0]     │  │
│  │   subnet_ids   │          │                             │  │
│  │                 │          │ Uses internally:            │  │
│  │                 │          │ - Security Group Module     │  │
│  │                 │          │ - Key Pair Module           │  │
│  └─────────────────┘          └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name            = "finishline"
  environment             = "dev"
  manage_by               = "terraform"
  vpc_id                  = module.vpc.main_vpc_id
  public_subnet_ids       = module.vpc.main_public_subnet_ids
  key_pair_name           = "finishline-dev-key"
}
```

### Complete Example

```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name            = "finishline"
  environment             = "prod"
  manage_by               = "terraform"
  vpc_id                  = module.vpc.main_vpc_id
  public_subnet_ids       = module.vpc.main_public_subnet_ids
  key_pair_name           = "finishline-prod-key"

  # Instance configuration
  ami_id                  = ""  # Use latest Amazon Linux 2
  jump_host_instance_type = "t3.micro"
  root_volume_size        = 20
  enable_monitoring       = true

  # Custom ingress rules
  ingress_rules = [
    {
      description = "SSH from admin network"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/24"]  # Bastion subnet only
    }
  ]

  # Tagging
  component   = "jump-host"
  cost_center = "IT-001"

  # Additional tags
  tags = {
    "Environment" = "production"
  }
}
```

## How EC2 Uses VPC Resources

### 1. VPC ID Connection

The EC2 module requires the VPC ID to create a security group within the correct VPC:

```hcl
# EC2 main.tf
module "security_group" {
  source = "../security_group"
  vpc_id = var.vpc_id  # From VPC module
  # ...
}
```

### 2. Public Subnet Connection

The EC2 instance is deployed in the first public subnet:

```hcl
# EC2 main.tf
resource "aws_instance" "jump_host" {
  subnet_id = var.public_subnet_ids[0]  # First public subnet
  # ...
}
```

### 3. Integration in Environment

```hcl
# Environment main.tf
module "vpc" {
  source = "../vpc"
  # ... VPC configuration
}

module "ec2" {
  source = "../ec2"

  # Connect to VPC
  vpc_id            = module.vpc.main_vpc_id
  public_subnet_ids = module.vpc.main_public_subnet_ids
}
```

## Variables

| Variable                  | Description                                      | Type           | Required |
| ------------------------- | ------------------------------------------------ | -------------- | -------- |
| `project_name`            | The name of the project                          | `string`       | Yes      |
| `environment`             | The environment (dev, staging, prod)             | `string`       | Yes      |
| `manage_by`               | The entity managing the instance                 | `string`       | Yes      |
| `vpc_id`                  | The ID of the VPC (from VPC module)              | `string`       | Yes      |
| `public_subnet_ids`       | List of public subnet IDs (from VPC module)      | `list(string)` | Yes      |
| `key_pair_name`           | Name of the SSH key pair                         | `string`       | Yes      |
| `create_key_pair`         | Whether to create a new key pair (default: true) | `bool`         | No       |
| `ami_id`                  | Custom AMI ID (uses Amazon Linux 2 if empty)     | `string`       | No       |
| `jump_host_instance_type` | EC2 instance type                                | `string`       | No       |
| `root_volume_size`        | Root volume size in GB                           | `number`       | No       |
| `enable_monitoring`       | Enable CloudWatch monitoring                     | `bool`         | No       |
| `user_data_base64`        | Base64 encoded user data                         | `string`       | No       |
| `ingress_rules`           | Ingress security group rules                     | `list(object)` | No       |
| `egress_rules`            | Egress security group rules                      | `list(object)` | No       |
| `component`               | Component tag value                              | `string`       | No       |
| `cost_center`             | Cost center tag value                            | `string`       | No       |
| `tags`                    | Additional tags                                  | `map(string)`  | No       |

## Outputs

| Output                | Description         |
| --------------------- | ------------------- |
| `instance_id`         | EC2 instance ID     |
| `instance_public_ip`  | Public IP address   |
| `instance_arn`        | EC2 instance ARN    |
| `public_dns`          | Public DNS hostname |
| `security_group_id`   | Security group ID   |
| `security_group_name` | Security group name |
| `key_pair_name`       | SSH key pair name   |

## Resources Created

### 1. Security Group (Internal Module)

- Created within the specified VPC using the security_group module
- Configurable ingress/egress rules
- Controls access to the EC2 instance
- Name format: `{project_name}-ec2-sg`

### 2. Key Pair (Internal Module)

- RSA 4096-bit SSH key pair
- Public key registered with AWS
- Private key saved locally as `.pem` file

### 3. EC2 Instance (Jump Host)

- Deployed in first public subnet
- Uses specified instance type
- Configurable root volume (gp3, encrypted)
- Detailed monitoring enabled
- Custom user data support

### 4. Elastic IP

- Associated with EC2 instance
- Persistent public IP address
- Survives instance stop/start

## Tagging Convention

All resources are tagged consistently:

- `Name`: `{project_name}-{environment}-jump-host`
- `Project`: The project name
- `Environment`: The environment
- `Component`: The component type (default: jump-host)
- `Tier`: Management
- `ManagedBy`: The value of `manage_by` variable
- `CostCenter`: Cost center code
- `Terraform`: Set to "true"

## Integration with VPC Module

The EC2 module requires VPC resources:

```hcl
# 1. Create VPC first
module "vpc" {
  source = "../vpc"
  # ... VPC configuration
}

# 2. Create EC2 using VPC resources
module "ec2" {
  source = "../ec2"

  # VPC connection
  vpc_id            = module.vpc.main_vpc_id
  public_subnet_ids = module.vpc.main_public_subnet_ids

  # ... other configuration
}
```

### Why Public Subnets?

The jump host is deployed in a **public subnet** because:

1. It needs a **public IP** for remote SSH access
2. It acts as a **bastion** to access private resources
3. It can route to the **internet** via Internet Gateway

## Jump Host Use Case

### Accessing Private Resources

```
User Internet          Jump Host              Private Resources
    │                      │                        │
    │  SSH (port 22)       │                        │
    ├─────────────────────▶│                        │
    │                      │  SSH to private host   │
    │                      ├───────────────────────▶│
    │                      │                        │
    │                      │  Response              │
    │                      ◀───────────────────────┤
    │◀─────────────────────┤                        │
    │                      │                        │
```

### Workflow

1. User SSH to jump host using the private key:

   ```bash
   ssh -i finishline-dev-key.pem ec2-user@<jump-host-public-ip>
   ```

2. From jump host, SSH to private resources:
   ```bash
   ssh -i finishline-dev-key.pem ec2-user@<private-instance-private-ip>
   ```

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0

## Dependencies

1. **VPC Module**: Must provide VPC ID and public subnet IDs
2. **Key Pair**: Created internally by the module

## Troubleshooting

### Cannot SSH to Jump Host

1. Verify Elastic IP is associated
2. Check security group allows SSH (port 22) from your IP
3. Ensure instance is in a public subnet with internet access
4. Verify key pair permissions: `chmod 400 *.pem`

### Instance Not Accessible

1. Check security group ingress rules
2. Verify instance is running
3. Check route table for public subnet (0.0.0.0/0 → IGW)
4. Verify internet gateway is attached to VPC

### Key Pair Not Working

1. Ensure .pem file has correct permissions
2. Verify key pair name matches
3. Check instance profile has correct permissions

## Security Best Practices

1. **Restrict SSH Access**: Limit ingress to specific IP ranges
2. **Use Strong Key**: RSA 4096-bit key is used
3. **Enable Monitoring**: CloudWatch monitoring enabled by default
4. **Encrypted Volumes**: Root volume is encrypted (gp3)
5. **Least Privilege**: Use minimal ingress rules

## Complete Example with All Dependencies

```hcl
# 1. VPC Module
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

# 2. EC2 Module (creates security group and key pair internally)
module "ec2" {
  source = "../ec2"

  project_name            = "finishline"
  environment             = "dev"
  manage_by               = "terraform"

  # Connect to VPC
  vpc_id                  = module.vpc.main_vpc_id
  public_subnet_ids       = module.vpc.main_public_subnet_ids

  # SSH key
  key_pair_name           = "finishline-dev-jump-host"

  # Instance config
  jump_host_instance_type = "t3.micro"
  root_volume_size        = 20

  # Security - restrict SSH to your IP
  ingress_rules = [
    {
      description = "SSH from my IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["<your-ip>/32"]  # Replace with your IP
    }
  ]
}

# Output the jump host IP
output "jump_host_ip" {
  value = module.ec2.instance_public_ip
}
```
