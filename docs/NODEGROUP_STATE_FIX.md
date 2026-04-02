# EKS Node Group State Synchronization Fix

**Date:** April 1, 2026  
**Issue:** Node group already exists in AWS but Terraform state doesn't recognize it  
**Error:** `ResourceInUseException: NodeGroup already exists with name default-nodegroup and cluster name finishline-infra-app-dev-eks`

---

## Problem

The EKS node group was created in a previous Terraform run but failed during creation. Now:

- The node group exists in AWS (in CREATE_FAILED state)
- Terraform's state doesn't have a record of it
- Terraform tries to create it again, causing a conflict

---

## Solution Options

### Option 1: Import Existing Node Group into Terraform State (Recommended)

**Pros:**

- ✅ Preserves existing resources
- ✅ No downtime
- ✅ Clean state management

**Steps:**

1. **Check if node group exists in AWS:**

   ```bash
   aws eks describe-nodegroup \
     --cluster-name finishline-infra-app-dev-eks \
     --nodegroup-name default-nodegroup \
     --region us-east-1
   ```

2. **Get the node group ARN:**

   ```bash
   aws eks describe-nodegroup \
     --cluster-name finishline-infra-app-dev-eks \
     --nodegroup-name default-nodegroup \
     --region us-east-1 \
     --query "nodegroup.nodegroupArn" \
     --output text
   ```

3. **Import into Terraform state:**

   ```bash
   cd terraform/environments/dev/compute/eks

   # Import the node group
   terragrunt import aws_eks_node_group.nodegroup[0] \
     arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/finishline-infra-app-dev-eks/nodegroup/default-nodegroup/NODEGROUP_ID
   ```

4. **Verify import:**

   ```bash
   terragrunt state list | grep nodegroup
   ```

5. **Apply configuration to update state:**
   ```bash
   terragrunt plan
   terragrunt apply
   ```

---

### Option 2: Delete Existing Node Group and Recreate

**Pros:**

- ✅ Clean slate
- ✅ Simple process

**Cons:**

- ❌ Downtime during recreation
- ❌ May take 10-15 minutes

**Steps:**

1. **Delete the existing node group:**

   ```bash
   aws eks delete-nodegroup \
     --cluster-name finishline-infra-app-dev-eks \
     --nodegroup-name default-nodegroup \
     --region us-east-1
   ```

2. **Wait for deletion to complete:**

   ```bash
   # Monitor deletion status
   aws eks describe-nodegroup \
     --cluster-name finishline-infra-app-dev-eks \
     --nodegroup-name default-nodegroup \
     --region us-east-1 \
     --query "nodegroup.status"

   # Wait until status is DELETED or command returns error
   # This typically takes 5-10 minutes
   ```

3. **Apply Terraform configuration:**
   ```bash
   cd terraform/environments/dev/compute/eks
   terragrunt plan
   terragrunt apply
   ```

---

### Option 3: Remove from Terraform State and Recreate

**Pros:**

- ✅ Clean state
- ✅ No manual AWS CLI needed

**Cons:**

- ❌ May cause issues if node group has dependencies

**Steps:**

1. **Remove from Terraform state:**

   ```bash
   cd terraform/environments/dev/compute/eks
   terragrunt state rm aws_eks_node_group.nodegroup[0]
   ```

2. **Apply configuration:**
   ```bash
   terragrunt plan
   terragrunt apply
   ```

---

## Recommended Approach

**Use Option 1 (Import)** if:

- The node group is in a usable state (ACTIVE or CREATE_FAILED with recoverable errors)
- You want to preserve the existing resource
- You want minimal disruption

**Use Option 2 (Delete and Recreate)** if:

- The node group is in an unrecoverable state
- You want a clean start
- You're okay with 10-15 minutes of downtime

**Use Option 3 (Remove from State)** if:

- You're certain the node group has no dependencies
- You want the simplest process
- You're comfortable with potential state issues

---

## Step-by-Step: Option 1 (Import) - Detailed

### Step 1: Check Node Group Status

```bash
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1
```

**Expected Output:**

```json
{
  "nodegroup": {
    "nodegroupName": "default-nodegroup",
    "nodegroupArn": "arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/finishline-infra-app-dev-eks/nodegroup/default-nodegroup/NODEGROUP_ID",
    "status": "CREATE_FAILED",
    ...
  }
}
```

### Step 2: Get Node Group ARN

```bash
NODEGROUP_ARN=$(aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1 \
  --query "nodegroup.nodegroupArn" \
  --output text)

echo "Node Group ARN: $NODEGROUP_ARN"
```

