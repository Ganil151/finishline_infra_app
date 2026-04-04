#========================================================================
#                      *** Key Pair Configuration ***
#========================================================================
#______________________Key Pair Locals Configuration_____________________
locals {
  tags = merge(var.common_tags, {
    Name = var.key_name
    Module = var.key_module
  })
}
#______________________Key Pair TLS Configuration________________________
resource "tls_private_key" "rsa_4096" {
  algorithm = var.key_algorithm
  rsa_bits  = var.rs_bits
}
#______________________Key Pair Pair Configuration_______________________
resource "aws_key_pair" "public_key" {
  key_name   = "${var.project_name}-${var.environment}-${var.key_name}"
  public_key = tls_private_key.rsa_4096.public_key_openssh
  tags = local.tags
  depends_on = [ tls_private_key.rsa_4096 ]
}
#___________________Key Pair Locals File Configuration_____________________
