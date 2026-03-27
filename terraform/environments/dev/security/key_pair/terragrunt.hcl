#============================================================
#            *** Key Pair Module - Dev Environment ***
#============================================================

include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//security/key_pair"
}

inputs = {
  project_name   = "finishline-infra-app"
  environment    = "dev"
  managed_by     = "finishline-infra-team"
  aws_region     = "us-east-1"

  key_name       = "finishline-dev-key"
  key_algorithm  = "RSA"
  rsa_bits       = 4096

  computed_tags = {
    Environment = "dev"
    Project     = "finishline-infra-app"
    ManagedBy   = "finishline-infra-team"
  }
}