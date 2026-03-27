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
PROJECT_ROOT="terraform"
ENVIRONMENTS=("dev" "stage" "prod")
NETWORKING_MODULES=("vpc" "sg" "alb")
COMPUTE_MODULES=("jumphost" "eks")
SECURITY_MODULES=("iam" "key_pair")
TF_FILES=("main.tf" "variables.tf" "outputs.tf" "locals.tf" "data.tf")
TG_FILE="terragrunt.hcl"
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
# Argument Parsing (FIXED for Windows compatibility)
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
    
    log step "Creating project root: $PROJECT_ROOT/"
    mkdir -p "$PROJECT_ROOT"
    cd "$PROJECT_ROOT"
    
    # Bootstrap
    mkdir -p "bootstrap"
    
    # Environments with component isolation
    for env in "${ENVIRONMENTS[@]}"; do
        mkdir -p "environments/$env/networking/vpc"
        mkdir -p "environments/$env/networking/sg"
        mkdir -p "environments/$env/networking/alb"
        mkdir -p "environments/$env/compute/eks"
        mkdir -p "environments/$env/compute/jumphost"
        mkdir -p "environments/$env/security/iam"
        mkdir -p "environments/$env/security/key_pair"
    done
    
    # Modules
    for mod in "${NETWORKING_MODULES[@]}"; do
        mkdir -p "modules/networking/$mod"
    done
    
    for mod in "${COMPUTE_MODULES[@]}"; do
        mkdir -p "modules/compute/$mod"
    done
    
    for mod in "${SECURITY_MODULES[@]}"; do
        mkdir -p "modules/security/$mod"
    done
    
    mkdir -p "scripts" "docs"
    
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
    
    # Root terragrunt.hcl
    touch "$TG_FILE"
    
    # Bootstrap files
    touch "bootstrap/$TG_FILE"
    for tf_file in "${TF_FILES[@]}"; do
        touch "bootstrap/$tf_file"
    done
    
    # Environment component configs
    for env in "${ENVIRONMENTS[@]}"; do
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
    
    # Module .tf files
    for mod in "${NETWORKING_MODULES[@]}"; do
        for tf_file in "${TF_FILES[@]}"; do
            touch "modules/networking/$mod/$tf_file"
        done
    done
    
    for mod in "${COMPUTE_MODULES[@]}"; do
        for tf_file in "${TF_FILES[@]}"; do
            touch "modules/compute/$mod/$tf_file"
        done
    done
    
    for mod in "${SECURITY_MODULES[@]}"; do
        for tf_file in "${TF_FILES[@]}"; do
            touch "modules/security/$mod/$tf_file"
        done
    done
    
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
    
    # .gitignore
    cat > ".gitignore" << 'EOF'
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
.terragrunt-cache/
*.tfplan
*.pem
*.key
**/jumphost.pem
**/terraform.tfvars
!terraform.tfvars.example
*.log
crash.log
.DS_Store
Thumbs.db
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
1. cd $PROJECT_ROOT/bootstrap && terragrunt init && terragrunt apply
2. cd ../environments/dev && terragrunt run-all plan
3. Edit terragrunt.hcl files with your configuration

${CYAN}Structure:${NC}
  $PROJECT_ROOT/
  ├── terragrunt.hcl
  ├── bootstrap/
  ├── environments/{dev,stage,prod}/
  ├── modules/{networking,compute,security}/
  ├── scripts/
  └── docs/

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