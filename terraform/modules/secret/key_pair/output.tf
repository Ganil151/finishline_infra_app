output "key_name" {
  description = "The name of the generated key_pair"
  value       = aws_key_pair.finishline_key_pair.key_name
}
