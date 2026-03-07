# Key Pair Module

This Terraform module generates an RSA SSH key pair and saves the private key locally for secure access to EC2 instances.

## Overview

The Key Pair module provides secure SSH access to EC2 instances by:

- Generating a 4096-bit RSA private key
- Creating an AWS Key Pair with the public key
- Saving the private key locally with proper permissions
- Managing key lifecycle through Terraform

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Key Pair Module                              │
│                                                                  │
│  ┌─────────────────────┐     ┌────────────────────────────┐   │
│  │  TLS Private Key     │────▶│   AWS Key Pair             │   │
│  │  (RSA 4096-bit)      │     │   (Public Key)             │   │
│  │                      │     │                            │   │
│  │  - Generated locally │     │  - Registered with AWS     │   │
│  │  - Never leaves local│     │  - Attached to EC2        │   │
│  └──────────┬────────────┘     └────────────────────────────┘   │
│             │                                                    │
│             ▼                                                    │
│  ┌─────────────────────┐                                        │
│  │  Local File          │                                        │
│  │  (Private Key .pem)  │                                        │
│  │                      │                                        │
│  │  - Saved locally     │                                        │
│  │  - chmod 400         │                                        │
│  │  - Used for SSH      │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "key_pair" {
  source = "./modules/secret/key_pair"

  project_name = "finishline"
  environment  = "dev"
  manage_by    = "terraform"
  key_name     = "finishline-dev-key"
}
```

### Complete Example

```hcl
module "key_pair" {
  source = "./modules/secret/key_pair"

  project_name = "finishline"
  environment  = "prod"
  manage_by    = "terraform"
  key_name     = "finishline-prod-jump-host"
}
```

### Using with EC2 Module

```hcl
# Create key pair first
module "key_pair" {
  source = "./modules/secret/key_pair"

  project_name = "finishline"
  environment  = "dev"
  manage_by    = "terraform"
  key_name     = "finishline-dev-key"
}

# Use with EC2 module
module "ec2_jump_host" {
  source = "./modules/ec2"

  project_name            = "finishline"
  environment             = "dev"
  manage_by               = "terraform"
  vpc_id                  = module.vpc.main_vpc_id
  public_subnet_ids       = module.vpc.main_public_subnet_ids
  key_pair_name           = module.key_pair.key_name
  # ... other configuration
}
```

## Variables

| Variable          | Description                                      | Type     | Required |
| ----------------- | ------------------------------------------------ | -------- | -------- |
| `project_name`    | The name of the project                          | `string` | Yes      |
| `environment`     | The environment (dev, staging, prod)             | `string` | Yes      |
| `manage_by`       | The entity responsible for managing the key pair | `string` | Yes      |
| `key_name`        | The name of the SSH key pair                     | `string` | Yes      |
| `create_key_pair` | Whether to create a new key pair (default: true) | `bool`   | No       |

## Outputs

| Output                  | Description                            |
| ----------------------- | -------------------------------------- |
| `key_name`              | The name of the generated SSH key pair |
| `key_pair_status`       | Status: "Created" or "Existing"        |
| `private_key_file_path` | Path to the private key PEM file       |

## Resources Created

### 1. TLS Private Key (`tls_private_key`)

- Generates a 4096-bit RSA private key locally
- Key is generated on the machine running Terraform
- Private key never leaves the local machine

### 2. AWS Key Pair (`aws_key_pair`)

- Creates an AWS Key Pair using the public key from the TLS key
- The public key is registered with AWS
- Can be attached to EC2 instances for SSH access
- If `create_key_pair = false`, creates a placeholder resource for importing existing keys

### 3. Local File (`local_file`)

- Saves the private key to a local `.pem` file
- File naming: `{key_name}.pem`
- File permissions: `0400` (read-only for owner)
- Uses local-exec provisioner to run `chmod 400`

## Tagging Convention

All resources are tagged consistently:

- `Name`: `finishline_key_pair_{project_name}`
- `Project`: The project name
- `Environment`: The environment
- `ManagedBy`: The value of `manage_by` variable
- `Terraform`: Set to "true" for Terraform-managed resources

## Security Considerations

### Private Key Security

1. **Local Storage Only**: The private key is stored only on the local machine running Terraform
2. **Proper Permissions**: File is created with 0400 permissions (read-only for owner)
3. **Never in AWS**: Private key is never uploaded to AWS
4. **Manual Management**: If the key is lost, it cannot be recovered from AWS

### Best Practices

1. **Use Separate Keys per Environment**: Create different keys for dev, staging, and prod
2. **Rotate Keys Periodically**: Generate new keys and update EC2 instances
3. **Store Keys Securely**: Use a secrets manager or secure location
4. **Restrict SSH Access**: Combine with security groups to limit SSH access

## Requirements

- Terraform >= 1.0.0
- OpenSSL (built into Terraform provider)

## Error Handling

The module includes built-in validation to ensure key pair creation succeeds:

1. **Key Pair Validation**: Uses `null_resource` to verify the AWS key pair was created successfully
2. **Private Key File Validation**: Checks that the PEM file was written to disk
3. **Lifecycle Protection**: The AWS key pair has `prevent_destroy = true` to prevent accidental deletion

If any validation fails, Terraform will display an error message indicating what went wrong.

## Dependencies

This module has no external dependencies and can be run independently.

## Considerations

1. **Key Recovery**: If the private key is lost, it cannot be recovered - a new key pair must be created
2. **State Management**: The private key is stored in Terraform state - ensure state is secured
3. **File Location**: The `.pem` file is created in the current working directory where Terraform is run
4. **Name Uniqueness**: Key pair names must be unique within an AWS region
5. **Import Existing Keys**: Set `create_key_pair = false` to import an existing key pair (requires manual AWS key pair creation)

## Troubleshooting

### Permission Denied When SSHing

- Ensure the `.pem` file has correct permissions: `chmod 400 filename.pem`
- Verify the key pair is attached to the EC2 instance
- Check security group allows SSH (port 22) from your IP

### Key Pair Not Found

- Verify the key pair name matches in both modules
- Check that the key was created in the correct AWS region
- Ensure Terraform was applied successfully

### Private Key Not Saved

- Check file permissions in the working directory
- Verify Terraform had write access to the directory
- Check Terraform logs for errors

## Integration with Other Modules

### EC2 Module

```hcl
module "key_pair" {
  source = "../key_pair"
  # ... configuration
}

module "ec2" {
  source = "../ec2"
  key_pair_name = module.key_pair.key_name
  # ... other configuration
}
```

### Jump Host Use Case

The primary use case for this module is creating a jump host (bastion) for accessing private resources:

1. Create key pair
2. Launch EC2 instance in public subnet with the key
3. SSH to jump host using the private key
4. From jump host, SSH to private instances

```bash
# SSH to jump host
ssh -i finishline-dev-key.pem ec2-user@<jump-host-ip>

# From jump host, SSH to private instance
ssh -i finishline-dev-key.pem ec2-user@<private-instance-ip>
```
