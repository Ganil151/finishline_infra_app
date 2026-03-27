#!/bin/bash
# =============================================================================
# Corrected Terragrunt Structure Initialization Script
# Project: Finish Line 2026 Infrastructure
# Reporter: Ganil Batist Yan
# Timeline: Feb 26, 2026 – March 2, 2026
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"
# Match text.txt root structure (current directory)
PROJECT_ROOT="." 
ENVIRONMENTS=("dev" "stage" "prod")
CATEGORIES=("networking" "compute" "security")

# Modules per category based on text.txt
NETWORKING_MODULES=("vpc" "sg" "alb")
COMPUTE_MODULES=("jumphost" "eks")
# text.txt shows kms in dev and modules, so we include it for all envs for consistency
SECURITY_MODULES=("iam" "key_pair" "kms")

# Union of TF files found in modules directory in text.txt
MODULE_TF_FILES=("main.tf" "variables.tf" "outputs.tf" "locals.tf" "data.tf" "addons.tf" "security_group.tf")
TG_FILE="terragrunt.hcl"
ROOT_HCL="root.hcl"
AWS_REGION="us-east-1"

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Global State
# -----------------------------------------------------------------------------
ORIGINAL_DIR="$(pwd)"
VERBOSE="false"
DRY_RUN="false"
SKIP_GIT="false"
FORCE="false"

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
    cd "$ORIGINAL_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    local msg="$2"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$level" in
        info)    echo -e "${YELLOW}[${ts}] ℹ️  $msg${NC}" ;;
        success) echo -e "${GREEN}[${ts}] ✅ $msg${NC}" ;;
        error)   echo -e "${RED}[${ts}] ❌ $msg${NC}" >&2 ;;
        step)    echo -e "${BLUE}[${ts}] 📍 $msg${NC}" ;;
        debug)   [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[${ts}] 🔍 $msg${NC}" ;;
        warn)    echo -e "${YELLOW}[${ts}] ⚠️  $msg${NC}" ;;
    esac
}

header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-git)
                SKIP_GIT="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
${CYAN}Usage:${NC} $SCRIPT_NAME [OPTIONS]

${CYAN}Options:${NC}
  -v, --verbose     Enable verbose output
  -n, --dry-run     Preview actions without making changes
  --skip-git        Skip Git repository initialization
  -f, --force       Overwrite existing directories
  -h, --help        Show this help message

${CYAN}Example:${NC}
  $SCRIPT_NAME --verbose
  $SCRIPT_NAME --dry-run --skip-git
EOF
}

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
verify_prerequisites() {
    log step "Verifying prerequisites..."
    
    # Check if running in Git Bash on Windows
    if [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"MSYS"* ]]; then
        log warn "Running on Windows (Git Bash). Ensure script has LF line endings."
    fi
    
    # Git check
    if [[ "$SKIP_GIT" != "true" ]]; then
        if ! command -v git &>/dev/null; then
            log warn "Git not found; skipping Git initialization"
            SKIP_GIT="true"
        fi
    fi
    
    log success "Prerequisites verified"
}

# -----------------------------------------------------------------------------
# Directory Creation
# -----------------------------------------------------------------------------
create_directories() {
    header "Creating Directory Structure"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log info "[DRY RUN] Would create directories"
        return
    fi
    
    # Note: PROJECT_ROOT is "." so we create structure in current dir
    cd "$PROJECT_ROOT"
    
    # Environments with component isolation
    for env in "${ENVIRONMENTS[@]}"; do
        # Create Category Directories
        mkdir -p "environments/$env/networking"
        mkdir -p "environments/$env/compute"
        mkdir -p "environments/$env/security"
        
        # Create Module Directories
        for mod in "${NETWORKING_MODULES[@]}"; do
            mkdir -p "environments/$env/networking/$mod"
        done
        for mod in "${COMPUTE_MODULES[@]}"; do
            mkdir -p "environments/$env/compute/$mod"
        done
        for mod in "${SECURITY_MODULES[@]}"; do
            mkdir -p "environments/$env/security/$mod"
        done
    done
    
    # Modules Source Structure
    mkdir -p "modules/networking"
    mkdir -p "modules/compute"
    mkdir -p "modules/security"
    
    for mod in "${NETWORKING_MODULES[@]}"; do
        mkdir -p "modules/networking/$mod"
    done
    for mod in "${COMPUTE_MODULES[@]}"; do
        mkdir -p "modules/compute/$mod"
    done
    for mod in "${SECURITY_MODULES[@]}"; do
        mkdir -p "modules/security/$mod"
    done
    
    # Scripts
    mkdir -p "scripts"
    
    log success "Directory structure created"
}

