#============================================================
#           ***  Application Load Balancer  ***
#============================================================
resource "aws_alb" "finishline_alb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = var.alb_type
  security_groups    = var.security_group_id != "" ? [var.security_group_id] : []
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_s3_bucket
      prefix  = var.access_logs_s3_prefix
      enabled = var.enable_access_logs
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Project     = "${var.project_name}"
    Environment = "${var.environment}"
    Manage_by   = "${var.managed_by}"
  }

}
#============================================================
#                ***  Target Group  ***
#============================================================
resource "aws_lb_target_group" "finishline_alb_tg" {
  name        = "${var.alb_name}-tg"
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  stickiness {
    type            = var.stickiness_type
    enabled         = var.stickiness_enabled
    cookie_duration = var.stickiness_cookie_duration
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Project     = "${var.project_name}"
    Environment = "${var.environment}"
    Manage_by   = "${var.managed_by}"
  }
}
#============================================================
#                  ***  ALB Listener  ***
#============================================================
resource "aws_lb_listener" "finishline_alb_listener" {
  load_balancer_arn = aws_alb.finishline_alb.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = var.listener_default_action
    target_group_arn = aws_lb_target_group.finishline_alb_tg.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}
