#========================================================================
#              *** Application Load Balancer Configuration ***
#========================================================================
resource "aws_lb" "finishline_alb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = var.alb_type
  security_groups    = [var.security_group_id]
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

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}
#========================================================================
#                 *** ALB Target Group Configuration ***
#========================================================================
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
    port                = var.health_check_port
    protocol            = var.health_check_protocol
  }

  dynamic "stickiness" {
    for_each = var.stickiness_enabled ? [1] : []
    content {
      type            = var.stickiness_type
      enabled         = var.stickiness_enabled
      cookie_duration = var.stickiness_type == "lb_cookie" ? var.stickiness_duration : null
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-tg"
  })
}
#========================================================================
#                 *** ALB Listener Configuration ***
#========================================================================
resource "aws_lb_listener" "finishline_alb_listener" {
  load_balancer_arn = aws_lb.finishline_alb.arn
  port              = var.listener_port
  protocol          = var.listener_protocol
  certificate_arn   = var.listener_protocol == "HTTPS" ? var.listener_certificate_arn : null
  ssl_policy        = var.listener_protocol == "HTTPS" ? var.listener_ssl_policy : null

  default_action {
    type             = var.listener_default_action
    target_group_arn = aws_lb_target_group.finishline_alb_tg.arn
  }

  lifecycle {
    create_before_destroy = true
  }

}

#========================================================================
#            *** HTTP to HTTPS Redirect Listener (Optional) ***
#========================================================================
resource "aws_lb_listener" "finishline_alb_http_redirect_listener" {
  count = var.create_http_redirect_listener ? 1 : 0

  load_balancer_arn = aws_lb.finishline_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

}
