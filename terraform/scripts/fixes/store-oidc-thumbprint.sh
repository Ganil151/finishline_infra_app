#!/bin/bash
#============================================================
#  Store OIDC Thumbprint in AWS SSM Parameter Store
#============================================================
# This script stores the EKS OIDC thumbprint securely in SSM Parameter Store
# Run this BEFORE running terragrunt apply
#
# Usage: ./store-oidc-thumbprint.sh -e <environment> -t <thumbprint> [-r region]
#
# Note: The thumbprint is NOT stored in this script. Get it from:
#   aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
# Then fetch the thumbprint from the OIDC provider
#============================================================

set -e

# Default values
ENVIRONMENT=""
THUMBPRINT=""  # Must be provided - no default to prevent accidental exposure
REGION="us-east-1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--thumbprint)
            THUMBPRINT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -e <environment> [-t <thumbprint>] [-r <region>]"
            echo ""
            echo "Options:"
            echo "  -e, --environment  Environment name (required)"
            echo "  -t, --thumbprint   OIDC thumbprint (default: AWS EKS default)"
            echo "  -r, --region       AWS region (default: us-east-1)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]]; then
    echo "✗ Error: Environment is required"
    echo "Use -h for help"
    exit 1
fi

PARAMETER_NAME="/finishline/${ENVIRONMENT}/oidc-thumbprint"

echo "============================================================"
echo "  Storing OIDC Thumbprint in SSM Parameter Store"
echo "============================================================"
echo "  Parameter Name: $PARAMETER_NAME"
echo "  Region: $REGION"
echo "  Thumbprint: $THUMBPRINT"
echo "============================================================"

# Store the parameter with encryption
aws ssm put-parameter \
    --name "$PARAMETER_NAME" \
    --value "$THUMBPRINT" \
    --type SecureString \
    --region "$REGION" \
    --overwrite \
    --description "EKS OIDC Provider Thumbprint for ${ENVIRONMENT} environment"

echo "✓ Successfully stored OIDC thumbprint in SSM Parameter Store"
echo ""
echo "You can now run terragrunt apply for the ${ENVIRONMENT} environment."
