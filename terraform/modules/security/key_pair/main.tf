#============================================================
#              ***  Key Pair Resources  ***
#============================================================
locals {
  tags = merge(var.common_tags, {
    Name   = var.key_name
    Module = "key_pair"
  })
}

resource "tls_private_key" "rsa_4096" {
  algorithm = var.key_algorithm
  rsa_bits  = var.rsa_bits
}

resource "aws_key_pair" "finishline_public_key" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa_4096.public_key_openssh

  tags = local.tags

  depends_on = [tls_private_key.rsa_4096]
}

resource "local_file" "private_key" {
  content         = tls_private_key.rsa_4096.private_key_openssh
  filename        = "${path.cwd}/${var.key_name}.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    command     = "powershell -Command \"if (Get-Command 'icacls' -ErrorAction SilentlyContinue) { icacls '${self.filename}' /inheritance:r /grant:r '$($env:USERNAME):(R)' } else { Write-Host 'Skipping permission change - icacls not available' }\""
    interpreter = ["cmd", "/C"]
  }

  depends_on = [tls_private_key.rsa_4096]
}

resource "null_resource" "key_warning" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "Location: ${local_file.private_key.filename}"
      echo "Permissions: 0600"
      echo ""
      echo "IMPORTANT:"
      echo "1. Move this file to a secure location:"
      echo "   mv ${local_file.private_key.filename} ~/.ssh/"
      echo ""
      echo "2. Set correct permissions:"
      echo "   chmod 400 ~/.ssh/${var.key_name}.pem"
      echo ""
      echo "3. Delete from terraform directory after copying!"
      echo ""
    EOT

  }
}
