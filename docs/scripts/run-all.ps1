#============================================================
#  Run All Environment Modules (PowerShell)
#============================================================
# This script runs all Terragrunt modules in the correct
# dependency order for the specified environment.
#
# Usage:
#   .\run-all.ps1 [-Environment dev|stage|prod|all] [-Action apply]
#
# Environments:
#   dev     - Development environment (default)
#   stage   - Staging environment
#   prod    - Production environment
#   all     - Run all environments in order (dev -> stage -> prod)
#
# Examples:
#   .\run-all.ps1                     # Plan dev environment (default)
#   .\run-all.ps1 -Action apply       # Apply dev environment
#   .\run-all.ps1 -Environment stage -Action plan    # Plan staging changes
#   .\run-all.ps1 -Environment prod -Action apply     # Apply production
#   .\run-all.ps1 -Environment all -Action destroy    # Destroy all environments
#============================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "stage", "prod", "all")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action = "plan"
)

#============================================================
# Configuration
#============================================================
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Split-Path -Parent $ScriptDir
$EnvDir = Join-Path -Path $TerraformDir -ChildPath "environments"
$FailedEnvironments = @()
$FailedModules = @()
$StartTime = Get-Date

# Valid environments
$ValidEnvironments = @("dev", "stage", "prod")

#============================================================
# Helper Functions
#============================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Print-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Env-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "########################################################" -ForegroundColor Magenta
    Write-Host "#  $Text" -ForegroundColor Magenta
    Write-Host "########################################################" -ForegroundColor Magenta
    Write-Host ""
}

function Show-Usage {
    Write-Host @"
Usage: .\run-all.ps1 [-Environment <env>] [-Action <action>]

Run Terragrunt modules for AWS infrastructure deployment.

OPTIONS:
    -Environment    Target environment (dev, stage, prod, all)
                   Default: dev
    -Action        Terragrunt action (plan, apply, destroy)
                   Default: plan

ENVIRONMENTS:
    dev     - Development environment
    stage   - Staging environment
    prod    - Production environment
    all     - Run all environments in order (dev -> stage -> prod)

EXAMPLES:
    .\run-all.ps1                         # Plan dev environment
    .\run-all.ps1 -Action apply           # Apply dev environment
    .\run-all.ps1 -Environment stage      # Plan stage environment
    .\run-all.ps1 -Environment prod -Action apply   # Apply production
    .\run-all.ps1 -Environment all -Action destroy  # Destroy all environments

"@ -ForegroundColor Cyan
    exit 0
}

function Cleanup {
    param([int]$ExitCode)
    
    $EndTime = Get-Date
    $Duration = New-TimeSpan -Start $StartTime -End $EndTime
    
    if ($ExitCode -ne 0) {
        Print-Header "Script Failed!"
        Write-Error-Custom "Script terminated after $($Duration.TotalSeconds) seconds"
        if ($FailedEnvironments.Count -gt 0) {
            Write-Error-Custom "Failed environments:"
            foreach ($env in $FailedEnvironments) {
                Write-Error-Custom "  - $env"
            }
        }
        if ($FailedModules.Count -gt 0) {
            Write-Error-Custom "Failed modules:"
            foreach ($module in $FailedModules) {
                Write-Error-Custom "  - $module"
            }
        }
        Write-Error-Custom "Exit code: $ExitCode"
    }
    else {
        if ($Environment -eq "all") {
            Print-Header "All Environments completed successfully!"
        }
        else {
            Print-Header "$Environment Environment completed successfully!"
        }
        Write-Info "Total execution time: $($Duration.TotalSeconds) seconds"
    }
    
    # Return to original directory
    Set-Location $ScriptDir -ErrorAction SilentlyContinue
    
    return $ExitCode
}

function Check-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if terragrunt is installed
    if (-not (Get-Command terragrunt -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Terragrunt is not installed or not in PATH"
        Write-Error-Custom "Install terragrunt: https://terragrunt.gruntwork.io/docs/getting-started/install/"
        exit 1
    }
    
    # Check if terraform is installed
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Terraform is not installed or not in PATH"
        Write-Error-Custom "Install terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    }
    
    # Check if AWS CLI is installed
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "AWS CLI is not installed or not in PATH"
        Write-Error-Custom "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $awsIdentity = aws sts get-caller-identity 2>$null
        if (-not $awsIdentity) {
            throw "AWS credentials not configured"
        }
        $awsAccount = ($awsIdentity | ConvertFrom-Json).Account
        Write-Info "AWS Account: $awsAccount"
    }
    catch {
        Write-Error-Custom "AWS credentials not configured or invalid"
        Write-Error-Custom "Run 'aws configure' or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
    }
    
    # Check if environments directory exists
    if (-not (Test-Path $EnvDir)) {
        Write-Error-Custom "Environments directory not found: $EnvDir"
        exit 1
    }
    
    Write-Info "All prerequisites checked successfully"
    Write-Info "Action: $Action"
    
    if ($Environment -eq "all") {
        Write-Info "Target: All Environments (dev -> stage -> prod)"
    }
    else {
        Write-Info "Target: $($Environment.Substring(0,1).ToUpper())$($Environment.Substring(1)) Environment"
    }
}

