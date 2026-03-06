# Finishline Infrastructure — Troubleshooting Guide

**Version**: 1.1
**Last Updated**: 2026-03-06
**Owner**: Platform / Infrastructure Team

---

## Table of Contents

1. [Terraform Init / Backend Errors](#1-terraform-init--backend-errors)
2. [AWS Authentication Errors](#2-aws-authentication-errors)
3. [IAM / Permissions Errors](#3-iam--permissions-errors)
4. [OIDC Provider Errors](#4-oidc-provider-errors)
5. [VPC / Networking Errors](#5-vpc--networking-errors)
6. [Key Pair Errors](#6-key-pair-errors)
7. [State Lock Errors](#7-state-lock-errors)
8. [Random Suffix / Resource Replace Loop](#8-random-suffix--resource-replace-loop)
9. [Security Group Errors](#9-security-group-errors)
10. [EKS Cluster Errors](#10-eks-cluster-errors)
11. [General Tips](#11-general-tips)

---

## 1. Terraform Init / Backend Errors

### Error: `Failed to get existing workspaces: S3 bucket does not exist`

```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Cause:** The S3 remote state bucket has not been created yet, or you are pointing to the wrong bucket name.

**Fix:**

1. Verify the bucket name in `terraform/environments/dev/backend.tf` matches what was bootstrapped.
2. If the bucket was never created, run the bootstrap script first:
   ```bash
   bash docs/script/terraInfra_1.sh
   ```
3. Ensure your AWS credentials have `s3:CreateBucket` and `s3:PutObject` permissions.

---

### Error: `Error loading state: BucketRegionError`

```
Error loading state: BucketRegionError: incorrect region, the bucket is not in 'us-east-1' region
```

**Cause:** The `region` field in `backend.tf` does not match the region where the S3 bucket was created.

**Fix:** Update the `region` value in `terraform/environments/dev/backend.tf` to match the bucket's actual region.

---

### Error: `Provider registry.terraform.io/... could not be installed`

**Cause:** No internet access or the provider cache is corrupted.

**Fix:**

```bash
rm -rf .terraform
terraform init
```

If behind a proxy, export:

```bash
export HTTPS_PROXY=http://<proxy-host>:<port>
```

---

## 2. AWS Authentication Errors

### Error: `NoCredentialProviders: no valid providers in chain`

```
Error: configuring Terraform AWS Provider: no valid credential sources found
```

**Cause:** AWS credentials are not configured in the environment.

**Fix (choose one):**

```bash
# Option 1 — static credentials
aws configure

# Option 2 — SSO
aws sso login --profile <profile>
export AWS_PROFILE=<profile>

# Option 3 — environment variables
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

Verify with:

```bash
aws sts get-caller-identity
```

---

### Error: `InvalidClientTokenId: The security token included in the request is invalid`

**Cause:** Expired or rotated credentials.

**Fix:** Re-authenticate:

```bash
aws sso login --profile <profile>
# or re-run aws configure with fresh credentials
```

---

## 3. IAM / Permissions Errors

### Error: `AccessDenied: User ... is not authorized to perform: iam:CreateRole`

**Cause:** The IAM principal running Terraform lacks `iam:CreateRole` (or related `iam:*`) permissions.

**Fix:** Attach the appropriate IAM permissions to your user or role. For development accounts, `AdministratorAccess` is typically used. For production, work with your security team to create a scoped policy covering:

- `iam:CreateRole` / `iam:DeleteRole`
- `iam:AttachRolePolicy` / `iam:DetachRolePolicy`
- `iam:CreatePolicy` / `iam:DeletePolicy`
- `iam:CreateOpenIDConnectProvider` / `iam:DeleteOpenIDConnectProvider`

---

### Error: `EntityAlreadyExists: Role with name ... already exists`

```
Error: creating IAM Role (finishline-cluster-role-XXXX): EntityAlreadyExists
```

**Cause:** A role with the same name already exists in AWS, likely from a prior run where state was lost.

**Fix (option A — import):**

```bash
terraform import module.<module>.aws_iam_role.eks-cluster-role[0] <existing-role-name>
```

**Fix (option B — manual cleanup):**
Delete the orphaned role in the AWS Console under **IAM → Roles**, then re-run `terraform apply`.

---

### Error: `MalformedPolicyDocument: Invalid ARN`

```
Error: MalformedPolicyDocument: Invalid ARN: arn:aws:s3:::arn:aws:s3:::my-bucket
```

**Cause:** A full ARN was passed to the `s3_bucket_arn` variable, which already wraps it in `arn:aws:s3:::…`. The variable expects a **bare bucket name**, not a full ARN.

**Fix:** In your environment's `main.tf`, pass only the bucket name:

```hcl
# Wrong
s3_bucket_arn = "arn:aws:s3:::my-finishline-bucket"

# Correct
s3_bucket_arn = "my-finishline-bucket"
```

---

## 4. OIDC Provider Errors

### Error: `InvalidIdentityToken: No OpenIDConnect provider found`

**Cause:** `is_eks_cluster_enabled` is set to `true` but no EKS cluster exists yet, or the `eks_oidc_url` variable is empty/incorrect.

**Fix:**

1. Ensure the EKS cluster is fully active before enabling OIDC resources.
2. Retrieve the OIDC URL from the cluster:
   ```bash
   aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
   ```
3. Pass it to the module:
   ```hcl
   eks_oidc_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
   ```

---

### Error: OIDC thumbprint validation failure

```
Error: error creating IAM OpenID Connect Provider: InvalidInput: Invalid thumbprint
```

**Cause:** The `oidc_thumbprint` list contains an outdated or incorrect certificate thumbprint.

**Fix:** Fetch the current thumbprint dynamically:

```bash
OIDC_URL=$(aws eks describe-cluster --name <cluster-name> \
  --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
echo | openssl s_client -connect ${OIDC_URL}:443 2>/dev/null \
  | openssl x509 -fingerprint -noout -sha1 \
  | tr -d ':' | awk -F= '{print tolower($2)}'
```

As of 2023, AWS recommends including both root CA thumbprints:

```hcl
oidc_thumbprint = [
  "9e99a48a9960b14926bb7f3b02e22da2b0ab7280",
  "f040c53f4f7048b9b5e7009571b2de2cabc02b6b"
]
```

---

## 5. VPC / Networking Errors

### Error: `VpcLimitExceeded: The maximum number of VPCs has been reached`

**Cause:** AWS default limit for VPCs per region is 5.

**Fix:** Either delete unused VPCs or request a quota increase:

```
AWS Console → Service Quotas → Amazon VPC → VPCs per Region → Request quota increase
```

---

### Error: `InvalidSubnet.Conflict: The CIDR conflicts with another subnet`

**Cause:** The provided CIDR blocks in `public_subnets_cidrs` or `private_subnets_cidrs` overlap with existing subnets.

**Fix:** In `terraform/environments/dev/variables.tf`, choose non-overlapping CIDR ranges:

```hcl
public_subnets_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
```

---

### Error: `InvalidAvailabilityZone: The availability zone does not exist`

**Cause:** An AZ specified in `availability_zones` does not exist in the current region.

**Fix:** List valid AZs for your region:

```bash
aws ec2 describe-availability-zones --region us-east-1 --query "AvailabilityZones[].ZoneName"
```

---

## 6. Key Pair Errors

### Error: `InvalidKeyPair.Duplicate: The keypair already exists`

```
Error: importing EC2 Key Pair: InvalidKeyPair.Duplicate: The keypair 'finishline-key' already exists.
```

**Cause:** A key pair with the same name already exists in AWS. The `key_pair` module generates a new key on each fresh `terraform init` if state is lost.

**Fix (option A — import):**

```bash
terraform import module.key_pair.aws_key_pair.finishline_key_pair <key-pair-name>
```

**Fix (option B — manual cleanup):**
Delete the existing key pair in the AWS Console under **EC2 → Key Pairs**, then re-run `terraform apply`.

---

### Error: `.pem` file has incorrect permissions

```
Warning: Unprotected private key file
Permissions 0644 for 'finishline-key-pair.pem' are too open.
```

**Cause:** The local private key file was not written with the correct permissions.

**Fix:**

```bash
chmod 400 terraform/environments/dev/finishline-key-pair.pem
```

---

## 7. State Lock Errors

### Error: `Error acquiring the state lock`

```
Error: Error acquiring the state lock
Lock Info:
  ID: ...
  Operation: OperationTypePlan
  ...
```

**Cause:** A previous Terraform operation did not release the state lock (e.g., a crashed or interrupted `apply`).

**Fix:**

1. Verify no active Terraform processes are running.
2. Force-unlock (use the Lock ID from the error message):
   ```bash
   terraform force-unlock <LOCK-ID>
   ```

> ⚠️ Only force-unlock if you are certain no other process is running, to avoid state corruption.

---

## 8. Random Suffix / Resource Replace Loop

### Symptom: Terraform proposes destroy+recreate of IAM roles on every plan

```
# aws_iam_role.eks-cluster-role[0] must be replaced
- name = "finishline-cluster-role-4821"
+ name = "finishline-cluster-role-7342"
```

**Cause:** The `random_integer.random_suffix` resource has no `keepers` block, so it generates a new value each plan cycle.

**Fix:** Add a `keepers` block tied to a stable input:

```hcl
resource "random_integer" "random_suffix" {
  min = 1000
  max = 9999
  keepers = {
    cluster_name = var.cluster_name
  }
}
```

If the value has already been applied, do **not** change it — instead, run `terraform refresh` to sync state, then add `keepers` going forward.

---

## 9. Security Group Errors

### Error: `InvalidGroup.Duplicate: The security group already exists`

**Cause:** A security group named `finishline_sg_<project>` already exists in the VPC, likely from a prior failed/orphaned apply.

**Fix:**

```bash
# Find the existing SG ID
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=finishline_sg_<project_name>" \
  --query "SecurityGroups[].GroupId" --output text

# Import it into state
terraform import module.finishline_sg.aws_security_group.finishline_sg <sg-id>
```

---

### Warning: Unrestricted egress (`0.0.0.0/0`)

The security group module allows all outbound traffic by default. This is intentional for dev but should be tightened for staging/prod. If a compliance scanner flags `CKV_AWS_382`, restrict egress to only required destinations and ports.

---

## 10. EKS Cluster Errors

### Error: `InvalidParameterException: EKS Auto Mode is only supported for cluster version 1.29 or above`

```
Error: creating EKS Cluster (...): InvalidParameterException:
EKS Auto Mode is only supported for cluster version 1.29 or above.
```

**Cause:** AWS provider ≥ 6.x may implicitly enable EKS Auto Mode. For clusters running Kubernetes < 1.29, Auto Mode is not supported.

**Fix (option A — upgrade Kubernetes version, recommended):**

In `terraform.tfvars`:

```hcl
cluster_version = "1.29"   # or "1.30", "1.31"
```

**Fix (option B — explicitly disable Auto Mode):**

The EKS module already includes the following blocks to opt out of Auto Mode:

```hcl
compute_config {
  enabled = false
}

storage_config {
  block_storage {
    enabled = false
  }
}

kubernetes_network_config {
  elastic_load_balancing {
    enabled = false
  }
}
```

If you see this error again, verify these blocks are present in `terraform/modules/eks/main.tf` and that the AWS provider version is `~> 6.0` or above.

---

### Error: `ResourceNotFoundException: No cluster found for name: ...`

**Cause:** Attempting to create node groups or add-ons before the cluster is available.

**Fix:** The EKS module uses `depends_on = [aws_eks_cluster.eks]` on both node group resources, and add-ons depend on the node groups. However, if you applied modules selectively (e.g., `terraform apply -target=module.eks.aws_eks_node_group.ondemand-node` before the cluster exists), you may hit this. Always apply the full plan without `-target` for first-time cluster creation.

---

### Error: `InvalidParameterException: Addon ... is not supported on cluster version ...`

**Cause:** The specified add-on version is not compatible with the Kubernetes cluster version.

**Fix:** Look up valid add-on versions for your cluster version:

```bash
aws eks describe-addon-versions \
  --addon-name coredns \
  --kubernetes-version 1.29 \
  --query "addons[].addonVersions[].addonVersion" \
  --output table
```

Then update `addons` in `terraform.tfvars` with a compatible version.

---

### Error: `Error: Kubernetes cluster unreachable` (during post-create operations)

**Cause:** After EKS cluster creation, downstream Kubernetes provider configuration (if used) cannot reach the private API endpoint because the caller's network is not within the VPC.

**Fix:** The cluster uses `endpoint_private_access = true` and `endpoint_public_access = false`. To interact with the cluster from outside the VPC, either:

1. Enable public access temporarily: `endpoint_public_access = true`, then revert after initial setup.
2. Use a bastion host or AWS Systems Manager Session Manager (SSM) within the VPC.
3. Use a VPN or Direct Connect to the VPC.

---

### Symptom: Node groups show `DEGRADED` or nodes not joining the cluster

**Cause (A):** The node group IAM role is missing required policies.
**Fix:** Verify the node group role has these policies attached (managed by `module.iam`):

- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonEBSCSIDriverPolicy`

**Cause (B):** The `aws-auth` ConfigMap does not include the node group role.
**Fix:** EKS should auto-register managed node group roles. If not:

```bash
kubectl describe configmap aws-auth -n kube-system
```

Ensure the nodegroup role ARN appears under `mapRoles`.

---

### Retrieve kubeconfig

```bash
aws eks update-kubeconfig \
  --name finishline-eks-cluster \
  --region us-east-1

kubectl get nodes -o wide
kubectl get pods -A
```

---

## 11. General Tips

| Tip                                                | Command                                            |
| -------------------------------------------------- | -------------------------------------------------- |
| Validate configuration syntax                      | `terraform validate`                               |
| Format all Terraform files                         | `terraform fmt -recursive`                         |
| Preview changes without applying                   | `terraform plan -out=tfplan`                       |
| Refresh only — sync state without changes          | `terraform refresh`                                |
| Target a single resource                           | `terraform apply -target=module.<name>.<resource>` |
| See current state                                  | `terraform show`                                   |
| List all managed resources                         | `terraform state list`                             |
| Remove a resource from state without destroying it | `terraform state rm <resource>`                    |
| Enable verbose logging                             | `export TF_LOG=DEBUG`                              |
| Check EKS cluster status                           | `aws eks describe-cluster --name <cluster-name>`   |
| List EKS node groups                               | `aws eks list-nodegroups --cluster-name <name>`    |

---

> For operational procedures (deployments, teardowns, day-2 ops), see [`docs/RUNBOOK.md`](RUNBOOK.md).
