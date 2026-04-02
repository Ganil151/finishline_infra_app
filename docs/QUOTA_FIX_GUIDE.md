# AWS Quota Fix Guide: EKS Node Group Fleet Requests

**Last Updated:** April 1, 2026  
**Issue:** EKS Node Group creation failing due to Fleet Requests quota limit  
**Error:** `You've reached your quota for maximum Fleet Requests for this account. Launching EC2 instance failed.`

---

## Problem Summary

The EKS node group creation is failing because your AWS account has reached the maximum Fleet Requests quota. This quota limits how many EC2 instances can be launched via fleet requests (used by EKS managed node groups).

**Current Configuration:**

- Capacity Type: `ON-DEMAND`
- Desired Size: `2` nodes
- Instance Type: `t3.medium`
- Region: `us-east-1`

---

## Solution Options

### Option 1: Switch to SPOT Instances (Recommended for Dev)

**Pros:**

- ✅ Bypasses On-Demand quota limits
- ✅ Significantly cheaper (60-90% cost savings)
- ✅ Perfect for dev/test environments
- ✅ Quick fix - no AWS support needed

**Cons:**

- ❌ Instances can be interrupted by AWS
- ❌ Not suitable for production workloads

**Implementation:**

Edit [`terraform/environments/dev/compute/eks/terragrunt.hcl`](terraform/environments/dev/compute/eks/terragrunt.hcl:105):

```hcl
# Change from ON-DEMAND to SPOT
node_group_capacity_type = "SPOT"  # Line 105
```

**Apply the change:**

```bash
cd terraform/environments/dev/compute/eks
terragrunt plan
terragrunt apply
```

---

### Option 2: Reduce Node Count to 1

**Pros:**

- ✅ Reduces quota consumption by 50%
- ✅ Still uses On-Demand instances
- ✅ Quick fix

**Cons:**

- ❌ Less redundancy (single point of failure)
- ❌ May not be enough capacity for workloads

**Implementation:**

Edit [`terraform/environments/dev/compute/eks/terragrunt.hcl`](terraform/environments/dev/compute/eks/terragrunt.hcl:110-114):

```hcl
# Reduce from 2 nodes to 1
node_group_scaling_config = {
  desired_size = 1  # Changed from 2
  min_size     = 1  # Changed from 2
  max_size     = 1  # Changed from 2
}
```

**Apply the change:**

```bash
cd terraform/environments/dev/compute/eks
terragrunt plan
terragrunt apply
```

---

### Option 3: Request AWS Quota Increase (Best for Production)

**Pros:**

- ✅ Permanent solution
- ✅ Allows full On-Demand capacity
- ✅ Required for production environments

**Cons:**

- ❌ Takes 24-48 hours for AWS approval
- ❌ May require justification

**Steps to Request Quota Increase:**

1. **Check Current Quota:**

   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-1216C47A \
     --region us-east-1
   ```

2. **Request Increase via AWS CLI:**

   ```bash
   aws service-quotas request-service-quota-increase \
     --service-code ec2 \
     --quota-code L-1216C47A \
     --desired-value 32 \
     --region us-east-1
   ```

3. **Or Request via AWS Console:**
   - Go to: **Service Quotas** → **Amazon EC2** → **Running On-Demand Standard instances**
   - Click **Request quota increase**
   - Set desired value (e.g., 32 vCPUs)
   - Provide business justification

4. **Monitor Request:**
   ```bash
   aws service-quotas list-requested-service-quota-change-history \
     --service-code ec2 \
     --region us-east-1
   ```

**While Waiting for Quota Increase:**
Use Option 1 (SPOT) or Option 2 (reduce nodes) as temporary workaround.

---

### Option 4: Check and Clean Up Existing Resources

**Pros:**

- ✅ May free up quota without any changes
- ✅ Good housekeeping practice

**Cons:**

- ❌ May not be enough to resolve the issue

**Check Existing EC2 Instances:**

```bash
# List all running EC2 instances in the account
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,State.Name]" \
  --output table \
  --region us-east-1

