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

module "key_pair" {
  source = "../../modules/secret/key_pair"

  project_name = var.project_name
  environment  = var.environment
  manage_by    = var.manage_by
  key_name     = var.key_name
}


