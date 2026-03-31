#!/bin/bash
#============================================================
#  Destroy All Environment Resources
#============================================================
# This script destroys all Terragrunt resources in the
# REVERSE dependency order to avoid dependency issues.
#
# Usage:
#   ./destroy-all.sh [-e|--environment ENV]
#   ./destroy-all.sh --all
#
# Environments:
#   dev     - Development environment (default)
#   stage   - Staging environment
#   prod    - Production environment
#   all     - Destroy all environments in reverse order
#
# Examples:
#   ./destroy-all.sh                    # Destroy dev environment (default)
#   ./destroy-all.sh -e stage           # Destroy staging environment
#   ./destroy-all.sh --environment prod # Destroy production
#   ./destroy-all.sh --all              # Destroy all environments
#============================================================

set -euo pipefail

#============================================================
# Configuration
#============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$TERRAFORM_DIR/environments"
ENVIRONMENT="${1:-dev}"
FAILED_ENVIRONMENTS=()
FAILED_MODULES=()
START_TIME=$(date +%s)

# Valid environments
VALID_ENVIRONMENTS=("dev" "stage" "prod")

#============================================================
# Helper Functions
#============================================================

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
    echo ""
}

print_env_header() {
    echo ""
    echo "########################################################"
    echo "#  $1"
    echo "########################################################"
    echo ""
}

