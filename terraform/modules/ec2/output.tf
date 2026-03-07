output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.jump_host.id
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_eip.jump_host.public_ip
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.jump_host.arn
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.jump_host.public_dns
}

output "security_group_id" {
  description = "The ID of the security group created for the EC2 instance"
  value       = module.security_group.finishline_sg_id
}

output "security_group_name" {
  description = "The name of the security group created for the EC2 instance"
  value       = module.security_group.finishline_sg_name
}

output "key_pair_name" {
  description = "The name of the key pair created for the EC2 instance"
  value       = module.key_pair.key_name
}
