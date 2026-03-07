#!/bin/bash

# =============================================================================
# Script to fix Terraform import issues for existing resources
# =============================================================================

# Set the working directory
cd "$(dirname "$0")"

echo "=========================================="
echo "Fixing Terraform Import Issues"
echo "=========================================="

# Check if user has AWS credentials
echo ""
echo "Step 1: Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi
echo "AWS credentials OK"

# Get the VPC ID from the error message
VPC_ID="vpc-0a22611916abc579e"
SG_NAME="finishline_sg_finishline-infra"
KEY_NAME="finishline-key-pair"

# Find the Security Group ID
echo ""
echo "Step 2: Finding Security Group ID..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SG_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null)

if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
    echo "ERROR: Security group '$SG_NAME' not found in VPC '$VPC_ID'"
    echo "Please check if the security group exists in AWS."
    exit 1
fi

echo "Found Security Group ID: $SG_ID"

# Import the Security Group
echo ""
echo "Step 3: Importing Security Group into Terraform state..."
terraform import module.finishline_sg.aws_security_group.finishline_sg "$SG_ID"

if [ $? -eq 0 ]; then
    echo "Security Group imported successfully!"
else
    echo "WARNING: Security Group import may have failed. Check the output above."
fi

# Check if Key Pair exists in AWS
echo ""
echo "Step 4: Checking if Key Pair exists in AWS..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" &>/dev/null; then
    echo "Key Pair '$KEY_NAME' exists in AWS."
    
    # Import the Key Pair (optional - mainly for state management)
    echo ""
    echo "Step 5: Importing Key Pair into Terraform state..."
    # Note: AWS Key Pair cannot be directly imported because it doesn't have a resource ID
    # Instead, we need to handle this differently
    echo "INFO: AWS Key Pairs cannot be imported via Terraform import command."
    echo "      The key pair will be managed as an existing resource."
else
    echo "Key Pair '$KEY_NAME' does NOT exist in AWS."
    echo "Setting create_key_pair = true to create a new one..."
    sed -i 's/create_key_pair = false/create_key_pair = true/' terraform.tfvars
fi

# Remove the old state file if it exists (to start fresh with imported resources)
echo ""
echo "Step 6: Cleaning up old state..."
if [ -f "errored.tfstate" ]; then
    echo "Removing errored.tfstate file..."
    rm -f errored.tfstate
fi

# Remove any old .pem files that might cause permission issues
echo ""
echo "Step 7: Checking PEM file permissions..."
if [ -f "$KEY_NAME.pem" ]; then
    echo "Found existing $KEY_NAME.pem file"
    # Check if we can write to it
    if [ ! -w "." ]; then
        echo "WARNING: Current directory is not writable."
        echo "You may need to run: chmod 700 ."
    fi
fi

echo ""
echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' to verify the configuration"
echo "2. Run 'terraform apply' to apply the changes"
echo ""
echo "NOTE: If you see any resource conflicts, you may need to run:"
echo "      terraform state mv <source> <destination>"
echo "      to move resources to the correct module."
