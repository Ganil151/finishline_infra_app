#========================================================================
#                 *** PROJECT Variables Configuration ***
#========================================================================
variable "project_name" {
  description = "Name of the project (e.g., finishline-infra-app)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "managed_by" {
  description = "Team managing this resource (e.g., finishline-infra-team)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment (e.g., us-east-1)"
  type        = string
}
#========================================================================
#                      *** JUMPHOST Variables Configuration ***
#========================================================================
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
}
variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}
variable "security_group_id" {
  description = "Security group ID for the EC2 instance"
  type        = string
}
variable "key_name" {
  description = "Key pair name for the EC2 instance"
  type        = string
}
variable "root_volume_type" {
  description = "Root volume type for the EC2 instance"
  type        = string
}
variable "root_volume_size" {
  description = "Root volume size for the EC2 instance"
  type        = number
}
variable "root_volume_encrypted" {
  description = "Root volume encryption for the EC2 instance"
  type        = bool
}
variable "root_volume_kms_key_id" {
  description = "Root volume KMS key ID for the EC2 instance"
  type        = string
}
variable "root_volume_delete_on_termination" {
  description = "Root volume delete on termination for the EC2 instance"
  type        = bool
}
variable "ebs_block_devices" {
  description = "EBS block devices for the EC2 instance"
  type        = list(map(string))
}
variable "associate_public_ip_address" {
  description = "Associate public IP address for the EC2 instance"
  type        = bool
}
variable "private_ip" {
  description = "Private IP address for the EC2 instance"
  type        = string
}
variable "metadata_http_endpoint" {
  description = "Metadata HTTP endpoint for the EC2 instance"
  type        = string
}
variable "metadata_http_put_response_hop_limit" {
  description = "Metadata HTTP put response hop limit for the EC2 instance"
  type        = number
}
variable "metadata_http_tokens" {
  description = "Metadata HTTP tokens for the EC2 instance"
  type        = string
}
variable "user_data_replace_on_change" {
  description = "User data replace on change for the EC2 instance"
  type        = bool
}
variable "user_data_script_path" {
  description = "User data script path for the EC2 instance"
  type        = string
}
variable "common_tags" {
  description = "Common tags for the EC2 instance"
  type        = map(string)
}