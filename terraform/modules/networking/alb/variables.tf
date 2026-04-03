#========================================================================
#               *** Finishline Project Variables ***
#========================================================================
variable "project_name" {
  description = "The name of the project"
  type        = string
}
variable "environment" {
  description = "The environment name"
  type        = string
}
variable "aws_region" {
  description = "The AWS region"
  type        = string
}
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
#========================================================================
#               *** Application Load Balancer Variables ***
#========================================================================
variable "alb_name" {
  description = "The name of the Application Load Balancer"
  type        = string
}
variable "alb_internal" {
  description = "Indicates if the ALB is internal"
  type        = bool
}
variable "alb_type" {
  description = "The type of the Application Load Balancer"
  type        = string
}
variable "security_group_id" {
  description = "The ID of the security group"
  type        = string
}
variable "subnet_ids" {
  description = "The IDs of the subnets"
  type        = list(string)
}
variable "enable_deletion_protection" {
  description = "Indicates if deletion protection is enabled"
  type        = bool
}
variable "enable_http2" {
  description = "Indicates if HTTP/2 is enabled"
  type        = bool
}
variable "enable_cross_zone_load_balancing" {
  description = "Indicates if cross-zone load balancing is enabled"
  type        = bool
}
variable "enable_access_logs" {
  description = "Indicates if access logs are enabled"
  type        = bool
}
variable "access_logs_s3_bucket" {
  description = "The S3 bucket for access logs"
  type        = string
}
variable "access_logs_s3_prefix" {
  description = "The prefix for access logs in S3"
  type        = string
}

variable "target_group_port" {
  description = "The port for the target group"
  type        = number
}
variable "target_group_protocol" {
  description = "The protocol for the target group"
  type        = string
}
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
variable "target_type" {
  description = "The type of the target"
  type        = string
}
variable "health_check_enabled" {
  description = "Indicates if health check is enabled"
  type        = bool
}
variable "healthy_threshold" {
  description = "The number of healthy thresholds"
  type        = number
}
variable "unhealthy_threshold" {
  description = "The number of unhealthy thresholds"
  type        = number
}
variable "health_check_timeout" {
  description = "The timeout for health checks"
  type        = number
}
variable "health_check_interval" {
  description = "The interval for health checks"
  type        = number
}
variable "health_check_path" {
  description = "The path for health checks"
  type        = string
}
variable "health_check_matcher" {
  description = "The matcher for health checks (e.g., '200', '200-299', '200,302')"
  type        = string
  default     = "200"
  validation {
    condition     = can(regex("^([0-9]{3}(-[0-9]{3})?(,[0-9]{3}(-[0-9]{3})?)*)$", var.health_check_matcher))
    error_message = "Health check matcher must be valid HTTP codes (e.g., '200', '200-299', '200,302')."
  }
}
variable "health_check_port" {
  description = "The port for health checks (default: traffic-port)"
  type        = string
  default     = "traffic-port"
}
variable "health_check_protocol" {
  description = "The protocol for health checks (default: same as listener protocol)"
  type        = string
  default     = "HTTP"
}
variable "stickiness_type" {
  description = "The type of stickiness"
  type        = string
}
variable "stickiness_enabled" {
  description = "Indicates if stickiness is enabled"
  type        = bool
}

variable "stickiness_duration" {
  description = "The duration for stickiness"
  type        = number
}
variable "listener_port" {
  description = "The port for the listener"
  type        = number
}
variable "listener_protocol" {
  description = "The protocol for the listener"
  type        = string
}
variable "listener_default_action" {
  description = "The default action for the listener"
  type        = string
}

variable "listener_certificate_arn" {
  description = "The ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null
  validation {
    condition     = var.listener_protocol == "HTTPS" ? var.listener_certificate_arn != null : true
    error_message = "listener_certificate_arn is required when listener_protocol is HTTPS."
  }
}

variable "listener_ssl_policy" {
  description = "The SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "create_http_redirect_listener" {
  description = "Whether to create an HTTP to HTTPS redirect listener on port 80"
  type        = bool
  default     = false
}
