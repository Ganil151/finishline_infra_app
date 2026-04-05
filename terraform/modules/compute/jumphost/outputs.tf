#========================================================================
#                   *** JUMPHOST Outputs Configuration ***
#========================================================================
output "jumphost_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.finishline_jumphost.id
}
output "jumphost_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.finishline_jumphost.private_ip
}
output "jumphost_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.finishline_jumphost.public_ip
}
output "jumphost_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.finishline_jumphost.arn
}
output "jumphost_tags" {
  description = "Tags of the EC2 instance"
  value       = aws_instance.finishline_jumphost.tags
}
output "jumphost_ami_id" {
  description = "AMI ID of the EC2 instance"
  value       = aws_instance.finishline_jumphost.ami
}
output "jumphost_instance_type" {
  description = "Instance type of the EC2 instance"
  value       = aws_instance.finishline_jumphost.instance_type
}
output "jumphost_subnet_id" {
  description = "Subnet ID of the EC2 instance"
  value       = aws_instance.finishline_jumphost.subnet_id
}
output "jumphost_security_group_id" {
  description = "Security group ID of the EC2 instance"
  value       = aws_instance.finishline_jumphost.vpc_security_group_ids
}
output "jumphost_key_name" {
  description = "Key pair name of the EC2 instance"
  value       = aws_instance.finishline_jumphost.key_name
}
output "jumphost_root_volume_type" {
  description = "Root volume type of the EC2 instance"
  value       = aws_instance.finishline_jumphost.root_block_device[0].volume_type
}
output "jumphost_root_volume_size" {
  description = "Root volume size of the EC2 instance"
  value       = aws_instance.finishline_jumphost.root_block_device[0].volume_size
}
output "jumphost_root_volume_encrypted" {
  description = "Root volume encryption of the EC2 instance"
  value       = aws_instance.finishline_jumphost.root_block_device[0].encrypted
}
output "jumphost_root_volume_kms_key_id" {
  description = "Root volume KMS key ID of the EC2 instance"
  value       = aws_instance.finishline_jumphost.root_block_device[0].kms_key_id
}
output "jumphost_root_volume_delete_on_termination" {
  description = "Root volume delete on termination of the EC2 instance"
  value       = aws_instance.finishline_jumphost.root_block_device[0].delete_on_termination
}
output "jumphost_ebs_block_devices" {
  description = "EBS block devices of the EC2 instance"
  value       = aws_instance.finishline_jumphost.ebs_block_device
}
output "jumphost_associate_public_ip_address" {
  description = "Associate public IP address of the EC2 instance"
  value       = aws_instance.finishline_jumphost.associate_public_ip_address
}
output "jumphost_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.finishline_jumphost.private_ip
}
output "jumphost_metadata_http_endpoint" {
  description = "Metadata HTTP endpoint of the EC2 instance"
  value       = aws_instance.finishline_jumphost.metadata_options.http_endpoint
}
output "jumphost_metadata_http_put_response_hop_limit" {
  description = "Metadata HTTP put response hop limit of the EC2 instance"
  value       = aws_instance.finishline_jumphost.metadata_options.http_put_response_hop_limit
}
output "jumphost_metadata_http_tokens" {
  description = "Metadata HTTP tokens of the EC2 instance"
  value       = aws_instance.finishline_jumphost.metadata_options.http_tokens
}
output "jumphost_user_data_replace_on_change" {
  description = "User data replace on change of the EC2 instance"
  value       = aws_instance.finishline_jumphost.user_data_replace_on_change
}
output "jumphost_user_data_script_path" {
  description = "User data script path of the EC2 instance"
  value       = aws_instance.finishline_jumphost.user_data
}