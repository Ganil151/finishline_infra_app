##############################################
# VPC Module
##############################################
module "vpc" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  manage_by             = var.manage_by
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  enable_dns_hostnames  = var.enable_dns_hostnames
  enable_dns_support    = var.enable_dns_support
  public_subnets_cidrs  = var.public_subnets_cidrs
  private_subnets_cidrs = var.private_subnets_cidrs
}

##############################################
# Security Group Module
##############################################
module "finishline_sg" {
  source = "../../modules/security_group"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.main_vpc_id
  manage_by           = var.manage_by
  security_group_name = var.security_group_name
  ingress_rules       = var.ingress_rules
  egress_rules        = var.egress_rules
}

##############################################
# Key Pair Module
##############################################
module "key_pair" {
  source = "../../modules/secret/key_pair"

  project_name    = var.project_name
  environment     = var.environment
  manage_by       = var.manage_by
  key_name        = var.key_name
  create_key_pair = var.create_key_pair
}

##############################################
# EC2 Jump Host Module
##############################################
module "jump_host" {
  source = "../../modules/ec2"

  project_name            = var.project_name
  environment             = var.environment
  manage_by               = var.manage_by
  vpc_id                  = module.vpc.main_vpc_id
  public_subnet_ids       = module.vpc.main_public_subnet_ids
  ami_id                  = var.ami_id
  jump_host_instance_type = var.jump_host_instance_type
  key_pair_name           = var.key_name
  create_key_pair         = var.create_key_pair
  root_volume_size        = var.root_volume_size
  enable_monitoring       = var.enable_monitoring
  user_data_base64        = var.user_data_base64
  component               = var.ec2_component
  cost_center             = var.cost_center
  tags                    = var.ec2_tags
}

##############################################
# IAM Module
# Creates EKS cluster role and node group role.
# Must be declared BEFORE EKS module since EKS cluster depends on IAM role.
# Note: OIDC provider is created separately after EKS cluster is ready.
##############################################
module "iam" {
  source = "../../modules/secret/iam"

  cluster_name                  = var.cluster_name
  is_eks_role_enabled           = var.is_eks_role_enabled
  is_eks_nodegroup_role_enabled = var.is_eks_nodegroup_role_enabled
  is_eks_cluster_enabled        = var.is_eks_cluster_enabled

  # Pass empty string initially; OIDC provider will be created separately
  eks_oidc_url = ""
}

##############################################
# EKS Module
# Must be declared after IAM module since it requires IAM role ARNs
##############################################
module "eks" {
  source = "../../modules/eks"

  project_name              = var.project_name
  environment               = var.environment
  manage_by                 = var.manage_by
  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  is_eks_cluster_enabled    = var.is_eks_cluster_enabled
  is_eks_node_group_enabled = var.is_eks_node_group_enabled
  is_eks_addons_enabled     = var.is_eks_addons_enabled

  # IAM Roles from IAM module
  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_nodegroup_role_arn

  # Network — private subnets and cluster security group from VPC/SG modules
  subnet_ids         = module.vpc.main_private_subnet_ids
  security_group_ids = [module.finishline_sg.finishline_sg_id]

  # Endpoint access
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access

  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # Addons
  addons = var.addons

  # On-demand node group
  desired_capacity_on_demand = var.desired_capacity_on_demand
  min_capacity_on_demand     = var.min_capacity_on_demand
  max_capacity_on_demand     = var.max_capacity_on_demand
  ondemand_instance_types    = var.ondemand_instance_types

  # Spot node group
  desired_capacity_spot = var.desired_capacity_spot
  min_capacity_spot     = var.min_capacity_spot
  max_capacity_spot     = var.max_capacity_spot
  spot_instance_types   = var.spot_instance_types
}
