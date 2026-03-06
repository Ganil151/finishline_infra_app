variable "cluster_name" {
  description = "The Eks cluster name"
  type        = string
}

variable "is_eks_role_enabled" {
  description = "Whether to enable the Eks cluster role"
  type        = bool
}

variable "is_eks_nodegroup_role_enabled" {
  description = "Whether to enable the Eks node group role"
  type        = bool
}

variable "is_eks_cluster_enabled" {
  description = "Whether to enable the Eks cluster"
  type        = bool
}

variable "eks_oidc_url" {
  description = "The OIDC issuer URL of the EKS cluster (required when is_eks_cluster_enabled = true)"
  type        = string
  default     = ""
}

variable "oidc_thumbprint" {
  description = "List of server certificate thumbprints for the OIDC identity provider"
  type        = list(string)
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

variable "s3_bucket_arn" {
  description = "The name of the S3 bucket to scope the OIDC IAM policy. Leave empty to allow all buckets (not recommended for production)."
  type        = string
  default     = ""
}
