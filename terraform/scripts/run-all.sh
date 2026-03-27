#!/bin/bash
#============================================================
#  Run All Environment Modules
#============================================================
# This script runs all Terragrunt modules in the correct
# dependency order for the specified environment.
#
# Usage:
#   ./run-all.sh [-e|--environment ENV] [plan|apply|destroy]
#   ./run-all.sh --all [plan|apply|destroy]
#
# Environments:
#   dev     - Development environment (default)
#   stage   - Staging environment
#   prod    - Production environment
#   all     - Run all environments in order (dev -> stage -> prod)
#
# Examples:
#   ./run-all.sh                    # Apply dev environment (default)
#   ./run-all.sh -e stage plan      # Plan staging changes
#   ./run-all.sh --environment prod apply   # Apply production
#   ./run-all.sh --all destroy      # Destroy all environments
#============================================================

set -euo pipefail

#============================================================
# Configuration
#============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$TERRAFORM_DIR/environments"
ACTION="${1:-apply}"
ENVIRONMENT="${2:-dev}"
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
        print_header "Script Failed!"
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
            print_header "All Environments completed successfully!"
        else
            print_header "${ENVIRONMENT^} Environment completed successfully!"
        fi
        log_info "Total execution time: ${duration} seconds"
    fi
    
    # Return to original directory
    cd "$SCRIPT_DIR" 2>/dev/null || true
    
    exit $exit_code
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ACTION]

Run Terragrunt modules for AWS infrastructure deployment.

OPTIONS:
    -e, --environment ENV   Target environment (dev, stage, prod, all)
                            Default: dev
    -h, --help              Show this help message

ACTIONS:
    plan    - Show planned changes (default)
    apply   - Apply changes
    destroy - Destroy resources

EXAMPLES:
    $0                    # Plan dev environment (default)
    $0 apply              # Apply dev environment
    $0 -e stage plan      # Plan stage environment
    $0 --environment prod apply   # Apply production
    $0 --all destroy      # Destroy all environments

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
            plan|apply|destroy)
                ACTION="$1"
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
    
    # Validate action
    case "$ACTION" in
        plan|apply|destroy)
            ;;
        *)
            log_error "Invalid action: $ACTION"
            log_error "Valid actions: plan, apply, destroy"
            exit 1
            ;;
    esac
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        log_error "Terragrunt is not installed or not in PATH"
        log_error "Install terragrunt: https://terragrunt.gruntwork.io/docs/getting-started/install/"
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        log_error "Install terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        log_error "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_error "Run 'aws configure' or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
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
    log_info "Action: $ACTION"
    
    if [[ "$ENVIRONMENT" == "all" ]]; then
        log_info "Target: All Environments (dev -> stage -> prod)"
    else
        log_info "Target: ${ENVIRONMENT^} Environment"
    fi
}

# Function to run terragrunt init in a directory
run_terragrunt_init() {
    local dir="$1"
    local module="$2"
    
    echo ""
    log_info "Initializing $module..."
    echo ">>> Module path: $dir"
    
    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        log_error "Module directory not found: $dir"
        return 1
    fi
    
    # Check if terragrunt.hcl exists
    if [[ ! -f "$dir/terragrunt.hcl" ]]; then
        log_error "terragrunt.hcl not found in: $dir"
        return 1
    fi
    
    cd "$dir"
    
    # Run terragrunt init (no non-interactive flag needed for init)
    if terragrunt init; then
        log_info "✓ $module initialized successfully"
        return 0
    else
        local exit_code=$?
        log_error "✗ $module init failed with exit code: $exit_code"
        return 1
    fi
}

# Function to run terragrunt in a directory with error handling
run_terragrunt() {
    local dir="$1"
    local module="$2"
    local step="$3"
    
    echo ""
    log_info "Step $step: Running $module..."
    echo ">>> Module path: $dir"
    
    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
        log_error "Module directory not found: $dir"
        FAILED_MODULES+=("$module")
        return 1
    fi
    
    # Check if terragrunt.hcl exists
    if [[ ! -f "$dir/terragrunt.hcl" ]]; then
        log_error "terragrunt.hcl not found in: $dir"
        FAILED_MODULES+=("$module")
        return 1
    fi
    
    cd "$dir"
    
    # Run terragrunt with error capture
    if terragrunt "$ACTION" --terragrunt-non-interactive; then
        log_info "✓ $module completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "✗ $module failed with exit code: $exit_code"
        FAILED_MODULES+=("$module")
        return 1
    fi
}

# Helper function to check if a module directory exists
module_exists() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -f "$dir/terragrunt.hcl" ]]
}

