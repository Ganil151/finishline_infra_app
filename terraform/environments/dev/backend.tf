terraform {
  backend "s3" {
    bucket       = "finishline-infra-app-9e1f6284"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true

  }
}
