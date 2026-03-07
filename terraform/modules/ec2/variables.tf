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

variable "vpc_id" {
  description = "The ID of the VPC"
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

variable "ingress_rules" {
  description = "The ingress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "SSH from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "egress_rules" {
  description = "The egress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "finishline_sg_id" {
  description = "(Deprecated) The security group ID to attach to the EC2 instance - now managed internally"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "The key pair name for the EC2 instance"
  type        = string
}

variable "create_key_pair" {
  description = "Whether to create a new key pair or use an existing one"
  type        = bool
  default     = true
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
