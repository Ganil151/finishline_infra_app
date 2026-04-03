#========================================================================
#                 *** Security Group Outputs ***
#========================================================================

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.finishline_security_group.id
}

output "security_group_arn" {
  description = "The ARN of the security group"
  value       = aws_security_group.finishline_security_group.arn
}

output "security_group_name" {
  description = "The name of the security group"
  value       = aws_security_group.finishline_security_group.name
}

output "security_group_vpc_id" {
  description = "The VPC ID the security group belongs to"
  value       = aws_security_group.finishline_security_group.vpc_id
}

output "security_group_owner_id" {
  description = "The AWS account ID that owns the security group"
  value       = aws_security_group.finishline_security_group.owner_id
}
