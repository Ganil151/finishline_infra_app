#============================================================
#                 *** Jumphost Module  ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//compute/jumphost"
}

locals {
  compute_tag = {
    project_name = "finishline-infra-app"
    environment  = "dev"
    managed_by   = "finishline-infra-team"
  }
}

#============================================================
#  Dependencies
#============================================================
dependency "key_pair" {
  config_path = "../../security/key_pair"
}

dependency "vpc" {
  config_path = "../../networking/vpc"
}

dependency "sg" {
  config_path = "../../networking/sg"
}

inputs = {
  #============================================================
  #  Project Variables
  #============================================================
  project_name  = local.compute_tag.project_name
  environment   = local.compute_tag.environment
  managed_by    = local.compute_tag.managed_by
  aws_region    = "us-east-1"
  computed_tags = local.compute_tag

  #============================================================
  #  Jumphost Instance Variables
  #============================================================
  is_finishline_jumphost_enabled = true

  ami_id = ""

  instance_type = "t3.micro"

  subnet_id  = dependency.vpc.outputs.public_subnets_ids[0]
  vpc_id     = dependency.vpc.outputs.vpc_id
  security_group_ids = [dependency.sg.outputs.security_group_id]
  key_name   = dependency.key_pair.outputs.key_name

  iam_instance_profile_name = ""

  root_volume_type                  = "gp3"
  root_volume_size                  = 30
  root_volume_encrypted             = true
  root_volume_kms_key_id            = null
  root_volume_delete_on_termination = true

  ebs_block_devices = []

  associate_public_ip_address = true
  private_ip                  = ""

  metadata_http_endpoint               = "enabled"
  metadata_http_tokens                 = "required"
  metadata_http_put_response_hop_limit = 1

  #============================================================
  #  User Data Variables
  #============================================================
  user_data_script_path       = "${get_terragrunt_dir()}/../../../../scripts/jumphost-install-tools.sh"
  user_data_replace_on_change = true
}
