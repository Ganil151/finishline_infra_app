#============================================================
#  Project Variables
#============================================================
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

variable "computed_tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
}

#============================================================
#  Jumphost Instance Variables
#============================================================
variable "is_finishline_jumphost_enabled" {
  description = "Whether to enable the jumphost instance"
  type        = bool
}

variable "ami_id" {
  description = "AMI ID for the jumphost instance (leave empty to use Amazon Linux 2)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the jumphost"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the jumphost instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the jumphost instance"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs for the jumphost"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for the jumphost"
  type        = string
}

variable "root_volume_type" {
  description = "Root volume type (gp2, gp3, io1, etc.)"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GiB"
  type        = number
}

variable "root_volume_encrypted" {
  description = "Whether to encrypt the root volume"
  type        = bool
}

variable "root_volume_kms_key_id" {
  description = "KMS key ID for root volume encryption"
  type        = string
}

variable "root_volume_delete_on_termination" {
  description = "Whether to delete the root volume on termination"
  type        = bool
}

variable "ebs_block_devices" {
  description = "List of additional EBS block devices"
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    encrypted             = bool
    kms_key_id            = string
    delete_on_termination = bool
    iops                  = number
    throughput            = number
  }))
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address"
  type        = bool
}

variable "private_ip" {
  description = "Private IP address to assign (leave empty for automatic)"
  type        = string
}

variable "metadata_http_endpoint" {
  description = "Whether the instance metadata endpoint is enabled"
  type        = string
}

variable "metadata_http_tokens" {
  description = "Whether IMDSv2 is required (required or optional)"
  type        = string
}

variable "metadata_http_put_response_hop_limit" {
  description = "HTTP put response hop limit for instance metadata"
  type        = number
}

#============================================================
#  User Data Variables
#============================================================
variable "user_data_script_path" {
  description = "Path to the user data script for jumphost initialization"
  type        = string
}

variable "user_data_replace_on_change" {
  description = "Whether to replace the instance when user data changes"
  type        = bool
}
