#!/bin/bash
#============================================================
#  Apply Karpenter Manifests to EKS Cluster
#============================================================
# This script applies the Karpenter EC2NodeClass and NodePool
# manifests to an EKS cluster. It should be run from a machine
# that has access to the EKS cluster (e.g., jumphost, CI/CD).
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - kubectl installed
#   - AWS credentials with EKS access
#   - Network access to EKS cluster endpoint
#
# Usage:
#   ./apply-karpenter-manifests.sh [environment]
#   environment: dev, stage, prod (default: dev)
#
# Examples:
#   ./apply-karpenter-manifests.sh           # Apply to dev
#   ./apply-karpenter-manifests.sh prod      # Apply to prod
#============================================================

set -euo pipefail

#============================================================
# Configuration
#============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-dev}"
REGION="us-east-1"
CLUSTER_NAME="finishline-infra-app-${ENVIRONMENT}-eks"

# Manifest files
EC2NODECLASS_MANIFEST="${SCRIPT_DIR}/ec2nodeclass.yaml"
NODEPOOL_MANIFEST="${SCRIPT_DIR}/nodepool.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#============================================================
# Helper Functions
#============================================================
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

#============================================================
# Validation
#============================================================
print_header "Validating Prerequisites"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi
print_success "AWS CLI is installed"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi
print_success "kubectl is installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid."
    print_error "Run 'aws configure' or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
fi
print_success "AWS credentials are configured"

# Check if manifest files exist
if [[ ! -f "$EC2NODECLASS_MANIFEST" ]]; then
    print_error "EC2NodeClass manifest not found: $EC2NODECLASS_MANIFEST"
    exit 1
fi
print_success "EC2NodeClass manifest found"

if [[ ! -f "$NODEPOOL_MANIFEST" ]]; then
    print_error "NodePool manifest not found: $NODEPOOL_MANIFEST"
    exit 1
fi
print_success "NodePool manifest found"

#============================================================
# Update Kubeconfig
#============================================================
print_header "Updating Kubeconfig"

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

if aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --alias "$CLUSTER_NAME"; then
    print_success "Kubeconfig updated successfully"
else
    print_error "Failed to update kubeconfig"
    print_error "Ensure the EKS cluster exists and you have access to it"
    exit 1
fi

#============================================================
# Verify Cluster Access
#============================================================
print_header "Verifying Cluster Access"

if kubectl cluster-info --context "$CLUSTER_NAME" &> /dev/null; then
    print_success "Successfully connected to EKS cluster"
else
    print_error "Failed to connect to EKS cluster"
    print_error "Check your network access and AWS credentials"
    exit 1
fi

#============================================================
# Apply Manifests
#============================================================
print_header "Applying Karpenter Manifests"

# Apply EC2NodeClass
echo ""
echo "Applying EC2NodeClass manifest..."
if kubectl apply -f "$EC2NODECLASS_MANIFEST" --context "$CLUSTER_NAME"; then
    print_success "EC2NodeClass applied successfully"
else
    print_error "Failed to apply EC2NodeClass"
    exit 1
fi

# Apply NodePool
echo ""
echo "Applying NodePool manifest..."
if kubectl apply -f "$NODEPOOL_MANIFEST" --context "$CLUSTER_NAME"; then
    print_success "NodePool applied successfully"
else
    print_error "Failed to apply NodePool"
    exit 1
fi

#============================================================
# Verify Resources
#============================================================
print_header "Verifying Karpenter Resources"

echo ""
echo "EC2NodeClass:"
kubectl get ec2nodeclass --context "$CLUSTER_NAME" 2>/dev/null || print_warning "No EC2NodeClass resources found"

echo ""
echo "NodePool:"
kubectl get nodepool --context "$CLUSTER_NAME" 2>/dev/null || print_warning "No NodePool resources found"

echo ""
echo "Karpenter Pods:"
kubectl get pods -n karpenter --context "$CLUSTER_NAME" 2>/dev/null || print_warning "Karpenter namespace not found or no pods running"

#============================================================
# Summary
#============================================================
print_header "Summary"

echo ""
print_success "Karpenter manifests applied successfully to $CLUSTER_NAME"
echo ""
echo "Next steps:"
echo "  1. Verify Karpenter controller is running:"
echo "     kubectl get pods -n karpenter --context $CLUSTER_NAME"
echo ""
echo "  2. Check Karpenter logs:"
echo "     kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50 --context $CLUSTER_NAME"
echo ""
echo "  3. Monitor node provisioning:"
echo "     kubectl get nodes -w --context $CLUSTER_NAME"
echo ""
echo "Script completed at: $(date)"
