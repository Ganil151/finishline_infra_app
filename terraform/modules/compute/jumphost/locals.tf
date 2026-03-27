locals {
  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-jumphost"
    Module      = "jumphost"
    Environment = var.environment
  })
}
