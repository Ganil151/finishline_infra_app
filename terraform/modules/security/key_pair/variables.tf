#========================================================================
#                        *** Key Pair Variables ***
#========================================================================
variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, test, prod)."
  type        = string
}

variable "key_name" {
  description = "The name of the key pair."
  type        = string
}

variable "key_module" {
  description = "The module name."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "key_algorithm" {
  description = "The algorithm to use for the key pair."
  type        = string
  default     = "RSA"
}

variable "rs_bits" {
  description = "The number of bits to use for the key pair."
  type        = number
  default     = 4096
}

variable "private_key_output_path" {
  description = "The directory path where the private key will be saved"
  type        = string
  default     = "."
}