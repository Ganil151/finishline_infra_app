output "key_name" {
  description = "The name of the generated key_pair"
  value       = var.create_key_pair ? aws_key_pair.finishline_key_pair[0].key_name : var.key_name
}

output "key_pair_status" {
  description = "Status message indicating key pair creation status"
  value       = var.create_key_pair ? "Created" : "Use existing - ensure key exists in AWS"
}
