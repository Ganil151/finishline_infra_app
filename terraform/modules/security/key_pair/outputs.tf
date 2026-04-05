#========================================================================
#                        *** Key Pair Outputs ***
#========================================================================
output "key_name" {
  description = "The name of the key pair."
  value       = aws_key_pair.public_key.key_name
}

output "public_key" {
  description = "The public key of the key pair."
  value       = aws_key_pair.public_key.public_key
}

output "private_key" {
  description = "The private key of the key pair."
  value       = tls_private_key.rsa_4096.private_key_pem
  sensitive   = true
} 