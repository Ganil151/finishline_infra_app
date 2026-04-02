## 🛡️ Infrastructure Change Summary

**Environment:** (Dev / Stage / Prod)
**Module:** (VPC / EKS / IAM / etc.)

### 🎯 Objective
Briefly describe what this PR achieves (e.g., "Updating EKS cluster to 1.31", "Fixing Node Group Quota").

### 🛠️ Changes Performed
- [ ] Updated `terragrunt.hcl`
- [ ] Modified Terraform Module logic
- [ ] Updated variables/outputs

### ✅ Verification Steps
- [ ] Ran `terragrunt run-all plan` and it succeeded.
- [ ] No formatting issues (`terraform fmt`).
- [ ] Verified changes on AWS Console (for manual checks).

### 🚨 Critical Impacts
Are there any breaking changes? (e.g., "VPC recreation", "Node Group rolling update").

### 📋 Checklist
- [ ] Follows Modular Terragrunt Architecture.
- [ ] Updated `RUNBOOK.md` if necessary.
- [ ] Added/Updated verification scripts.
