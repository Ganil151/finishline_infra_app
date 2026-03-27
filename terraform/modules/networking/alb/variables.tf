# ===========================================================
#               ***   Project Variables   ***
# ===========================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "managed_by" {
  description = "Team managing this resource"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "computed_tags" {
  description = "Additional tags to apply"
  type        = map(string)
}

# ===========================================================
#               ***   VPC Variables   ***
# ===========================================================
variable "vpc_id" {
  description = "CIDR block for the VPC"
  type        = string
}

# ===========================================================
#               ***   ALB Variables   ***
# ===========================================================
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "alb_internal" {
  description = "Whether the ALB is internal"
  type        = bool
}

variable "alb_type" {
  description = "Type of the Application Load Balancer"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection for the ALB"
  type        = bool
}

variable "enable_http2" {
  description = "Whether to enable HTTP/2 for the ALB"
  type        = bool
}

variable "enable_cross_zone_load_balancing" {
  description = "Whether to enable cross-zone load balancing for the ALB"
  type        = bool
}

variable "enable_access_logs" {
  description = "Whether to enable access logs for the ALB"
  type        = bool
}

variable "access_logs_s3_bucket" {
  description = "S3 bucket for storing access logs"
  type        = string
}
variable "access_logs_s3_prefix" {
  description = "Prefix for access log files in the S3 bucket"
  type        = string
}

variable "target_group_port" {
  description = "Port for the target group"
  type        = number
}

variable "target_group_protocol" {
  description = "Protocol for the target group"
  type        = string
}

variable "target_type" {
  description = "Type of the target"
  type        = string
}

variable "health_check_enabled" {
  description = "Whether to enable health checks for the target group"
  type        = bool
}

variable "healthy_threshold" {
  description = "Number of healthy responses required for a target to be considered healthy"
  type        = number
}

variable "unhealthy_threshold" {
  description = "Number of unhealthy responses required for a target to be considered unhealthy"
  type        = number
}

variable "health_check_timeout" {
  description = "Timeout for health checks"
  type        = number
}

variable "health_check_interval" {
  description = "Interval between health checks"
  type        = number
}

variable "health_check_path" {
  description = "Path for health checks"
  type        = string
}

variable "health_check_matcher" {
  description = "Matcher for health checks"
  type        = string
}

variable "stickiness_type" {
  description = "Type of stickiness for the target group"
  type        = string
}

variable "stickiness_enabled" {
  description = "Whether to enable stickiness for the target group"
  type        = bool
}

variable "stickiness_cookie_duration" {
  description = "Duration for the stickiness cookie"
  type        = number
}

variable "listener_port" {
  description = "Port for the ALB listener"
  type        = number
}

variable "listener_protocol" {
  description = "Protocol for the ALB listener"
  type        = string
}

variable "listener_default_action" {
  description = "Default action for the ALB listener"
  type        = string
}

# ===========================================================
#               ***   Security Group Variables   ***
# ===========================================================
variable "security_group_id" {
  description = "Security group ID to associate with the ALB"
  type        = string
}
