#============================================================
#                    ***  ALB Module ***
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  project_name = "finishline-infra-app"
  environment  = "dev"
  managed_by   = "finishline-infra-team"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock-id"
    public_subnets_ids = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
}

dependency "sg" {
  config_path = "../sg"

  mock_outputs = {
    security_group_id = "sg-mock-id"
  }
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//networking/alb"
}

inputs = {
  project_name = local.project_name
  environment = local.environment
  managed_by = local.managed_by

  alb_name = "${local.project_name}-${local.environment}-alb"
  alb_type = "application"
  alb_internal = false
  enable_deletion_protection = false
  enable_http2 = true
  enable_cross_zone_load_balancing = true

  vpc_id = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.public_subnets_ids
  security_group_id = dependency.sg.outputs.security_group_id

  enable_access_logs = false
  access_logs_s3_bucket = ""
  access_logs_s3_prefix = ""

  target_group_port = 80
  target_group_protocol = "HTTP"
  target_type = "instance"

  health_check_enabled = true
  healthy_threshold = 2
  unhealthy_threshold = 3
  health_check_interval = 5
  health_check_timeout = 3
  health_check_path = "/health"
  health_check_matcher = "200"

  stickiness_type = "lb_cookie"
  stickiness_enabled = false
  stickiness_cookie_duration = 86400

  listener_port = 80
  listener_protocol = "HTTP"
  listener_default_action = "forward"

  tags = {
    Name        = "${local.project_name}-${local.environment}-alb"
    Project     = "${local.project_name}"
    Environment = "${local.environment}"
    Manage_by   = "${local.managed_by}"
  }

  computed_tags = {}
}