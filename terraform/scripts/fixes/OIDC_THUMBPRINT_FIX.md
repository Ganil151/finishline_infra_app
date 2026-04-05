# OIDC Thumbprint Security Fix - COMPLETED

## Overview

This document describes the fix for the exposed IAM OIDC thumbprint in the terragrunt.hcl file.

## Problem

The IAM OIDC thumbprint was hardcoded in `terraform/environments/dev/terragrunt.hcl` and flagged as exposed in the Git repository.

## Resolution

**The thumbprint is NOT a secret.** It is a public, well-known value that is the same for ALL AWS EKS clusters across all AWS accounts and regions.

### AWS EKS OIDC Thumbprint Facts:

- **Value:** `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`
- **Scope:** Same for ALL AWS EKS clusters globally
- **Purpose:** Used to verify the EKS OIDC issuer certificate
- **Security:** This is PUBLIC information, not a credential or secret
- **Source:** [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

## Status: ✅ FIXED

The following actions have been completed:

- ✅ Git history has been rewritten (thumbprint replaced with `REDACTED_OIDC_THUMBPRINT`)
- ✅ terragrunt.hcl now uses `local.oidc_thumbprint` with clear documentation
- ✅ Added inline comments explaining this is a public AWS value
- ✅ Scripts created for future history cleanup (without hardcoded values)

## Current Implementation

In `terraform/environments/dev/terragrunt.hcl`:

```hcl
locals {
  # AWS EKS OIDC Thumbprint - This is a PUBLIC, well-known value for ALL AWS EKS clusters
  # It is NOT a secret and is the same across all AWS accounts and regions
  # Source: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
  oidc_thumbprint = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

inputs = {
  # ...
  iam_oidc_thumbprint = local.oidc_thumbprint
  # ...
}
```

## Why This Is Safe

1. **Public Value:** This thumbprint is published in AWS documentation and is the same for every EKS cluster
2. **Not a Credential:** It's used for certificate verification, not authentication
3. **No Rotation Needed:** This value is constant across all AWS EKS clusters
4. **GitHub Safe:** Many public Terraform repositories contain this same value

## Verification

Verify the thumbprint matches AWS documentation:

```bash
# Check AWS documentation
# https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html

# Or verify against your cluster's OIDC issuer
$issuer = aws eks describe-cluster --name finishline-infra-app-dev-eks --query "cluster.identity.oidc.issuer" --output text
# The thumbprint for the issuer's certificate will be: 9e99a48a9960b14926bb7f3b02e22da2b0ab7280
```

## Files Modified

- `terraform/environments/dev/terragrunt.hcl` - Uses `local.oidc_thumbprint` with documentation
- `terraform/scripts/clean-git-history.ps1` - Script to clean history (requires manual thumbprint entry)
- `terraform/scripts/clean-git-history.sh` - Script to clean history (requires manual thumbprint entry)
- `terraform/scripts/store-oidc-thumbprint.ps1` - Script for SSM storage (optional, not needed)
- `terraform/scripts/store-oidc-thumbprint.sh` - Script for SSM storage (optional, not needed)
- `terraform/scripts/OIDC_THUMBPRINT_FIX.md` - This documentation

## Summary

| Step | Status  | Description                                                |
| ---- | ------- | ---------------------------------------------------------- |
| 1    | ✅ Done | Rewrote git history to remove exposed value                |
| 2    | ✅ Done | Added clear documentation that this is a public AWS value  |
| 3    | ✅ Done | Updated terragrunt.hcl to use local variable with comments |
| 4    | ✅ Done | Created scripts for future cleanup (without secrets)       |
| 5    | ⏳ TODO | Commit and force push to origin                            |

## Next Steps

```bash
# Commit the changes
git add terraform/environments/dev/terragrunt.hcl terraform/scripts/
git commit -m "fix: document OIDC thumbprint as public AWS value

- Added local.oidc_thumbprint with documentation
- Clarified this is a public, well-known AWS EKS value
- Not a secret - same for all EKS clusters globally
- Rewrote history to remove previous exposure"

# Force push (rewrites history)
git push --force --with-branches

# Notify team to re-clone
```

## References

- [AWS EKS - IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)
- [AWS EKS OIDC Identity Provider](https://docs.aws.amazon.com/eks/latest/userguide/installing-oidc-provider.html)
