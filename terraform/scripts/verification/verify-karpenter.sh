#!/bin/bash
#============================================================
#  Karpenter Verification Script
#============================================================

echo "=== Karpenter Verification ==="
echo ""

# 1. Verify EC2NodeClass
echo "1. EC2NodeClass:"
if kubectl get ec2nodeclass default &>/dev/null; then
    echo "   ✓ EC2NodeClass: default"
else
    echo "   ✗ EC2NodeClass: NOT FOUND"
fi
echo ""

# 2. Verify NodePool
echo "2. NodePool:"
if kubectl get nodepool default &>/dev/null; then
    echo "   ✓ NodePool: default"
else
    echo "   ✗ NodePool: NOT FOUND"
fi
echo ""

# 3. Verify Karpenter Controller
echo "3. Karpenter Controller:"
CONTROLLER_STATUS=$(kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$CONTROLLER_STATUS" == "Running" ]; then
    echo "   ✓ Karpenter Controller: Running"
else
    echo "   ✗ Karpenter Controller: $CONTROLLER_STATUS"
fi
echo ""

# 4. Verify IRSA (IAM Roles for Service Accounts)
echo "4. IRSA:"
IRSA_ARN=$(kubectl get sa karpenter -n karpenter -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
if [[ "$IRSA_ARN" == *"karpenter-controller"* ]]; then
    echo "   ✓ IRSA: CONFIGURED"
    echo "   Role ARN: $IRSA_ARN"
else
    echo "   ✗ IRSA: NOT CONFIGURED"
    echo ""
    echo "   To fix, run:"
    echo "   kubectl patch serviceaccount karpenter -n karpenter \\"
    echo "     -p '{\"metadata\": {\"annotations\": {\"eks.amazonaws.com/role-arn\": \"arn:aws:iam::ACCOUNT-ID:role/finishline-infra-app-dev-eks-karpenter-controller\"}}}'"
fi
echo ""

# 5. Verify CRDs
echo "5. Karpenter CRDs:"
CRDS=$(kubectl get crds | grep -c karpenter 2>/dev/null)
if [ "$CRDS" -ge 3 ]; then
    echo "   ✓ CRDs: $CRDS installed"
    kubectl get crds | grep karpenter | sed 's/^/      /'
else
    echo "   ✗ CRDs: Only $CRDS installed (expected 3)"
fi
echo ""

# 6. Test Karpenter Functionality
echo "6. Karpenter Functionality:"
DISCOVERED_SUBNETS=$(kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100 2>/dev/null | grep -c "Discovered subnets")
if [ "$DISCOVERED_SUBNETS" -gt 0 ]; then
    echo "   ✓ Subnet Discovery: Working"
else
    echo "   ⚠ Subnet Discovery: Checking logs..."
fi
echo ""

echo "=== Verification Complete ==="
