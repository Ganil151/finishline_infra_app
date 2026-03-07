#############################################
# TLS Private Key Generation
#############################################
resource "tls_private_key" "rsa_4096" {
  count     = var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

#############################################
# AWS Key Pair Creation
#############################################
resource "aws_key_pair" "finishline_key_pair" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096[0].public_key_openssh

  tags = {
    Name        = "finishline_key_pair_${var.project_name}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Terraform   = "true"
  }

  lifecycle {
    # Prevent accidental key deletion
    prevent_destroy = true
  }
}

# For using an existing key pair (set create_key_pair = false):
# 
# Option 1: Import existing key pair into Terraform state before running apply:
#   terraform import module.<module_name>.aws_key_pair.imported_key_pair <key-name>
#
# Option 2: Simply set create_key_pair = true in your tfvars to create a new key pair
#
# Note: To use an existing key pair, uncomment the resource below and run terraform import

# resource "aws_key_pair" "imported_key_pair" {
#   count    = var.create_key_pair ? 0 : 1
#   key_name = var.key_name
#   # Provide the actual public key content of your existing key pair
#   # Example: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-comment
#   public_key = "" 
#
#   tags = {
#     Name        = "finishline_key_pair_${var.project_name}"
#     Project     = var.project_name
#     Environment = var.environment
#     ManagedBy   = var.manage_by
#     Terraform   = "true"
#   }
#
#   lifecycle {
#     prevent_destroy = true
#     ignore_changes = [public_key]
#   }
# }

#############################################
# Local Private Key File
#############################################
resource "local_file" "private_key" {
  count           = var.create_key_pair ? 1 : 0
  content         = tls_private_key.rsa_4096[0].private_key_pem
  filename        = "${var.key_name}.pem"
  file_permission = "0400"

  depends_on = [tls_private_key.rsa_4096]

  provisioner "local-exec" {
    command = "chmod 400 ${var.key_name}.pem"
  }
}