# -----------------------------------------------------------------------------
# File Creation
# -----------------------------------------------------------------------------
create_empty_files() {
    header "Creating Empty Placeholder Files"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log info "[DRY RUN] Would create empty files"
        return
    fi
    
    cd "$PROJECT_ROOT"
    
    # Root configuration
    touch "$ROOT_HCL"
    
    # Environment specific files (dev only for pem)
    touch "environments/dev/finishline-infra-app-dev-key.pem"
    
    # Environment component configs
    for env in "${ENVIRONMENTS[@]}"; do
        # Category level terragrunt.hcl (e.g., environments/dev/compute/terragrunt.hcl)
        touch "environments/$env/networking/$TG_FILE"
        touch "environments/$env/compute/$TG_FILE"
        touch "environments/$env/security/$TG_FILE"
        
        # Module level terragrunt.hcl
        for mod in "${NETWORKING_MODULES[@]}"; do
            touch "environments/$env/networking/$mod/$TG_FILE"
        done
        for mod in "${COMPUTE_MODULES[@]}"; do
            touch "environments/$env/compute/$mod/$TG_FILE"
        done
        for mod in "${SECURITY_MODULES[@]}"; do
            touch "environments/$env/security/$mod/$TG_FILE"
        done
    done
    
    # Module Source Files (.tf and READMEs)
    # Networking Modules
    for mod in "${NETWORKING_MODULES[@]}"; do
        for tf_file in "${MODULE_TF_FILES[@]}"; do
            touch "modules/networking/$mod/$tf_file"
        done
    done
    # Networking Category README
    touch "modules/networking/README.md"
    
    # Compute Modules
    for mod in "${COMPUTE_MODULES[@]}"; do
        for tf_file in "${MODULE_TF_FILES[@]}"; do
            touch "modules/compute/$mod/$tf_file"
        done
        # Compute Module READMEs (seen in eks, jumphost)
        touch "modules/compute/$mod/README.md"
    done
    
    # Security Modules
    for mod in "${SECURITY_MODULES[@]}"; do
        for tf_file in "${MODULE_TF_FILES[@]}"; do
            touch "modules/security/$mod/$tf_file"
        done
        # Security Module READMEs (seen in iam)
        if [[ "$mod" == "iam" ]]; then
            touch "modules/security/$mod/README.md"
        fi
    done
    # Security Category README
    touch "modules/security/README.md"
    
    log success "Empty placeholder files created"
}

# -----------------------------------------------------------------------------
# Git Initialization
# -----------------------------------------------------------------------------
init_git() {
    if [[ "$SKIP_GIT" == "true" ]]; then
        log info "Skipping Git initialization"
        return
    fi
    
    header "Initializing Git Repository"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log info "[DRY RUN] Would initialize Git"
        return
    fi
    
    cd "$ORIGINAL_DIR"
    
    if [[ ! -d ".git" ]]; then
        git init
        log success "Git repository initialized"
    fi
    
    # .gitignore updated to match artifacts seen in text.txt
    cat > ".gitignore" << 'EOF'
### Terraform ###
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data, such as
# password, private keys, and other secrets. These should not be part of version
# control as they are data points which are potentially sensitive and subject
# to change depending on the environment.
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally and so
# are not checked in
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negated pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
# example: *tfplan*
*tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc

### Terragrunt ###
# terragrunt cache directories
**/.terragrunt-cache/*

# Terragrunt debug output file (when using `--terragrunt-debug` option)
# See: https://terragrunt.gruntwork.io/docs/reference/cli-options/#terragrunt-debug
terragrunt-debug.tfvars.json

# End of https://www.toptal.com/developers/gitignore/api/terraform,terragrunt
EOF
    log success ".gitignore created"
    
    # Initial commit
    if git ls-files --others --exclude-standard | grep -q .; then
        git add . 2>/dev/null || true
        git commit -m "chore: Initialize Terragrunt structure" 2>/dev/null || true
        log success "Initial commit created"
    fi
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
print_summary() {
    header "Initialization Complete"
    
    cat << EOF
${GREEN}✅ Structure Created Successfully${NC}

${CYAN}Next Steps:${NC}
1. Edit $ROOT_HCL with your remote backend configuration
2. cd environments/dev && terragrunt run-all plan
3. Edit terragrunt.hcl files with your configuration

${CYAN}Structure:${NC}
  .
  ├── $ROOT_HCL
  ├── environments/{dev,stage,prod}/
  ├── modules/{networking,compute,security}/
  └── scripts/

---
Reporter: Ganil Batist Yan
EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    header "Finish Line 2026 - Structure Initialization"
    
    parse_args "$@"
    
    log info "Script: $SCRIPT_NAME"
    log info "Working directory: $ORIGINAL_DIR"
    log info "Options: verbose=$VERBOSE, dry-run=$DRY_RUN, skip-git=$SKIP_GIT, force=$FORCE"
    
    verify_prerequisites
    create_directories
    create_empty_files
    init_git
    print_summary
}

# Execute
main "$@"
