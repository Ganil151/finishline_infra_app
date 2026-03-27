# ALB Outputs
output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_alb.finishline_alb.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the Application Load Balancer"
  value       = aws_alb.finishline_alb.arn_suffix
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_alb.finishline_alb.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer"
  value       = aws_alb.finishline_alb.zone_id
}

output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_alb.finishline_alb.id
}

# Target Group Outputs
output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.finishline_alb_tg.arn
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the Target Group"
  value       = aws_lb_target_group.finishline_alb_tg.arn_suffix
}

output "target_group_id" {
  description = "The ID of the Target Group"
  value       = aws_lb_target_group.finishline_alb_tg.id
}

output "target_group_name" {
  description = "The name of the Target Group"
  value       = aws_lb_target_group.finishline_alb_tg.name
}

# Listener Outputs
output "listener_arn" {
  description = "The ARN of the Listener"
  value       = aws_lb_listener.finishline_alb_listener.arn
}

output "listener_id" {
  description = "The ID of the Listener"
  value       = aws_lb_listener.finishline_alb_listener.id
}
