# Terragrunt Destroy Troubleshooting Guide

**Last Updated:** March 29, 2026  
**Applies to:** `destroy-all.sh` and `run-all.sh destroy`

---

## Common Failure Scenarios

### 1. KMS Module Not Found in Dev Environment

**Error:**
```
[ERROR] Module directory not found: environments/dev/security/kms
```

**Cause:** The KMS module only exists in `prod` and `stage` environments, not in `dev`.

**Resolution:** The script has been updated to skip KMS in environments where it doesn't exist. If you're using an older script version, manually skip it:

```bash
# Destroy dev without KMS
cd environments/dev
terragrunt run-all destroy --exclude-dir security/kms
```

---

### 2. Dependency Errors - Module References Deleted Resources

**Error:**
```
Error: Dependency "iam" output "karpenter_controller_role_arn" not found
```

**Cause:** Modules are being destroyed in the wrong order. Dependencies must be destroyed **after** the modules that depend on them.

**Resolution:** Use the updated `destroy-all.sh` script which follows the correct order:

```bash
./destroy-all.sh --environment dev
```

**Correct Destroy Order:**
1. Karpenter (depends on EKS and IAM)
2. Jumphost
3. EKS
4. ALB
5. Security Groups
6. VPC
7. KMS (if exists)
8. Key Pair
9. IAM (destroyed last)

---

### 3. AWS API Throttling

**Error:**
```
Error: operation error EC2: DeleteVpc, api error RequestLimitExceeded
```

**Cause:** AWS API rate limits exceeded during bulk resource deletion.

**Resolution:** The updated script includes automatic retry logic with 5-second delays. If failures persist:

```bash
# Wait 5-10 minutes and retry
sleep 600
./destroy-all.sh --environment dev
```

---

### 4. S3 Bucket Not Empty

**Error:**
```
Error: BucketNotEmpty: The bucket you tried to delete is not empty
```

**Cause:** Terraform state bucket still contains state files.

**Resolution:** Manually empty the bucket first:

```bash
# List bucket contents
aws s3 ls s3://finishline-infra-app-ba3347ce --recursive

# Empty the bucket (including all versions)
aws s3 rm s3://finishline-infra-app-ba3347ce --recursive

# Then retry destroy
./destroy-all.sh --environment dev
```

---

### 5. EKS Cluster Still Has Resources

**Error:**
```
Error: error deleting EKS Cluster: ResourceInUseException: Cluster has associated resources
```

**Cause:** EKS cluster still has managed node groups, Fargate profiles, or addons.

**Resolution:**

```bash
# 1. Update kubeconfig
aws eks update-kubeconfig --name finishline-infra-app-dev-eks

# 2. List and delete all resources in karpenter namespace
kubectl delete namespace karpenter --ignore-not-found

# 3. List and delete all Karpenter resources
kubectl delete ec2nodeclass --all --ignore-not-found
kubectl delete nodepool --all --ignore-not-found

# 4. Wait for nodes to terminate
kubectl get nodes
# Wait until only managed nodes remain (or none)

# 5. Retry destroy
cd environments/dev/compute/eks
terragrunt destroy
```

---

### 6. VPC Has Dependencies

**Error:**
```
Error: operation error EC2: DeleteVpc, api error DependencyViolation
```

**Cause:** VPC still has attached resources (ENIs, security groups, subnets, etc.)

**Resolution:**

```bash
# 1. Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev" --query "Vpcs[0].VpcId" --output text)

# 2. Check for remaining ENIs
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID"

# 3. Check for remaining security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID"

# 4. Check for remaining subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"

# 5. Check for NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"

# 6. Manually delete remaining resources if needed
# WARNING: Only do this if you're sure they're not needed!
```

---

### 7. IAM Roles Still Attached to Resources

**Error:**
```
Error: DeleteConflict: Cannot delete IAM role, it is still attached to
```

**Cause:** IAM role is still referenced by EKS, EC2, or Lambda.

**Resolution:**

```bash
# 1. Find what's using the role
ROLE_NAME=finishline-dev-karpenter-controller
aws iam list-attached-role-policies --role-name $ROLE_NAME
aws iam list-instance-profiles-for-role --role-name $ROLE_NAME

# 2. Detach policies
aws iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::ACCOUNT:policy/POLICY_NAME

# 3. Delete instance profiles
PROFILE_NAME=$(aws iam list-instance-profiles-for-role --role-name $ROLE_NAME --query "InstanceProfiles[0].InstanceProfileName" --output text)
aws iam remove-role-from-instance-profile \
  --instance-profile-name $PROFILE_NAME \
  --role-name $ROLE_NAME
aws iam delete-instance-profile --instance-profile-name $PROFILE_NAME

# 4. Retry IAM destroy
cd environments/dev/security/iam
terragrunt destroy
```

---

### 8. Terraform State Lock Issues

**Error:**
```
Error: Error acquiring the state lock
```

**Cause:** Another Terraform process is running or a previous run crashed.

**Resolution:**

```bash
# 1. Check for running terraform processes
ps aux | grep terraform

# 2. Force unlock (only if you're sure no other process is running)
cd environments/dev/networking/vpc
terragrunt force-unlock LOCK_ID

# 3. If using S3 backend, check for lock file
aws s3 ls s3://finishline-infra-app-ba3347ce/env:/dev/networking/vpc/terraform.tfstate.lock.info

# 4. Delete lock file (if you're sure it's stale)
aws s3 rm s3://finishline-infra-app-ba3347ce/env:/dev/networking/vpc/terraform.tfstate.lock.info
```