function Run-Terragrunt {
    param(
        [string]$Dir,
        [string]$Module,
        [string]$Step
    )
    
    Write-Host ""
    Write-Info "Step $Step`: Running $Module..."
    Write-Host ">>> Module path: $Dir"
    
    # Check if directory exists
    if (-not (Test-Path $Dir)) {
        Write-Error-Custom "Module directory not found: $Dir"
        $script:FailedModules += $Module
        return $false
    }
    
    # Check if terragrunt.hcl exists
    if (-not (Test-Path (Join-Path $Dir "terragrunt.hcl"))) {
        Write-Error-Custom "terragrunt.hcl not found in: $Dir"
        $script:FailedModules += $Module
        return $false
    }
    
    Set-Location $Dir
    
    # Run terragrunt with error capture
    try {
        & terragrunt $Action --terragrunt-non-interactive
        Write-Info "✓ $Module completed successfully"
        return $true
    }
    catch {
        Write-Error-Custom "✗ $Module failed"
        $script:FailedModules += $Module
        return $false
    }
}

function Run-Environment {
    param([string]$Env)
    
    $envDir = Join-Path -Path $EnvDir -ChildPath $Env
    
    # Check if environment directory exists
    if (-not (Test-Path $envDir)) {
        Write-Error-Custom "Environment directory not found: $envDir"
        $script:FailedEnvironments += $Env
        return $false
    }
    
    Print-Env-Header "$($Env.Substring(0,1).ToUpper())$($Env.Substring(1)) Environment Deployment"
    Write-Info "Environment: $Env"
    Write-Info "Action: $Action"
    
    # Reset failed modules for this environment
    $script:FailedModules = @()
    
    #-----------------------------
    # Deployment Order:
    #-----------------------------
    # 1. IAM (creates roles needed by EKS)
    # 2. Key Pair (creates SSH key for jumphost)
    # 3. KMS (creates encryption keys for EKS)
    # 4. VPC (creates networking foundation)
    # 5. Security Groups (depends on VPC)
    # 6. ALB (depends on VPC and SG)
    # 7. EKS (depends on IAM, VPC, SG, KMS)
    # 8. Jumphost (depends on VPC, SG, Key Pair, IAM)
    #-----------------------------
    
    $envFailed = $false
    
    if (-not (Run-Terragrunt -Dir "$envDir\security\iam" -Module "IAM Module" -Step "1/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\security\key_pair" -Module "Key Pair Module" -Step "2/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\security\kms" -Module "KMS Module" -Step "3/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\networking\vpc" -Module "VPC Module" -Step "4/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\networking\sg" -Module "Security Groups Module" -Step "5/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\networking\alb" -Module "ALB Module" -Step "6/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\compute\eks" -Module "EKS Module" -Step "7/8")) { $envFailed = $true }
    if (-not (Run-Terragrunt -Dir "$envDir\compute\jumphost" -Module "Jumphost Module" -Step "8/8")) { $envFailed = $true }
    
    # Return to environments directory
    Set-Location $EnvDir
    
    if ($envFailed) {
        Write-Error-Custom "Environment $Env had failures"
        $script:FailedEnvironments += $Env
        return $false
    }
    
    Write-Info "✓ $($Env.Substring(0,1).ToUpper())$($Env.Substring(1)) environment completed successfully"
    return $true
}

#============================================================
# Main Execution
#============================================================

try {
    Print-Header "Running Terragrunt $Action"
    
    # Check prerequisites
    Check-Prerequisites
    
    # Change to environments directory
    Set-Location $EnvDir
    
    # Run for the specified environment(s)
    if ($Environment -eq "all") {
        # Run dev first
        $null = Run-Environment -Env "dev"
        
        # Run stage
        $null = Run-Environment -Env "stage"
        
        # Run prod last
        $null = Run-Environment -Env "prod"
        
        # Check if any environments failed
        if ($FailedEnvironments.Count -gt 0) {
            Write-Warn "Some environments failed. See errors above."
            $exitCode = Cleanup -ExitCode 1
            exit $exitCode
        }
    }
    else {
        # Run single environment
        $null = Run-Environment -Env $Environment
        
        # Check if any modules failed
        if ($FailedModules.Count -gt 0) {
            Write-Warn "Some modules failed. See errors above."
            $exitCode = Cleanup -ExitCode 1
            exit $exitCode
        }
    }
    
    $exitCode = Cleanup -ExitCode 0
    exit $exitCode
}
catch {
    Write-Error-Custom "Unexpected error: $_"
    $exitCode = Cleanup -ExitCode 1
    exit $exitCode
}
