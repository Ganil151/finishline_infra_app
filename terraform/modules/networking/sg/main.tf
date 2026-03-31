# ===========================================================
#         ***   Security Group Configuration   ***
# ===========================================================
resource "aws_security_group" "finishline_sg" {
  vpc_id = var.vpc_id

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

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-sg"
    }, var.enable_karpenter_discovery && var.karpenter_cluster_name != "" ? {
    "karpenter.sh/discovery" = var.karpenter_cluster_name
  } : {})

}
