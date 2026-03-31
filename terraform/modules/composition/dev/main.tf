# ===========================================================
#               ***   Networking Layer   ***
# ===========================================================

module "vpc" {
  source = "../../networking/vpc"

  project_name               = var.project_name
  environment                = var.environment
  managed_by                 = var.managed_by
  aws_region                 = var.aws_region
  common_tags                = var.common_tags
  vpc_cidr                   = var.vpc_cidr
  availability_zones         = var.availability_zones
  public_subnets_cidr        = var.public_subnets_cidr
  private_subnets_cidr       = var.private_subnets_cidr
  enable_dns_hostnames       = var.enable_dns_hostnames
  enable_dns_support         = var.enable_dns_support
  enable_karpenter_discovery = var.enable_karpenter_discovery
  karpenter_cluster_name     = var.karpenter_cluster_name
  ingress_rules              = var.vpc_ingress_rules
  egress_rules               = var.vpc_egress_rules
  create_eks_endpoint        = var.vpc_create_eks_endpoint
  create_sts_endpoint        = var.vpc_create_sts_endpoint
  create_ec2_endpoint        = var.vpc_create_ec2_endpoint
  create_s3_endpoint         = var.vpc_create_s3_endpoint
}

module "sg" {
  source = "../../networking/sg"

  project_name               = var.project_name
  environment                = var.environment
  managed_by                 = var.managed_by
  aws_region                 = var.aws_region
  common_tags                = var.common_tags
  vpc_id                     = module.vpc.vpc_id
  security_group_name        = var.security_group_name
  security_group_description = var.security_group_description
  enable_karpenter_discovery = var.enable_karpenter_discovery
  karpenter_cluster_name     = var.karpenter_cluster_name
  ingress_rules              = var.sg_ingress_rules
  egress_rules               = var.sg_egress_rules
}

module "alb" {
  source = "../../networking/alb"

  project_name                     = var.project_name
  environment                      = var.environment
  managed_by                       = var.managed_by
  aws_region                       = var.aws_region
  vpc_id                           = module.vpc.vpc_id
  subnet_ids                       = module.vpc.public_subnets_ids
  security_group_id                = module.sg.security_group_id
  computed_tags                    = var.common_tags
  alb_name                         = var.alb_name
  alb_type                         = var.alb_type
  alb_internal                     = var.alb_internal
  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.alb_enable_http2
  enable_cross_zone_load_balancing = var.alb_enable_cross_zone_load_balancing
  target_group_port                = var.alb_target_group_port
  target_group_protocol            = var.alb_target_group_protocol
  target_type                      = var.alb_target_type
  health_check_path                = var.alb_health_check_path
  health_check_matcher             = var.alb_health_check_matcher
  health_check_interval            = var.alb_health_check_interval
  health_check_enabled             = var.alb_health_check_enabled
  healthy_threshold                = var.alb_healthy_threshold
  unhealthy_threshold              = var.alb_unhealthy_threshold
  health_check_timeout             = var.alb_health_check_timeout
  stickiness_type                  = var.alb_stickiness_type
  stickiness_enabled               = var.alb_stickiness_enabled
  stickiness_cookie_duration       = var.alb_stickiness_cookie_duration
  listener_port                    = var.alb_listener_port
  listener_protocol                = var.alb_listener_protocol
  listener_default_action          = var.alb_listener_default_action
  enable_access_logs               = var.alb_enable_access_logs
  access_logs_s3_bucket            = var.alb_access_logs_s3_bucket
  access_logs_s3_prefix            = var.alb_access_logs_s3_prefix
}

# ===========================================================
#               ***   Security Layer   ***
# ===========================================================

module "iam" {
  source = "../../security/iam"

  project_name                         = var.project_name
  environment                          = var.environment
  managed_by                           = var.managed_by
  aws_region                           = var.aws_region
  common_tags                          = var.common_tags
  cluster_name                         = var.cluster_name
  is_eks_cluster_enabled               = var.is_eks_cluster_enabled
  is_eks_role_enabled                  = var.iam_is_eks_role_enabled
  is_eks_nodegroup_role_enabled        = var.is_eks_nodegroup_role_enabled
  name_suffix                          = var.iam_name_suffix
  eks_oidc_subject                     = var.iam_eks_oidc_subject
  eks_oidc_url                         = module.eks.cluster_oidc_issuer_url
  eks_oidc_namespace                   = var.iam_eks_oidc_namespace
  eks_oidc_service_account             = var.iam_eks_oidc_service_account
  oidc_thumbprint                      = var.iam_oidc_thumbprint
  s3_bucket_arn                        = var.iam_s3_bucket_arn
  s3_prefix                            = var.iam_s3_prefix
  s3_access_type                       = var.iam_s3_access_type
  is_karpenter_enabled                 = var.iam_is_karpenter_enabled
  karpenter_namespace                  = var.iam_karpenter_namespace
  karpenter_service_account            = var.iam_karpenter_service_account
  karpenter_cluster_name               = var.iam_karpenter_cluster_name
  karpenter_node_instance_profile_name = var.iam_karpenter_node_instance_profile_name
  enable_deterministic_naming          = var.iam_enable_deterministic_naming
  is_ebs_csi_driver_enabled            = var.iam_is_ebs_csi_driver_enabled
  ebs_csi_driver_namespace             = var.iam_ebs_csi_driver_namespace
  ebs_csi_driver_service_account       = var.iam_ebs_csi_driver_service_account
}

module "key_pair" {
  source = "../../security/key_pair"

  project_name  = var.project_name
  environment   = var.environment
  managed_by    = var.managed_by
  aws_region    = var.aws_region
  common_tags   = var.common_tags
  key_name      = var.key_name
  key_algorithm = var.key_algorithm
  rsa_bits      = var.rsa_bits
}