cleanup() {
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    if [[ $exit_code -ne 0 ]]; then
        print_header "Destroy Script Failed!"
        log_error "Script terminated after ${duration} seconds"
        if [[ ${#FAILED_ENVIRONMENTS[@]} -gt 0 ]]; then
            log_error "Failed environments:"
            for env in "${FAILED_ENVIRONMENTS[@]}"; do
                log_error "  - $env"
            done
        fi
        if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
            log_error "Failed modules:"
            for module in "${FAILED_MODULES[@]}"; do
                log_error "  - $module"
            done
        fi
        log_error "Exit code: $exit_code"
    else
        if [[ "$ENVIRONMENT" == "all" ]]; then
            print_header "All Environments Destroyed Successfully!"
        else
            print_header "${ENVIRONMENT^} Environment Destroyed Successfully!"
        fi
        log_info "Total execution time: ${duration} seconds"
    fi

    # Return to original directory
    cd "$SCRIPT_DIR" 2>/dev/null || true

    exit $exit_code
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Destroy Terragrunt resources for AWS infrastructure.

OPTIONS:
    -e, --environment ENV   Target environment (dev, stage, prod, all)
                            Default: dev
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Destroy dev environment (default)
    $0 -e stage             # Destroy stage environment
    $0 --environment prod   # Destroy production environment
    $0 --all                # Destroy all environments (prod -> stage -> dev)

WARNING: This will permanently delete all resources!

EOF
    exit 0
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            -a|--all)
                ENVIRONMENT="all"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate environment
    if [[ ! " ${VALID_ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]] && [[ "$ENVIRONMENT" != "all" ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        log_error "Valid environments: ${VALID_ENVIRONMENTS[*]}, all"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        log_error "Terragrunt is not installed or not in PATH"
        exit 1
    fi

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi

    # Check AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi

    # Check if environments directory exists
    if [[ ! -d "$ENV_DIR" ]]; then
        log_error "Environments directory not found: $ENV_DIR"
        exit 1
    fi

    log_info "All prerequisites checked successfully"
    log_info "AWS Account: $(aws sts get-caller-identity --query 'Account' --output text)"
    log_info "AWS Region: $(aws configure get region)"

    if [[ "$ENVIRONMENT" == "all" ]]; then
        log_info "Target: All Environments (prod -> stage -> dev)"
    else
        log_info "Target: ${ENVIRONMENT^} Environment"
    fi
    
    log_warn "WARNING: This will PERMANENTLY DELETE all resources!"
}

# Helper function to check if a module directory exists
module_exists() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -f "$dir/terragrunt.hcl" ]]
}

# Function to run terragrunt destroy in a directory with error handling
run_terragrunt_destroy() {
    local dir="$1"
    local module="$2"
    local step="$3"
    local max_retries=2
    local retry_count=0

    echo ""
    log_info "Step $step: Destroying $module..."
    echo ">>> Module path: $dir"

    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        log_warn "Module directory not found: $dir (skipping)"
        return 0
    fi

    # Check if terragrunt.hcl exists
    if [[ ! -f "$dir/terragrunt.hcl" ]]; then
        log_warn "terragrunt.hcl not found in: $dir (skipping)"
        return 0
    fi

    cd "$dir"

    # Retry logic for transient errors
    while [[ $retry_count -le $max_retries ]]; do
        if [[ $retry_count -gt 0 ]]; then
            log_warn "Retry attempt $retry_count of $max_retries for $module..."
        fi

        # Run terragrunt destroy with auto-approve flag and capture output
        local output
        if output=$(terragrunt destroy -auto-approve --terragrunt-non-interactive 2>&1); then
            log_info "✓ $module destroyed successfully"
            return 0
        else
            local exit_code=$?
            log_error "✗ $module failed with exit code: $exit_code"
            
            # Show last 20 lines of error output for debugging
            log_error "Error output (last 20 lines):"
            echo "$output" | tail -20 | sed 's/^/    /'
            
            # Check for specific known errors that might benefit from retry
            if echo "$output" | grep -q "RequestLimitExceeded\|Throttling\|TooManyRequests"; then
                log_warn "AWS throttling detected, will retry..."
                retry_count=$((retry_count+1))
                sleep 5
                continue
            fi
            
            # Check for dependency errors that won't benefit from retry
            if echo "$output" | grep -q "dependency.*not found\|ResourceReferenceError"; then
                log_error "Dependency error detected, skipping retries"
                FAILED_MODULES+=("$module")
                return 1
            fi
            
            # For other errors, don't retry
            FAILED_MODULES+=("$module")
            return 1
        fi
    done

    # All retries exhausted
    log_error "✗ $module failed after $max_retries retries"
    FAILED_MODULES+=("$module")
    return 1
}

# Destroy modules for a specific environment (in reverse order)
destroy_environment() {
    local env="$1"
    local env_dir="$ENV_DIR/$env"

    # Check if environment directory exists
    if [[ ! -d "$env_dir" ]]; then
        log_error "Environment directory not found: $env_dir"
        FAILED_ENVIRONMENTS+=("$env")
        return 1
    fi

    print_env_header "Destroying ${env^} Environment"
    log_info "Environment: $env"

    # Reset failed modules for this environment
    FAILED_MODULES=()

    #-----------------------------
    # Destroy Order (REVERSE of deployment):
    #-----------------------------
    # 1. Karpenter (must be destroyed first so managed nodes are terminated before EKS goes away)
    # 2. Jumphost (depends on VPC, SG, Key Pair, IAM)
    # 3. EKS (depends on IAM, VPC, SG, KMS)
    # 4. ALB (depends on VPC and SG)
    # 5. Security Groups (depends on VPC)
    # 6. VPC (creates networking foundation)
    # 7. KMS (creates encryption keys for EKS) - only in prod/stage
    # 8. Key Pair (creates SSH key for jumphost)
    # 9. IAM (creates roles - destroyed last)
    #-----------------------------

    local env_failed=0
    local step=1
    local total_steps=9

    # Karpenter first (depends on EKS and IAM)
    run_terragrunt_destroy "$env_dir/compute/karpenter" "Karpenter Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # Jumphost (depends on VPC, SG, Key Pair)
    run_terragrunt_destroy "$env_dir/compute/jumphost" "Jumphost Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # EKS (depends on IAM, VPC, SG, KMS)
    run_terragrunt_destroy "$env_dir/compute/eks" "EKS Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # ALB (depends on VPC and SG)
    run_terragrunt_destroy "$env_dir/networking/alb" "ALB Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # Security Groups (depends on VPC)
    run_terragrunt_destroy "$env_dir/networking/sg" "Security Groups Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # VPC (networking foundation)
    run_terragrunt_destroy "$env_dir/networking/vpc" "VPC Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # KMS (only exists in prod and stage, NOT in dev)
    if module_exists "$env_dir/security/kms"; then
        run_terragrunt_destroy "$env_dir/security/kms" "KMS Module" "$step/$total_steps" || env_failed=1
    else
        log_info "KMS Module not found in $env (expected for dev) - skipping"
    fi
    step=$((step+1))

    # Key Pair
    run_terragrunt_destroy "$env_dir/security/key_pair" "Key Pair Module" "$step/$total_steps" || env_failed=1
    step=$((step+1))

    # IAM (destroyed last - other modules depend on it)
    run_terragrunt_destroy "$env_dir/security/iam" "IAM Module" "$step/$total_steps" || env_failed=1

    # Return to environments directory
    cd "$ENV_DIR"

    if [[ $env_failed -ne 0 ]]; then
        log_error "Environment $env had failures"
        FAILED_ENVIRONMENTS+=("$env")
        return 1
    fi

    log_info "✓ ${env^} environment destroyed successfully"
    return 0
}

#============================================================
# Main Execution
#============================================================

trap cleanup EXIT

# Parse command line arguments
parse_arguments "$@"

print_header "Destroying Terragrunt Resources"

# Check prerequisites
check_prerequisites

# Confirm destruction
echo ""
echo "Attempting to destroy all resources. Bypassing manual confirmation."
confirm="yes"
if [[ "$confirm" != "yes" ]]; then
    log_info "Destruction cancelled by user"
    exit 0
fi

# Change to environments directory
cd "$ENV_DIR"

# Run for the specified environment(s)
if [[ "$ENVIRONMENT" == "all" ]]; then
    # Destroy prod first
    destroy_environment "prod" || true

    # Destroy stage
    destroy_environment "stage" || true

    # Destroy dev last
    destroy_environment "dev" || true

    # Check if any environments failed
    if [[ ${#FAILED_ENVIRONMENTS[@]} -gt 0 ]]; then
        log_warn "Some environments had failures. See errors above."
        exit 1
    fi
else
    # Destroy single environment
    destroy_environment "$ENVIRONMENT" || true

    # Check if any modules failed
    if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
        log_warn "Some modules had failures. See errors above."
        exit 1
    fi
fi

exit 0
