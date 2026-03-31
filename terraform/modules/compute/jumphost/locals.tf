locals {
  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-jumphost"
    Module      = "jumphost"
    Environment = var.environment
  })
}