### Step 3: Import into Terraform State

```bash
cd terraform/environments/dev/compute/eks

# Import the node group
terragrunt import aws_eks_node_group.nodegroup[0] $NODEGROUP_ARN
```

**Expected Output:**

```
aws_eks_node_group.nodegroup[0]: Importing from ID "arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/finishline-infra-app-dev-eks/nodegroup/default-nodegroup/NODEGROUP_ID"...
aws_eks_node_group.nodegroup[0]: Import prepared!
  Prepared aws_eks_node_group for import
aws_eks_node_group.nodegroup[0]: Refreshing state... [id=arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/finishline-infra-app-dev-eks/nodegroup/default-nodegroup/NODEGROUP_ID]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

### Step 4: Verify Import

```bash
# Check if node group is in state
terragrunt state list | grep nodegroup

# Show node group details
terragrunt state show aws_eks_node_group.nodegroup[0]
```

### Step 5: Apply Configuration

```bash
# Plan to see what changes will be made
terragrunt plan

# Apply changes (should update SPOT capacity type)
terragrunt apply
```

---

## Step-by-Step: Option 2 (Delete and Recreate) - Detailed

### Step 1: Delete Node Group

```bash
aws eks delete-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1
```

### Step 2: Monitor Deletion

```bash
# Check deletion status every 30 seconds
while true; do
  STATUS=$(aws eks describe-nodegroup \
    --cluster-name finishline-infra-app-dev-eks \
    --nodegroup-name default-nodegroup \
    --region us-east-1 \
    --query "nodegroup.status" \
    --output text 2>/dev/null || echo "DELETED")

  echo "Status: $STATUS"

  if [ "$STATUS" = "DELETED" ]; then
    echo "Node group deleted successfully!"
    break
  fi

  sleep 30
done
```

### Step 3: Apply Terraform

```bash
cd terraform/environments/dev/compute/eks
terragrunt plan
terragrunt apply
```

---

## Troubleshooting

### If Import Fails

**Error:** `Cannot import non-existent remote object`

**Solution:** The node group doesn't exist in AWS. Use Option 2 (Delete and Recreate) instead.

**Error:** `Resource already exists in state`

**Solution:** Remove from state first:

```bash
terragrunt state rm aws_eks_node_group.nodegroup[0]
terragrunt import aws_eks_node_group.nodegroup[0] $NODEGROUP_ARN
```

### If Delete Fails

**Error:** `NodegroupNotFoundException`

**Solution:** The node group is already deleted. Proceed with Terraform apply.

**Error:** `ResourceInUseException: Nodegroup has dependent resources`

**Solution:** Delete dependent resources first:

```bash
# List EC2 instances in the node group
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=default-nodegroup" \
  --query "Reservations[].Instances[].InstanceId"

# Terminate instances
aws ec2 terminate-instances --instance-ids INSTANCE_ID_1 INSTANCE_ID_2

# Wait for termination
aws ec2 wait instance-terminated --instance-ids INSTANCE_ID_1 INSTANCE_ID_2

# Retry node group deletion
aws eks delete-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1
```

### If Terraform Apply Still Fails

**Error:** `NodeGroup already exists`

**Solution:** Force refresh Terraform state:

```bash
cd terraform/environments/dev/compute/eks
terragrunt refresh
terragrunt plan
terragrunt apply
```

---

## Verification After Fix

```bash
# 1. Check node group status
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1 \
  --query "nodegroup.status"

# Expected: "ACTIVE"

# 2. Check node group capacity type
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1 \
  --query "nodegroup.capacityType"

# Expected: "SPOT"

# 3. Check nodes are running
aws eks update-kubeconfig \
  --name finishline-infra-app-dev-eks \
  --region us-east-1

kubectl get nodes

# Expected: 2 nodes in Ready state

# 4. Verify Terraform state
cd terraform/environments/dev/compute/eks
terragrunt state list | grep nodegroup

# Expected: aws_eks_node_group.nodegroup[0]
```

---

## Quick Reference Commands

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1

# Delete node group
aws eks delete-nodegroup \
  --cluster-name finishline-infra-app-dev-eks \
  --nodegroup-name default-nodegroup \
  --region us-east-1

# Import node group
cd terraform/environments/dev/compute/eks
terragrunt import aws_eks_node_group.nodegroup[0] NODEGROUP_ARN

# Remove from state
terragrunt state rm aws_eks_node_group.nodegroup[0]

# Refresh state
terragrunt refresh

# Apply configuration
terragrunt plan
terragrunt apply
```

---

**END OF STATE FIX GUIDE**