# Count instances by type
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceType" \
  --output text \
  --region us-east-1 | sort | uniq -c
```

**Check for Unused Resources:**

```bash
# Check for unattached EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query "Volumes[].[VolumeId,Size,State]" \
  --output table

# Check for unused Elastic IPs
aws ec2 describe-addresses \
  --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" \
  --output table
```

**Clean Up Unused Resources:**

```bash
# Delete unattached EBS volumes
aws ec2 delete-volume --volume-id vol-xxxxx

# Release unused Elastic IPs
aws ec2 release-address --allocation-id eipalloc-xxxxx
```

---

### Option 5: Use Different Instance Type

**Pros:**

- ✅ May have more quota available for different instance families
- ✅ No configuration changes needed

**Cons:**

- ❌ May not be suitable for workloads
- ❌ Different pricing

**Check Quota by Instance Family:**

```bash
# Check quota for different instance families
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --query "Quotas[?contains(ServiceCode, 'ec2') && contains(QuotaName, 'Running')].[QuotaName,Value]" \
  --output table \
  --region us-east-1
```

**Alternative Instance Types:**

```hcl
# Try different instance families
node_group_instance_types = ["t3.small"]      # Smaller, may have more quota
node_group_instance_types = ["t3.large"]      # Larger, may have different quota
node_group_instance_types = ["m5.large"]      # Different family
node_group_instance_types = ["c5.large"]      # Compute optimized
```

---

## Recommended Action Plan

### For Dev Environment (Immediate Fix):

1. **Apply Option 1** (Switch to SPOT):

   ```bash
   # Edit terragrunt.hcl
   node_group_capacity_type = "SPOT"

   # Apply
   cd terraform/environments/dev/compute/eks
   terragrunt plan
   terragrunt apply
   ```

2. **Verify Deployment:**
   ```bash
   aws eks describe-nodegroup \
     --cluster-name finishline-infra-app-dev-eks \
     --nodegroup-name default-nodegroup \
     --region us-east-1
   ```

### For Production Environment (Long-term Fix):

1. **Request Quota Increase** (Option 3) - Start this immediately
2. **Use SPOT instances** in dev/stage while waiting
3. **Keep On-Demand** for production after quota increase

---

## Verification Commands

After applying any fix, verify the node group is healthy:

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name finishline-infra-app-dev-eks \
  --region us-east-1

# Check node status
kubectl get nodes

# Check node group status
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1 \
  --query "nodegroup.status"

# Check node group scaling
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1 \
  --query "nodegroup.scalingConfig"
```

---

## Additional Resources

- [AWS EC2 Quotas Documentation](https://docs.aws.amazon.com/general/latest/gr/ec2-service-limit.html)
- [AWS Service Quotas User Guide](https://docs.aws.amazon.com/servicequotas/latest/userguide/intro.html)
- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [EC2 Spot Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html)

---

## Troubleshooting

### If SPOT instances also fail:

1. **Check SPOT quota:**

   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-34B43A08 \
     --region us-east-1
   ```

2. **Try different instance types:**

   ```hcl
   node_group_instance_types = ["t3.small", "t3.medium", "t3.large"]
   ```

3. **Check for SPOT capacity:**
   ```bash
   aws ec2 describe-spot-instance-requests \
     --region us-east-1 \
     --query "SpotInstanceRequests[].[Status.Code,Status.Message]" \
     --output table
   ```

### If quota increase is denied:

1. **Provide better justification:**
   - Business critical workloads
   - Production environment requirements
   - Expected growth projections

2. **Contact AWS Support:**
   - Create a support case
   - Explain the business need
   - Provide architecture diagrams

3. **Consider Reserved Instances:**
   - For production workloads
   - Better pricing than On-Demand
   - Guaranteed capacity

---

**END OF QUOTA FIX GUIDE**