# Initialize all modules in dependency order
init_environment() {
    local env="$1"
    local env_dir="$ENV_DIR/$env"
    
    print_env_header "Initializing ${env^} Environment"
    log_info "Environment: $env"
    
    #-----------------------------
    # Initialization Order:
    #-----------------------------
    # 1. IAM (creates roles needed by EKS)
    # 2. Key Pair (creates SSH key for jumphost)
    # 3. KMS (creates encryption keys for EKS) - only in prod
    # 4. VPC (creates networking foundation)
    # 5. Security Groups (depends on VPC)
    # 6. ALB (depends on VPC and SG)
    # 7. EKS (depends on IAM, VPC, SG, KMS)
    # 8. Karpenter (depends on EKS)
    # 9. Jumphost (depends on VPC, SG, Key Pair, IAM)
    #-----------------------------
    
    run_terragrunt_init "$env_dir/security/iam" "IAM Module"
    run_terragrunt_init "$env_dir/security/key_pair" "Key Pair Module"
    
    if module_exists "$env_dir/security/kms"; then
        run_terragrunt_init "$env_dir/security/kms" "KMS Module"
    fi
    
    run_terragrunt_init "$env_dir/networking/vpc" "VPC Module"
    run_terragrunt_init "$env_dir/networking/sg" "Security Groups Module"
    run_terragrunt_init "$env_dir/networking/alb" "ALB Module"
    run_terragrunt_init "$env_dir/compute/eks" "EKS Module"
    
    if module_exists "$env_dir/compute/karpenter"; then
        run_terragrunt_init "$env_dir/compute/karpenter" "Karpenter Module"
    fi
    
    if module_exists "$env_dir/compute/jumphost"; then
        run_terragrunt_init "$env_dir/compute/jumphost" "Jumphost Module"
    fi
    
    # Return to environments directory
    cd "$ENV_DIR"
    
    log_info "✓ ${env^} environment initialization completed"
    return 0
}

# Run modules for a specific environment
run_environment() {
    local env="$1"
    local env_dir="$ENV_DIR/$env"
    
    # Check if environment directory exists
    if [[ ! -d "$env_dir" ]]; then
        log_error "Environment directory not found: $env_dir"
        FAILED_ENVIRONMENTS+=("$env")
        return 1
    fi
    
    print_env_header "${env^} Environment Deployment"
    log_info "Environment: $env"
    log_info "Action: $ACTION"
    
    # Reset failed modules for this environment
    FAILED_MODULES=()
    
    #-----------------------------
    # Deployment Order:
    #-----------------------------
    # 1. IAM (creates roles needed by EKS)
    # 2. Key Pair (creates SSH key for jumphost)
    # 3. KMS (creates encryption keys for EKS) - only in prod
    # 4. VPC (creates networking foundation)
    # 5. Security Groups (depends on VPC)
    # 6. ALB (depends on VPC and SG)
    # 7. EKS (depends on IAM, VPC, SG, KMS)
    # 8. Karpenter (depends on EKS)
    # 9. Jumphost (depends on VPC, SG, Key Pair, IAM)
    #-----------------------------
    
    local env_failed=0
    local step=1
    local total_steps=9
    
    run_terragrunt "$env_dir/security/iam" "IAM Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    run_terragrunt "$env_dir/security/key_pair" "Key Pair Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    
    if module_exists "$env_dir/security/kms"; then
        run_terragrunt "$env_dir/security/kms" "KMS Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    else
        step=$((step+1))  # Skip KMS step number
    fi
    
    run_terragrunt "$env_dir/networking/vpc" "VPC Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    run_terragrunt "$env_dir/networking/sg" "Security Groups Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    run_terragrunt "$env_dir/networking/alb" "ALB Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    run_terragrunt "$env_dir/compute/eks" "EKS Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    
    if module_exists "$env_dir/compute/karpenter"; then
        run_terragrunt "$env_dir/compute/karpenter" "Karpenter Module" "$step/$total_steps" && step=$((step+1)) || env_failed=1
    else
        step=$((step+1))  # Skip Karpenter step number
    fi
    
    if module_exists "$env_dir/compute/jumphost"; then
        run_terragrunt "$env_dir/compute/jumphost" "Jumphost Module" "$step/$total_steps" || env_failed=1
    fi
    
    # Return to environments directory
    cd "$ENV_DIR"
    
    if [[ $env_failed -ne 0 ]]; then
        log_error "Environment $env had failures"
        FAILED_ENVIRONMENTS+=("$env")
        return 1
    fi
    
    log_info "✓ ${env^} environment completed successfully"
    return 0
}

#============================================================
# Main Execution
#============================================================

trap cleanup EXIT

# Parse command line arguments
parse_arguments "$@"

print_header "Running Terragrunt $ACTION"

# Check prerequisites
check_prerequisites

# Change to environments directory
cd "$ENV_DIR"

# Run for the specified environment(s)
if [[ "$ENVIRONMENT" == "all" ]]; then
    # Initialize all environments first
    init_environment "dev"
    init_environment "stage"
    init_environment "prod"
    
    # Then run dev first
    run_environment "dev" || true
    
    # Run stage
    run_environment "stage" || true
    
    # Run prod last
    run_environment "prod" || true
    
    # Check if any environments failed
    if [[ ${#FAILED_ENVIRONMENTS[@]} -gt 0 ]]; then
        log_warn "Some environments failed. See errors above."
        exit 1
    fi
else
    # Initialize the target environment first
    init_environment "$ENVIRONMENT"
    
    # Run single environment
    run_environment "$ENVIRONMENT" || true
    
    # Check if any modules failed
    if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
        log_warn "Some modules failed. See errors above."
        exit 1
    fi
fi

exit 0
