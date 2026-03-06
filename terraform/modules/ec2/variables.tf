variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment for the EC2 instance"
  type        = string
}

variable "manage_by" {
  description = "The entity responsible for managing the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance. If empty, will use the latest Amazon Linux 2 AMI"
  type        = string
  default     = ""
}

variable "jump_host_instance_type" {
  description = "The instance type for the jump host"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the EC2 instance"
  type        = list(string)
}

variable "finishline_sg_id" {
  description = "The security group ID to attach to the EC2 instance"
  type        = string
}

variable "key_pair_name" {
  description = "The key pair name for the EC2 instance"
  type        = string
}

variable "root_volume_size" {
  description = "The size of the root volume in GB"
  type        = number
  default     = 20
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for the EC2 instance"
  type        = bool
  default     = true
}

variable "user_data_base64" {
  description = "The base64 encoded user data for the EC2 instance"
  type        = string
  default     = ""
}

variable "component" {
  description = "The component name for tagging"
  type        = string
  default     = "jump-host"
}

variable "cost_center" {
  description = "The cost center for tagging"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to the EC2 instance"
  type        = map(string)
  default     = {}
}
