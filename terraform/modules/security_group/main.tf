resource "aws_security_group" "finishline_sg" {
  name        = "finishline_sg_${var.project_name}"
  description = "Allow inbound/outbound traffic for Finishline"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name        = "finishline_sg_${var.project_name}"
    Project     = var.project_name
    Environment = var.environment
    ManageBy    = var.manage_by
    Terraform   = "true"
  }

}
