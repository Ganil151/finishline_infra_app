output "finishline_sg_id" {
  description = "The ID of the Finishline security group"
  value       = aws_security_group.finishline_sg.id
}

output "finishline_sg_name" {
  description = "The name of the Finishline security group"
  value       = aws_security_group.finishline_sg.name
}

output "finishline_sg_arn" {
  description = "The ARN of the Finishline security group"
  value       = aws_security_group.finishline_sg.arn
}


