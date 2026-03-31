#============================================================
#  Terragrunt Configuration - Monolithic Dev Environment
#============================================================
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../modules//composition/dev"
}

locals {
  # Dynamically fetch the executor's public IPv4 address for security rules
  executor_ip = chomp(run_cmd("--terragrunt-quiet", "curl", "-s", "https://ipv4.icanhazip.com"))
}

inputs = {
  #============================================================
  #  Project Variables
  #============================================================
  environment  = "dev"
  managed_by   = "finishline-infra-team"
  project_name = "finishline-infra-app"

  #============================================================
  #  VPC Configuration (Audited)
  #============================================================
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_karpenter_discovery = true
  karpenter_cluster_name     = "finishline-infra-app-dev-eks"

  # Network ACL Ingress Rules (Audited from vpc/terragrunt.hcl)
  vpc_ingress_rules = [
    { rule_no = 100, from_port = 80, to_port = 80, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" },
    { rule_no = 110, from_port = 443, to_port = 443, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" },
    { rule_no = 120, from_port = 22, to_port = 22, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" },
    { rule_no = 130, from_port = 1024, to_port = 65535, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" }
  ]
  # Network ACL Egress Rules (Audited from vpc/terragrunt.hcl)
  vpc_egress_rules = [
    { rule_no = 100, from_port = 80, to_port = 80, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" },
    { rule_no = 110, from_port = 443, to_port = 443, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" },
    { rule_no = 120, from_port = 1024, to_port = 65535, protocol = "tcp", action = "allow", cidr_block = "0.0.0.0/0" }
  ]

  # VPC Endpoints (Audited from vpc/terragrunt.hcl)
  vpc_create_eks_endpoint = true
  vpc_create_sts_endpoint = true
  vpc_create_ec2_endpoint = true
  vpc_create_s3_endpoint  = true

  #============================================================
  #  Security Group Configuration (Audited from sg/terragrunt.hcl)
  #============================================================
  security_group_name        = "finishline-dev-sg"
  security_group_description = "Security group for dev environment"

  sg_ingress_rules = [
    {
      description = "SSH access from internet"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${local.executor_ip}/32"]
    },
    {
      description = "HTTP access from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS access from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "MySQL - VPC internal only"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "EKS Kubelet - VPC internal only"
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  sg_egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  #============================================================
  #  ALB Configuration (Audited from alb/terragrunt.hcl)
  #============================================================
  alb_name                         = "finishline-infra-app-dev-alb"
  alb_internal                     = false
  alb_type                         = "application"
  enable_deletion_protection       = false
  alb_enable_http2                 = true
  alb_enable_cross_zone_load_balancing = true
  alb_target_group_port            = 80
  alb_target_group_protocol        = "HTTP"
  alb_target_type                  = "instance"
  alb_health_check_path            = "/health"
  alb_health_check_matcher         = "200"
  alb_health_check_interval        = 5
  alb_health_check_enabled         = true
  alb_healthy_threshold            = 3
  alb_unhealthy_threshold          = 3
  alb_health_check_timeout         = 4
  alb_stickiness_type              = "lb_cookie"
  alb_stickiness_enabled           = false
  alb_stickiness_cookie_duration   = 86400
  alb_listener_port                = 80
  alb_listener_protocol            = "HTTP"
  alb_listener_default_action      = "forward"

  #============================================================
  #  IAM & EKS Configuration (Audited from eks/terragrunt.hcl & iam/terragrunt.hcl)
  #============================================================
  cluster_name                  = "finishline-infra-app-dev-eks"
  cluster_version               = "1.35" # Note: Stick to manual select as intended by user
  is_eks_cluster_enabled        = true
  iam_is_eks_role_enabled       = true
  is_eks_nodegroup_role_enabled = true
  iam_oidc_thumbprint           = "REDACTED_OIDC_THUMBPRINT"
  iam_name_suffix               = ""
  iam_eks_oidc_subject          = ""
  iam_eks_oidc_namespace        = "default"
  iam_eks_oidc_service_account  = ""
  iam_s3_bucket_arn             = ""
  iam_s3_prefix                 = "*"
  iam_s3_access_type            = "read"
  iam_is_karpenter_enabled      = true
  iam_karpenter_namespace       = "karpenter"
  iam_karpenter_service_account = "karpenter"
  iam_karpenter_cluster_name    = "finishline-infra-app-dev-eks"
  iam_karpenter_node_instance_profile_name = ""
  iam_enable_deterministic_naming = false
  iam_is_ebs_csi_driver_enabled     = true
  iam_ebs_csi_driver_namespace      = "kube-system"
  iam_ebs_csi_driver_service_account = "ebs-csi-controller-sa"
  endpoint_private_access       = true
  endpoint_public_access        = true

  eks_cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  eks_authentication_mode       = "API"

  node_group_name           = "default-nodegroup"
  node_group_instance_types = ["t3.medium"]
  node_group_scaling_config = {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  eks_node_group_ami_type      = "BOTTLEROCKET_x86_64"
  eks_node_group_capacity_type = "ON_DEMAND"
  eks_node_group_disk_size     = 50
  eks_node_group_labels        = { "node-group-type" = "base" }
  eks_node_group_timeouts      = { create = "60m", update = "60m", delete = "60m" }

  #============================================================
  #  Key Pair & Jumphost Configuration (Audited from jumphost/terragrunt.hcl)
  #============================================================
  key_name                       = "finishline-dev-key"
  key_algorithm                  = "RSA"
  rsa_bits                       = 4096
  is_finishline_jumphost_enabled = true
  jumphost_ami_id                = "" # Uses default AL2
  jumphost_instance_type         = "t3.micro"
  jumphost_root_volume_size      = 30
  jumphost_root_volume_type      = "gp3"
  jumphost_metadata_http_tokens  = "required"
  jumphost_user_data_script_path = "${get_terragrunt_dir()}/../../scripts/jumphost-install-tools.sh"
  jumphost_user_data_replace_on_change = true

  #============================================================
  #  Karpenter Configuration (Audited from karpenter/terragrunt.hcl)
  #============================================================
  karpenter_instance_types          = ["m5.large", "m5.xlarge", "c5.large"]
  karpenter_max_cpu                 = 50
  karpenter_capacity_types          = ["spot", "on-demand"]
  karpenter_ami_family              = "Bottlerocket"
  karpenter_volume_size             = "50Gi"
  karpenter_detailed_monitoring     = false
  karpenter_interruption_queue_name = ""
}
