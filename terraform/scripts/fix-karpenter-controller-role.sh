#!/bin/bash
CLUSTER_NAME="finishline-infra-app-dev-eks"
ROLE_NAME="${CLUSTER_NAME}-karpenter-controller-role"
AWS_REGION="us-east-1"

echo "1. Fetching OIDC Parameters..."
# Get OIDC URL and dynamically extract the domain and exact IAM ARN
OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
OIDC_DOMAIN=${OIDC_URL#https://}
OIDC_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Url, '$OIDC_DOMAIN')].Arn" --output text)

echo "2. Building Trust Policy payload for $ROLE_NAME..."
cat > /tmp/karpenter-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_DOMAIN}:sub": "system:serviceaccount:karpenter:karpenter",
          "${OIDC_DOMAIN}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# 3. First, try to update if it exists, otherwise CREATE it.
echo "3. Updating/Creating AWS IAM Role..."
if ! aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    echo "   Role does not exist natively on AWS! Creating it..."
    aws iam create-role \
      --role-name $ROLE_NAME \
      --assume-role-policy-document file:///tmp/karpenter-trust-policy.json
    
    echo "   Attaching Admin Node policy for EC2 Bootstrapping..."
    aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
else
    echo "   Updating Trust Policy..."
    aws iam update-assume-role-policy \
      --role-name $ROLE_NAME \
      --policy-document file:///tmp/karpenter-trust-policy.json
fi

echo "4. Patching K8s ServiceAccount Annotation..."
# Ensure the ServiceAccount targets the exact role ARN explicitly
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query "Role.Arn" --output text)
kubectl patch serviceaccount karpenter -n karpenter \
  -p "{\"metadata\": {\"annotations\": {\"eks.amazonaws.com/role-arn\": \"$ROLE_ARN\"}}}"

echo "5. Restarting Karpenter Pod..."
kubectl rollout restart deployment karpenter -n karpenter

echo "6. Verifying Recovery in Real-time..."
kubectl get pods -n karpenter -w
