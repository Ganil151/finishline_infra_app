# Karpenter Module Fixes

## Summary

Fixed the "cannot create REST client: no client config" error and identified additional misconfigurations in the Karpenter module.

## Issues Found and Fixed

### 1. Kubernetes Provider Configuration (Primary Issue)

**Problem:** The Kubernetes provider was not properly configured, causing the "cannot create REST client: no client config" error.

**Root Cause:**

- Missing `terraform` block with `required_providers` declaration
- CA certificate was not being base64-decoded before passing to the provider

**Fix Applied:**

- Added `terraform` block with explicit `required_providers` for Kubernetes provider
- Changed `cluster_ca_certificate = var.cluster_ca_certificate` to `cluster_ca_certificate = base64decode(var.cluster_ca_certificate)`
- Removed unused Helm provider configuration to simplify the module

**Files Modified:**

- `terraform/modules/compute/karpenter/provider.tf`

### 2. EC2NodeClass Role Configuration (Secondary Issue)

**Problem:** The EC2NodeClass resource was using the instance profile name for the `role` field, but it should use the IAM role name.

**Root Cause:**

- The `role` field in EC2NodeClass expects the IAM role name, not the instance profile name
- The module was using `var.karpenter_instance_profile_name` instead of the role name

**Fix Applied:**

- Changed `role = var.karpenter_instance_profile_name` to `role = var.karpenter_node_role_name`
- Added new variable `karpenter_node_role_name` to the module
- Updated all environment Terragrunt configurations to pass the new variable

**Files Modified:**

- `terraform/modules/compute/karpenter/main.tf`
- `terraform/modules/compute/karpenter/variables.tf`
- `terraform/environments/dev/compute/karpenter/terragrunt.hcl`
- `terraform/environments/stage/compute/karpenter/terragrunt.hcl`
- `terraform/environments/prod/compute/karpenter/terragrunt.hcl`

### 3. Root Configuration Update

**Problem:** The root.hcl was generating an empty kubernetes-provider.tf file, which could cause confusion.

**Fix Applied:**

- Updated the comment in root.hcl to clarify that Kubernetes provider is configured in module-specific provider.tf files

**Files Modified:**

- `terraform/root.hcl`

## Verification Steps

After applying these fixes, verify the configuration:

1. **Check provider initialization:**

   ```bash
   cd terraform/environments/dev/compute/karpenter
   terragrunt init
   ```

2. **Validate configuration:**

   ```bash
   terragrunt validate
   ```

3. **Apply changes:**
   ```bash
   terragrunt apply
   ```

## Additional Notes

- The EKS cluster must have public endpoint enabled or you must run from within the VPC (e.g., jumphost)
- AWS CLI must be installed and configured with proper credentials
- The Kubernetes provider uses `aws eks get-token` for authentication, which requires AWS CLI

## References

- [Karpenter Documentation](https://karpenter.sh/docs/)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [RUNBOOK.md](docs/RUNBOOK.md) - Section 3.5 Karpenter Troubleshooting
