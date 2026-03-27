#============================================================
#  Jumphost Outputs
#============================================================
output "instance_id" {
  description = "ID of the jumphost EC2 instance"
  value       = try(aws_instance.finishline_jumphost[0].id, "")
}

output "instance_arn" {
  description = "ARN of the jumphost EC2 instance"
  value       = try(aws_instance.finishline_jumphost[0].arn, "")
}

output "public_ip" {
  description = "Public IP address of the jumphost"
  value       = try(aws_instance.finishline_jumphost[0].public_ip, "")
}

output "private_ip" {
  description = "Private IP address of the jumphost"
  value       = try(aws_instance.finishline_jumphost[0].private_ip, "")
}

output "public_dns" {
  description = "Public DNS name of the jumphost"
  value       = try(aws_instance.finishline_jumphost[0].public_dns, "")
}

output "private_dns" {
  description = "Private DNS name of the jumphost"
  value       = try(aws_instance.finishline_jumphost[0].private_dns, "")
}

output "key_name" {
  description = "EC2 key pair name used for SSH access"
  value       = var.key_name
}
