# FinishLine Infrastructure Documentation Hub

> [!NOTE]
> **The 101 Concept:** Welcome to the brain of the FinishLine Infrastructure project! If Terraform and Terragrunt are the engine and steering wheel of our environments, this folder is the driver's manual. We do not just build infrastructure here; we document *why* we built it, *how* to operate it, and *what* to do when it breaks.
>
> If you are a new DevSecOps engineer onboarding to this repository, **start here.**

> [!TIP]
> **The DevSecOps Angle:** Security isn't just about firewalls and IAM roles; it's about **traceability and operational clarity**. When an incident occurs in production at 3:00 AM, ambiguous documentation is a critical vulnerability. Our guides are written pedagogically—explaining exactly what underlying AWS/Kubernetes APIs a CLI command triggers, ensuring you operate with total confidence and zero guesswork.

---

## Directory Index

Please refer to the following guides based on your current mission:

### 1. 🚀 Deployment & Operations
**File:** [RUNBOOK.md](./RUNBOOK.md)

This is your primary operational manual. It covers:
*   The exact step-by-step dependency sequence for deploying the `vpc`, `security`, and `compute` modules via Terragrunt block resolution.
*   Pre-launch security hardening checklists (verifying open CIDRs, validating IAM strictness).
*   Pedagogical breakdowns of exactly how `aws sts get-caller-identity` negotiates trust and how `kubectl` natively authenticates via `~/.kube/config`.

### 2. 🧯 Incident Response & Troubleshooting
**File:** [KARPENTER_FIXES.md](./KARPENTER_FIXES.md)

If the `karpenter` EC2-auto-provisioner fails to natively schedule Kubernetes pods, consult this guide. It covers:
*   Debugging AWS STS Trust Relationships and IAM OIDC Provider loops bridging EKS to AWS.
*   IRSA (IAM Roles for Service Accounts) logic flow.
*   CrashLoopBackOff remediations for the Karpenter Helm Release.

### 3. 🔍 Security & Compliance
**File:** [AUDIT_LOG.md](./AUDIT_LOG.md)

The historical log of infrastructure compliance audits, vulnerability remediations, and architectural pivots required to pass strict industrial-grade security reviews before migrating code from `dev` to `prod`.

### 4. 📚 Project Specifications
*   **Original Challenge Set (Part 1):** [Finishline_Infra_Project_Assignment.pdf](./Finishline_Infra_Project_Assignment.pdf)
*   **Karpenter Expansion (Part 2):** [Finishline_Karpenter_Project.pdf](./Finishline_Karpenter_Project.pdf)

---

## How to Read This Repository

Each underlying Terraform module (e.g., `compute/eks/README.md`) contains its own localized documentation breaking down its specific resources. 

However, all core modules adhere to a strict **pedagogical framework** comprising:
1.  **The 101 Concept:** A jargon-free explanation of the architectural components.
2.  **The DevSecOps Angle:** The explicit security and operational reasoning behind the architectural design (i.e. Least Privilege, isolating Bastion Hosts, dropping inbound SSH).

Always review the module-level READMEs before executing `terragrunt apply` on an unfamiliar component.
