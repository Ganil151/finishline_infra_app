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
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = tls_private_key.rsa_4096.public_key_openssh
  tags = local.tags
  depends_on = [ tls_private_key.rsa_4096 ]
}
#___________________Key Pair Locals File Configuration____________________
resource "local_file" "private_key" {
  content = tls_private_key.rsa_4096.private_key_pem
  filename = "${var.private_key_output_path}/${var.project_name}-${var.environment}-key.pem"
  file_permission = "0600"

  # Cross-platform permission handling (Linux/Mac)
  provisioner "local-exec" {
    command     = "chmod 400 ${self.filename}"
    interpreter = ["bash", "-c"]
    on_failure  = continue
  }

  # Cross-platform permission handling (Windows)
  provisioner "local-exec" {
    command     = "powershell -Command \"if (Get-Command 'icacls' -ErrorAction SilentlyContinue) { icacls '${self.filename}' /inheritance:d /grant:r '$($env:USERNAME):(R)' }\""
    interpreter = ["cmd", "/c"]
    on_failure  = continue
  }

  depends_on = [ tls_private_key.rsa_4096 ]
}

resource "null_resource" "key_warning" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'WARNING: The private key has been created at ${local_file.private_key.filename}'"
  }

  depends_on = [ local_file.private_key ]
}