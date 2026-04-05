#============================================================
#  Store OIDC Thumbprint in AWS SSM Parameter Store
#============================================================
# This script stores the EKS OIDC thumbprint securely in SSM Parameter Store
# Run this BEFORE running terragrunt apply
#
# Usage: .\store-oidc-thumbprint.ps1 -Environment "dev" -Thumbprint "<your-thumbprint>"
#
# Note: The thumbprint is NOT stored in this script. Get it from:
#   aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
# Then fetch the thumbprint from the OIDC provider
#============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,  # Must be provided - no default to prevent accidental exposure
    
    [Parameter(Mandatory = $false)]
    [string]$Region = "us-east-1"
)

$parameterName = "/finishline/$Environment/oidc-thumbprint"

Write-Host "============================================================"
Write-Host "  Storing OIDC Thumbprint in SSM Parameter Store"
Write-Host "============================================================"
Write-Host "  Parameter Name: $parameterName"
Write-Host "  Region: $Region"
Write-Host "  Thumbprint: $Thumbprint"
Write-Host "============================================================"

try {
    # Store the parameter with encryption
    $result = aws ssm put-parameter `
        --name $parameterName `
        --value $Thumbprint `
        --type SecureString `
        --region $Region `
        --overwrite `
        --description "EKS OIDC Provider Thumbprint for $Environment environment"

    Write-Host "✓ Successfully stored OIDC thumbprint in SSM Parameter Store"
    Write-Host "  Parameter ARN: $($result | ConvertFrom-Json).Parameter.ARN"
    Write-Host ""
    Write-Host "You can now run terragrunt apply for the $Environment environment."
    
} catch {
    Write-Host "✗ Error storing parameter: $_" -ForegroundColor Red
    exit 1
}