# ===========================================================
#               ***   Compute Layer   ***
# ===========================================================

module "eks" {
  source = "../../compute/eks"

  project_name                                = var.project_name
  environment                                 = var.environment
  managed_by                                  = var.managed_by
  aws_region                                  = var.aws_region
  common_tags                                 = var.common_tags
  cluster_name                                = var.cluster_name
  cluster_version                             = var.cluster_version
  is_eks_cluster_enabled                      = true
  eks_cluster_role_arn                        = module.iam.eks_cluster_role_arn
  cluster_enabled_log_types                   = var.eks_cluster_enabled_log_types
  subnets                                     = module.vpc.private_subnets_ids
  endpoint_private_access                     = var.endpoint_private_access
  endpoint_public_access                      = var.endpoint_public_access
  public_access_cidrs                         = ["0.0.0.0/0"]
  security_group_ids                          = [module.sg.security_group_id]
  authentication_mode                         = var.eks_authentication_mode
  bootstrap_cluster_creator_admin_permissions = true
  enable_upgrade_policy                       = false
  upgrade_policy_support_type                 = "STANDARD"
  ebs_csi_driver_role_arn                     = module.iam.ebs_csi_driver_role_arn
  cluster_admin_principals = {
    jumphost_role = module.iam.jumphost_role_arn
  }
  cluster_admin_kubernetes_groups = []
  cluster_admin_policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  is_ebs_csi_driver_enabled       = var.iam_is_ebs_csi_driver_enabled

  is_eks_nodegroup_enabled           = var.is_eks_nodegroup_role_enabled
  node_group_name                    = var.node_group_name
  node_group_role_arn                = module.iam.eks_nodegroup_role_arn
  node_group_subnets                 = module.vpc.private_subnets_ids
  node_group_ami_type                = var.eks_node_group_ami_type
  node_group_instance_types          = var.node_group_instance_types
  node_group_capacity_type           = var.eks_node_group_capacity_type
  node_group_disk_size               = var.eks_node_group_disk_size
  node_group_scaling_config          = var.node_group_scaling_config
  node_group_update_config           = { max_unavailable = 1 }
  node_group_launch_template_id      = ""
  node_group_launch_template_version = ""
  node_group_labels                  = var.eks_node_group_labels
  node_group_tags                    = var.common_tags
  node_group_taints                  = []
  node_group_timeouts                = var.eks_node_group_timeouts
}

module "jumphost" {
  source = "../../compute/jumphost"

  project_name                         = var.project_name
  environment                          = var.environment
  managed_by                           = var.managed_by
  aws_region                           = var.aws_region
  common_tags                          = var.common_tags
  is_finishline_jumphost_enabled       = var.is_finishline_jumphost_enabled
  ami_id                               = var.jumphost_ami_id
  instance_type                        = var.jumphost_instance_type
  subnet_id                            = module.vpc.public_subnets_ids[0]
  vpc_id                               = module.vpc.vpc_id
  security_group_ids                   = [module.sg.security_group_id]
  key_name                             = module.key_pair.key_name
  iam_instance_profile_name            = module.iam.jumphost_instance_profile_name
  root_volume_type                     = var.jumphost_root_volume_type
  root_volume_size                     = var.jumphost_root_volume_size
  root_volume_encrypted                = true
  root_volume_kms_key_id               = ""
  root_volume_delete_on_termination    = true
  ebs_block_devices                    = []
  associate_public_ip_address          = true
  private_ip                           = ""
  metadata_http_endpoint               = "enabled"
  metadata_http_tokens                 = var.jumphost_metadata_http_tokens
  metadata_http_put_response_hop_limit = 1
  user_data_script_path                = var.jumphost_user_data_script_path
  user_data_replace_on_change          = var.jumphost_user_data_replace_on_change
}

#============================================================
#  Readiness Gate - Wait for EKS to be Active before Karpenter
#============================================================
resource "terraform_data" "eks_ready" {
  input = var.cluster_name

  provisioner "local-exec" {
    command = "aws eks wait cluster-active --name ${var.cluster_name}"
  }

  depends_on = [module.eks]
}

resource "time_sleep" "eks_endpoint_ready" {
  create_duration = "60s"

  depends_on = [terraform_data.eks_ready]
}

module "karpenter" {
  source = "../../compute/karpenter"

  depends_on = [time_sleep.eks_endpoint_ready]

  project_name                      = var.project_name
  environment                       = var.environment
  common_tags                       = var.common_tags
  aws_region                        = var.aws_region
  cluster_name                      = module.eks.cluster_name
  cluster_endpoint                  = module.eks.cluster_endpoint
  cluster_ca_certificate            = module.eks.cluster_certificate_authority_data
  karpenter_instance_profile_name   = module.iam.karpenter_node_instance_profile_name
  karpenter_node_role_name          = module.iam.eks_nodegroup_role_name
  karpenter_subnet_tags             = { "karpenter.sh/discovery" = var.cluster_name }
  karpenter_security_group_tags     = { "karpenter.sh/discovery" = var.cluster_name }
  karpenter_instance_types          = var.karpenter_instance_types
  karpenter_max_cpu                 = var.karpenter_max_cpu
  karpenter_capacity_types          = var.karpenter_capacity_types
  karpenter_ami_family              = var.karpenter_ami_family
  karpenter_volume_size             = var.karpenter_volume_size
  karpenter_detailed_monitoring     = var.karpenter_detailed_monitoring
  karpenter_namespace               = "karpenter"
  karpenter_controller_role_arn     = module.iam.karpenter_controller_role_arn
  karpenter_interruption_queue_name = var.karpenter_interruption_queue_name
}
