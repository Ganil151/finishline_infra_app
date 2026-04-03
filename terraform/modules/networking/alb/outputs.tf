#========================================================================
#                 *** ALB Outputs ***
#========================================================================

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.finishline_alb.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.finishline_alb.dns_name
}

output "alb_name" {
  description = "The name of the Application Load Balancer"
  value       = aws_lb.finishline_alb.name
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer"
  value       = aws_lb.finishline_alb.zone_id
}

output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.finishline_alb.id
}

#========================================================================
#                 *** Target Group Outputs ***
#========================================================================

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.finishline_alb_tg.arn
}

output "target_group_name" {
  description = "The name of the target group"
  value       = aws_lb_target_group.finishline_alb_tg.name
}

output "target_group_id" {
  description = "The ID of the target group"
  value       = aws_lb_target_group.finishline_alb_tg.id
}

output "target_group_port" {
  description = "The port of the target group"
  value       = aws_lb_target_group.finishline_alb_tg.port
}

output "target_group_protocol" {
  description = "The protocol of the target group"
  value       = aws_lb_target_group.finishline_alb_tg.protocol
}

#========================================================================
#                 *** Listener Outputs ***
#========================================================================

output "listener_arn" {
  description = "The ARN of the ALB listener"
  value       = aws_lb_listener.finishline_alb_listener.arn
}

output "listener_id" {
  description = "The ID of the ALB listener"
  value       = aws_lb_listener.finishline_alb_listener.id
}

output "listener_port" {
  description = "The port of the ALB listener"
  value       = aws_lb_listener.finishline_alb_listener.port
}

output "http_redirect_listener_arn" {
  description = "The ARN of the HTTP to HTTPS redirect listener (if created)"
  value       = try(aws_lb_listener.finishline_alb_http_redirect_listener[0].arn, null)
}
