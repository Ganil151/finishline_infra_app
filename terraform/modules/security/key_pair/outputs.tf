# ===========================================================
#               ***   Key Pair Outputs   ***
# ===========================================================

output "key_name" {
  description = "The name of the key pair"
  value       = aws_key_pair.finishline_public_key.key_name
}

output "key_pair_id" {
  description = "The key pair ID"
  value       = aws_key_pair.finishline_public_key.id
}

output "private_key_path" {
  description = "The local file path where the private key is stored"
  value       = local_file.private_key.filename
}

output "public_key" {
  description = "The public key in OpenSSH format"
  value       = tls_private_key.rsa_4096.public_key_openssh
  sensitive   = false
}
