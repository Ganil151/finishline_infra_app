#!/bin/bash
#============================================================
#  Clean Git History to Remove Exposed OIDC Thumbprint
#============================================================
# This script removes the exposed OIDC thumbprint from git history
# by rewriting the commit that introduced it.
#
# IMPORTANT: This rewrites git history. After running:
# 1. Force push to origin: git push --force --with-branches
# 2. All collaborators must re-clone the repository
#
# NOTE: You must replace <YOUR-EXPOSED-THUMBPRINT> with the actual value
# that was exposed in your repository
#============================================================

set -e

REPO_PATH="C:\Users\ganil\Documents\finishline_infra_app"
THUMBPRINT="<YOUR-EXPOSED-THUMBPRINT>"  # <-- REPLACE THIS WITH THE ACTUAL EXPOSED VALUE

echo "============================================================"
echo "  Clean Git History - Remove Exposed OIDC Thumbprint"
echo "============================================================"
echo ""
echo "WARNING: This will rewrite git history!"
echo ""
echo "After running this script, you MUST:"
echo "  1. Force push to origin: git push --force --with-branches"
echo "  2. All collaborators must re-clone the repository"
echo ""
read -p "Do you want to continue? (y/n) " confirm

if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

cd "$REPO_PATH"

echo ""
echo "Step 1: Checking for BFG Repo-Cleaner..."
if command -v bfg &> /dev/null; then
    echo "BFG found. Running..."
    echo "$THUMBPRINT==>REDACTED_OIDC_THUMBPRINT" > /tmp/passwords.txt
    bfg --replace-text /tmp/passwords.txt --no-blob-protection .
    rm /tmp/passwords.txt
else
    echo "BFG not found. Using git filter-branch..."
    echo ""
    echo "Installing BFG is recommended. Download from:"
    echo "https://rtyley.github.io/bfg-repo-cleaner/"
    echo ""
    echo "Alternatively, using git filter-branch (slower)..."
    
    # Create a filter to replace the thumbprint
    # Note: The thumbprint must be passed via the THUMBPRINT variable
    git filter-branch --force --tree-filter "
        if [ -f \"terraform/environments/dev/terragrunt.hcl\" ]; then
            sed -i.bak \"s/\$THUMBPRINT/REDACTED_OIDC_THUMBPRINT/g\" terraform/environments/dev/terragrunt.hcl 2>/dev/null || true
            rm -f terraform/environments/dev/terragrunt.hcl.bak 2>/dev/null || true
        fi
    " --prune-empty HEAD

    # Cleanup any backup files
    find . -name "*.bak" -type f -delete
fi

echo ""
echo "Step 2: Running git gc to clean up..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "Step 3: Verifying thumbprint is removed from history..."
if git log -p --all | grep -q "$THUMBPRINT"; then
    echo "WARNING: Thumbprint still found in history!"
    exit 1
else
    echo "✓ Thumbprint successfully removed from history"
fi

echo ""
echo "============================================================"
echo "  NEXT STEPS (REQUIRED)"
echo "============================================================"
echo ""
echo "1. Force push to origin:"
echo "   git push --force --with-branches"
echo ""
echo "2. All collaborators must re-clone:"
echo "   git clone <repository-url>"
echo ""
echo "3. Verify the current file is correct:"
echo "   grep oidc_thumbprint terraform/environments/dev/terragrunt.hcl"
echo ""