---

### 9. Karpenter Resources Still Managing Nodes

**Error:**
```
Error: operation error EC2: TerminateInstances, api error IncorrectInstanceState
```

**Cause:** Karpenter is still actively managing EC2 instances.

**Resolution:**

```bash
# 1. Scale down Karpenter deployment
aws eks update-kubeconfig --name finishline-infra-app-dev-eks
kubectl scale deployment karpenter -n karpenter --replicas=0

# 2. Delete all NodeClaims
kubectl delete nodeclaims --all

# 3. Wait for nodes to terminate
watch kubectl get nodes

# 4. Delete Karpenter namespace
kubectl delete namespace karpenter

# 5. Retry Karpenter destroy
cd environments/dev/compute/karpenter
terragrunt destroy
```

---

### 10. CloudWatch Log Groups Persist

**Error:**
```
Warning: CloudWatch log groups still exist after destroy
```

**Cause:** Terraform doesn't automatically delete CloudWatch log groups.

**Resolution:**

```bash
# List all log groups for the environment
aws logs describe-log-groups --log-group-name-prefix /aws/eks/finishline-dev \
  --query "logGroups[].logGroupName" --output table

# Delete log groups
aws logs delete-log-group --log-group-name /aws/eks/finishline-dev/cluster
aws logs delete-log-group --log-group-name /aws/containerinsights/finishline-dev-performance
# ... repeat for each log group
```

---

## Manual Cleanup Checklist

If automated destroy fails completely, use this manual checklist:

```bash
ENV=dev  # or stage, prod

# 1. Karpenter
kubectl scale deployment karpenter -n karpenter --replicas=0
kubectl delete nodeclaims --all
kubectl delete ec2nodeclass --all
kubectl delete nodepool --all
kubectl delete namespace karpenter

# 2. EKS Addons
aws eks update-kubeconfig --name finishline-infra-app-$ENV-eks
aws eks delete-addon --cluster-name finishline-infra-app-$ENV-eks --addon-name vpc-cni
aws eks delete-addon --cluster-name finishline-infra-app-$ENV-eks --addon-name coredns
aws eks delete-addon --cluster-name finishline-infra-app-$ENV-eks --addon-name kube-proxy

# 3. EKS Node Groups (if any)
aws eks delete-nodegroup --cluster-name finishline-infra-app-$ENV-eks --nodegroup-name managed-ng

# 4. EKS Cluster
aws eks delete-cluster --name finishline-infra-app-$ENV-eks

# 5. Wait for EKS deletion (10-15 minutes)
aws eks wait cluster-deleted --name finishline-infra-app-$ENV-eks

# 6. ALB
aws elbv2 delete-load-balancer --load-balancer-arn <arn>
aws elbv2 delete-target-group --target-group-arn <arn>

# 7. Security Groups (revoke rules first)
# Use AWS Console or manually revoke/delete

# 8. VPC
# Delete route tables, subnets, internet gateway, NAT gateways first
# Then delete VPC

# 9. IAM Roles
# Detach policies, delete instance profiles, then delete roles

# 10. KMS Keys (schedule for deletion)
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 7

# 11. S3 Buckets (state and logs)
aws s3 rm s3://finishline-infra-app-ba3347ce --recursive
aws s3 rb s3://finishline-infra-app-ba3347ce
aws s3 rm s3://finishline-infra-app-alb-logs-$ENV --recursive
aws s3 rb s3://finishline-infra-app-alb-logs-$ENV

# 12. CloudWatch Log Groups
aws logs delete-log-group --log-group-name /aws/eks/finishline-infra-app-$ENV-eks
```

---

## Post-Destroy Verification

After destroy completes, verify cleanup:

```bash
# Check for remaining EC2 instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENV" \
  --query "Reservations[].Instances[].InstanceId"

# Check for remaining security groups
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=$ENV" \
  --query "SecurityGroups[].GroupId"

# Check for remaining VPCs
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=$ENV" \
  --query "Vpcs[].VpcId"

# Check for remaining IAM roles
aws iam list-roles --query "Roles[?contains(RoleName, 'finishline')].RoleName"

# Check for remaining S3 buckets
aws s3 ls | grep finishline

# Check for remaining EKS clusters
aws eks list-clusters --query "clusters[?contains(@, 'finishline')]"
```

---

## Getting Help

If you encounter issues not covered here:

1. **Check Terraform state:**
   ```bash
   cd environments/$ENV/networking/vpc
   terragrunt state list
   ```

2. **Enable debug logging:**
   ```bash
   export TF_LOG=DEBUG
   export TF_LOG_PATH=./terraform-debug.log
   terragrunt destroy
   ```

3. **Review AWS CloudTrail:**
   - Navigate to CloudTrail in AWS Console
   - Filter by event source (e.g., `ec2.amazonaws.com`, `eks.amazonaws.com`)
   - Look for failed API calls

4. **Contact AWS Support:**
   - Create a support case with error details
   - Include CloudTrail event IDs

---

**END OF TROUBLESHOOTING GUIDE**
