#======================================================
# Finishline Infra Jump Host
#======================================================

# Include Security Group Module
module "security_group" {
  source = "../security_group"

  project_name        = var.project_name
  environment         = var.environment
  manage_by           = var.manage_by
  vpc_id              = var.vpc_id
  security_group_name = "${var.project_name}-ec2-sg"
  ingress_rules       = var.ingress_rules
  egress_rules        = var.egress_rules
}

# Include Key Pair Module
module "key_pair" {
  source = "../secret/key_pair"

  project_name    = var.project_name
  environment     = var.environment
  manage_by       = var.manage_by
  key_name        = var.key_pair_name
  create_key_pair = var.create_key_pair
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jump_host" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.jump_host_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [module.security_group.finishline_sg_id]
  key_name               = module.key_pair.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring                  = var.enable_monitoring
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = true

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-jump-host"
    Environment = var.environment
    Project     = var.project_name
    Component   = var.component
    ManagedBy   = var.manage_by
    Tier        = "Management"
    CostCenter  = var.cost_center
    Terraform   = "true"
  }, var.tags)

}

resource "aws_eip" "jump_host" {
  instance = aws_instance.jump_host.id
  domain   = "vpc"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-jump-host-eip"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Terraform   = "true"
  }, var.tags)


}
