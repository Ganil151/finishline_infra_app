#!/bin/bash
# ============================================================
# COMPLETE FIX SCRIPT - Run all fixes in order for Karpenter
# ============================================================

echo "=== Karpenter Complete Fix Script ==="
echo ""

# 1. Check and fix CRDs
echo "1. Checking CRDs..."
kubectl get crds | grep -q "nodeclaims.karpenter.sh" || {
  echo "   Installing correct NodeClaim CRD..."
  kubectl apply --server-side=true -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/refs/tags/v1.0.8/pkg/apis/crds/karpenter.sh_nodeclaims.yaml
}

# Delete incorrect CRD
kubectl get crds | grep -q "nodeclaims.karpenter.k8s.aws" && {
  echo "   Removing incorrect NodeClaim CRD..."
  kubectl delete crd nodeclaims.karpenter.k8s.aws
}

echo ""

# 2. Check and create OIDC provider
echo "2. Checking OIDC provider..."
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList" --output text | grep -q "oidc.eks" || {
  echo "   Creating OIDC provider..."

  CLUSTER_NAME="finishline-infra-app-dev-eks"
  AWS_REGION="us-east-1"

  OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)

  # Use eksctl if available
  if command -v eksctl &> /dev/null; then
    eksctl utils associate-iam-oidc-provider \
      --cluster $CLUSTER_NAME \
      --region $AWS_REGION \
      --approve
  else
    # Manual creation (get thumbprint)
    THUMBPRINT=$(openssl s_client -showcerts \
      -connect oidc.eks.us-east-1.amazonaws.com:443 </dev/null 2>/dev/null | \
      openssl x509 -fingerprint -sha256 -noout 2>/dev/null | \
      cut -d= -f2 | tr -d ':')

    aws iam create-open-id-connect-provider \
      --url $OIDC_URL \
      --client-id-list sts.amazonaws.com \
      --thumbprint-list $THUMBPRINT \
      --region $AWS_REGION
  fi
}

echo ""

# 3. Verify IRSA annotation
echo "3. Checking IRSA annotation..."
kubectl get sa karpenter -n karpenter -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' | grep -q "karpenter" || {
  echo "   Patching service account..."
  ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/finishline-infra-app-dev-eks-karpenter-controller-role"
  kubectl patch serviceaccount karpenter -n karpenter \
    -p "{\"metadata\": {\"annotations\": {\"eks.amazonaws.com/role-arn\": \"$ROLE_ARN\"}}}"
}

echo ""

# 4. Restart Karpenter
echo "4. Restarting Karpenter controller..."
kubectl rollout restart deployment karpenter -n karpenter

echo ""
echo "5. Waiting for Karpenter to be ready..."
kubectl wait --for=condition=available deployment/karpenter -n karpenter --timeout=120s || {
  echo "   Timeout waiting for deployment. Checking pod status..."
  kubectl get pods -n karpenter
}

echo ""
echo "=== Fix Complete ==="
