#======================================================
# Finishline Infra Jump Host
#======================================================

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_84-gp2"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jump_host" {
  ami           = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type = var.jump_host_instance_type
  subnet_id = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.finishline_sg_id]
  key_name = var.key_pair_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring
  user_data_base64 = var.user_data_base64
  user_data_replace_on_change = true

  tags = merge({
    Name = "${var.project_name}-${var.environment}-jump-host"
    Environment = var.environment
    Project = var.project_name
    Component = var.component
    ManagedBy = var.managed_by
    Tier = "Management"
    CostCenter = var.cost_center
  }, var.tags)

}

resource "aws_eip" "jump_host" {
  instance = aws_instance.jump_host.id
  domain = "vpc"
  
  tags = merge({
    Name = "${var.project_name}-${var.environment}-jump-host-eip"
  }, var.tags)

  
}