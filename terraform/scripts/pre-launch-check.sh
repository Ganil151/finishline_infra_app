#!/bin/bash
# pre-launch-check.sh

set -e

echo "=== Pre-Launch Validation ==="
echo ""

# Check 1: Empty terragrunt.hcl files
echo "1. Checking for empty terragrunt.hcl files..."
EMPTY_FILES=$(find ../environments/prod ../environments/stage -name "terragrunt.hcl" -empty 2>/dev/null || find environments/prod environments/stage -name "terragrunt.hcl" -empty 2>/dev/null)
if [ -n "$EMPTY_FILES" ]; then
  echo "   ❌ FAIL: Empty terragrunt.hcl files found:"
  echo "$EMPTY_FILES" | sed 's/^/      /'
  exit 1
else
  echo "   ✓ PASS: No empty terragrunt.hcl files"
fi

# Check 2: Prod Karpenter controller role
echo ""
echo "2. Checking prod Karpenter configuration..."
if ! grep -q "karpenter_controller_role_arn" ../environments/prod/compute/karpenter/terragrunt.hcl 2>/dev/null && ! grep -q "karpenter_controller_role_arn" environments/prod/compute/karpenter/terragrunt.hcl 2>/dev/null; then
  echo "   ❌ FAIL: Missing karpenter_controller_role_arn in prod"
  exit 1
else
  echo "   ✓ PASS: Prod Karpenter controller role configured"
fi

# Check 3: S3 access type validation
echo ""
echo "3. Checking S3 access type validation..."
if grep -q '"delete"' ../modules/security/iam/variables.tf 2>/dev/null; then
  echo "   ✓ PASS: S3 access type validation includes 'delete'"
else
  echo "   ⚠ WARNING: S3 access type validation may need update"
fi

# Check 4: Public access CIDRs in prod
echo ""
echo "4. Checking prod EKS public access CIDRs..."
if grep -q '0\.0\.0\.0/0' ../environments/prod/compute/eks/terragrunt.hcl 2>/dev/null; then
  echo "   ⚠ WARNING: Prod EKS allows access from 0.0.0.0/0"
  echo "   Consider restricting to specific IPs"
else
  echo "   ✓ PASS: Prod EKS access is restricted"
fi

# Check 5: SSH open to internet
echo ""
echo "5. Checking NACL SSH rules..."
if grep -q 'cidr_block = "0\.0\.0\.0/0"' ../environments/dev/networking/vpc/terragrunt.hcl 2>/dev/null; then
  echo "   ⚠ WARNING: SSH open to 0.0.0.0/0 in dev NACL rules"
else
  echo "   ✓ PASS: SSH is restricted"
fi

echo ""
echo "=== Validation Complete ==="
echo ""
echo "Review any WARNINGs above before proceeding with deployment."
