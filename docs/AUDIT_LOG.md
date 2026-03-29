# Infrastructure Audit Log: Part 1

## Issue Resolution: AMI Casing Conflict

**Incident Summary:** 
An invalid AMI type validation failure was detected when parameter value `BOTTLEROCKET_X86_64` was passed to the `node_group_ami_type` variable. 

**Root Cause:**
The Terraform AWS Provider performs strict validation mapped directly to Amazon EKS API enumerations. The AWS API rigorously enforces case-sensitivity and strictly expects the designation `BOTTLEROCKET_x86_64` (using a lower-case 'x'). Consequently, `BOTTLEROCKET_X86_64` is inherently invalid. The backend does not implement case-folding or fuzzy string matching; it expects an exact type match. Providing the incorrect string invokes an immediate API conflict due to a literal type divergence.

**Remediation Applied:**
A strict `validation` compliance block has been implemented inside `modules/compute/eks/variables.tf` to trap this error statically. 
- **Enforcement:** The variable `node_group_ami_type` must purely match permissible identifiers (e.g., `BOTTLEROCKET_x86_64`, `AL2_x86_64`, etc.).
- **Outcome:** The change explicitly captures case-sensitive mismatches immediately during terraform plan or validation stages, delivering an exact message about API string-matching logic to the user. No silent corrections exist; explicitly valid input is required.
