resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "finishline_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh

  tags = {
    Name        = "finishline_key_pair_${var.project_name}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.rsa_4096.private_key_pem
  filename        = "${var.key_name}.pem"
  file_permission = "0400"

  depends_on = [tls_private_key.rsa_4096]

  provisioner "local-exec" {
    command = "chmod 400 ${var.key_name}.pem"
  }
}
