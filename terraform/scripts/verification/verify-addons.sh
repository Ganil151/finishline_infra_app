#!/bin/bash

#============================================================
#  EKS Addons Verification Script
#  FinishLine Infrastructure App
#============================================================
# This script verifies that all EKS addons are properly
# deployed and healthy across all environments.
#
# Usage: ./verify-addons.sh [environment]
#   environment: dev, stage, prod (default: dev)
#============================================================

set -e

# Configuration
ENVIRONMENT="${1:-dev}"
CLUSTER_NAME="finishline-infra-app-${ENVIRONMENT}-eks"
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Addons to verify
ADDONS=("vpc-cni" "coredns" "kube-proxy" "aws-ebs-csi-driver")

# Helper functions
print_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=========================================${NC}"
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

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl is not installed. Kubernetes verification will be skipped."
    KUBECTL_AVAILABLE=false
else
    KUBECTL_AVAILABLE=true
fi

print_header "EKS Addons Verification for: $CLUSTER_NAME"
echo ""

# Verify cluster exists
echo "1. Verifying cluster exists..."
CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" == "NOT_FOUND" ]; then
    print_error "Cluster '$CLUSTER_NAME' not found in region $REGION"
    exit 1
fi

print_success "Cluster status: $CLUSTER_STATUS"
echo ""

# List all addons
echo "2. All EKS Addons:"
ADDON_LIST=$(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'sort(addons)' --output text 2>/dev/null || echo "")

if [ -z "$ADDON_LIST" ]; then
    print_warning "No addons found for cluster '$CLUSTER_NAME'"
else
    for addon in $ADDON_LIST; do
        print_success "Found: $addon"
    done
fi
echo ""

# Check each addon status
print_header "Addon Status & Health"
echo ""

ALL_HEALTHY=true

for addon in "${ADDONS[@]}"; do
    echo -e "${BLUE}=== $addon ===${NC}"
    
    # Check if addon exists
    ADDON_EXISTS=$(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" --query "addons[?@=='$addon']" --output text 2>/dev/null || echo "")
    
    if [ -z "$ADDON_EXISTS" ]; then
        print_warning "Addon not found"
        ALL_HEALTHY=false
        echo ""
        continue
    fi
    
    # Get addon details
    STATUS=$(aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$REGION" --addon-name "$addon" --query 'addon.status' --output text 2>/dev/null || echo "UNKNOWN")
    VERSION=$(aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$REGION" --addon-name "$addon" --query 'addon.addonVersion' --output text 2>/dev/null || echo "N/A")
    ISSUES=$(aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$REGION" --addon-name "$addon" --query 'addon.health.issues' --output json 2>/dev/null || echo "[]")
    
    # Print status
    case $STATUS in
        "ACTIVE")
            print_success "Status: $STATUS"
            ;;
        "CREATING"|"UPDATING"|"DELETING")
            print_warning "Status: $STATUS (in progress)"
            ALL_HEALTHY=false
            ;;
        *)
            print_error "Status: $STATUS"
            ALL_HEALTHY=false
            ;;
    esac
    
    echo "   Version: $VERSION"
    
    # Check health issues
    if [ "$ISSUES" == "[]" ] || [ "$ISSUES" == "null" ]; then
        print_success "Health: No issues"
    else
        print_error "Health Issues detected:"
        echo "$ISSUES" | jq -r '.[] | "     - \(.code): \(.message)"' 2>/dev/null || echo "     $ISSUES"
        ALL_HEALTHY=false
    fi
    
    echo ""
done

# Summary
print_header "Summary"
echo ""

if [ "$ALL_HEALTHY" == true ]; then
    print_success "All addons are healthy and active!"
else
    print_warning "Some addons are not yet healthy. This may be normal if recently deployed."
    echo ""
    echo "Wait a few minutes and run this script again, or check:"
    echo "  aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name <addon-name>"
fi

echo ""

# Kubernetes verification (if kubectl is available)
if [ "$KUBECTL_AVAILABLE" == true ]; then
    print_header "Kubernetes Pod Status (Optional)"
    echo ""
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1
    
    echo ""
    echo "Checking addon pods in kube-system namespace:"
    echo ""
    
    # Check pods for each addon
    echo "VPC CNI Pods:"
    kubectl get pods -n kube-system -l k8s-app=aws-node -o wide 2>/dev/null || print_warning "No VPC CNI pods found"
    echo ""
    
    echo "CoreDNS Pods:"
    kubectl get pods -n kube-system -l k8s-app=coredns -o wide 2>/dev/null || print_warning "No CoreDNS pods found"
    echo ""
    
    echo "Kube-Proxy Pods:"
    kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide 2>/dev/null || print_warning "No kube-proxy pods found"
    echo ""
    
    echo "EBS CSI Controller Pods:"
    kubectl get pods -n kube-system -l app=aws-ebs-csi-controller -o wide 2>/dev/null || print_warning "No EBS CSI controller pods found"
    echo ""
fi

print_header "Verification Complete"
echo ""
echo "Script completed at: $(date)"
echo ""
