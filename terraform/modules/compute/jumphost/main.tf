#========================================================================
#                      *** JUMPHOST Configuration ***
#========================================================================
resource "aws_instance" "finishline_jumphost" {
  count = var.environment == "prod" ? 1 : 0 
  ami = var.ami_id != "" ? var.ami_id : data.aws_ami.latest_amazon_linux.id
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name = var.key_name
  tags = {
    Name = "${var.project_name}-${var.environment}-jumphost"
    Environment = var.environment
    ManagedBy = var.managed_by
  }

  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    encrypted = var.root_volume_encrypted
    kms_key_id = var.root_volume_kms_key_id
    delete_on_termination = var.root_volume_delete_on_termination
  }
  dynamic "ebs_block_device" {
    for_each = var.ebs_block_devices
    content {
      device_name = ebs_block_device.value.device_name
      volume_size = lookup(ebs_block_device.value, "volume_size", 8)
      volume_type = lookup(ebs_block_device.value, "volume_type", "gp3")
      encrypted = lookup(ebs_block_device.value, "encrypted", true)
      kms_key_id = lookup(ebs_block_device.value, "kms_key_id", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
    }
  }
  associate_public_ip_address = var.associate_public_ip_address
  private_ip = var.private_ip != "" ? var.private_ip : null

  metadata_options {
    http_endpoint = var.metadata_http_endpoint
    http_put_response_hop_limit = var.metadata_http_put_response_hop_limit
    http_tokens = var.metadata_http_tokens
  }
  user_data_replace_on_change = var.user_data_replace_on_change
  user_data = var.user_data_script_path != "" ? file(var.user_data_script_path) : null

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-jumphost"
  })

  lifecycle {
    create_before_destroy = true
  } 
  
}