#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Reconstructing file structure from tree.txt..."

# 1. Create Root files
touch README.md root.hcl
mkdir -p scripts

# 2. Define the Module Architecture
# Based on [cite: 1, 4, 5]
COMPUTE_MODS=("eks" "jumphost" "karpenter")
NETWORK_MODS=("alb" "sg" "vpc")
SECURITY_MODS=("iam" "key_pair")
ENVIRONMENTS=("dev" "staging" "prod")

# 3. Create Root Modules Directory
# Based on [cite: 4, 5, 6]
echo "📂 Scaffolding modules/..."

for mod in "${COMPUTE_MODS[@]}"; do
    mkdir -p "modules/compute/$mod"
    touch "modules/compute/$mod"/{main,outputs,variables}.tf [cite: 5]
    [[ "$mod" == "eks" ]] && touch "modules/compute/eks/addons.tf" [cite: 4]
done

for mod in "${NETWORK_MODS[@]}"; do
    mkdir -p "modules/networking/$mod"
    touch "modules/networking/$mod"/{main,outputs,variables}.tf [cite: 5]
done

for mod in "${SECURITY_MODS[@]}"; do
    mkdir -p "modules/security/$mod"
    touch "modules/security/$mod"/{main,outputs,variables}.tf [cite: 6]
done

# 4. Create Environments Directory
# Based on [cite: 1, 2, 3]
echo "🌍 Scaffolding environments/..."

for env in "${ENVIRONMENTS[@]}"; do
    echo "  - Building [$env]"
    
    # Compute sub-envs [cite: 1]
    for mod in "${COMPUTE_MODS[@]}"; do
        mkdir -p "environments/$env/compute/$mod"
        touch "environments/$env/compute/$mod/terragrunt.hcl"
    done

    # Networking sub-envs [cite: 1, 4]
    for mod in "${NETWORK_MODS[@]}"; do
        mkdir -p "environments/$env/networking/$mod"
        touch "environments/$env/networking/$mod/terragrunt.hcl" [cite: 4]
    done

    # Security sub-envs [cite: 1, 2, 3]
    for mod in "${SECURITY_MODS[@]}"; do
        mkdir -p "environments/$env/security/$mod"
        touch "environments/$env/security/$mod/terragrunt.hcl" [cite: 2, 3]
    done
done

echo "✅ File structure matched to tree.txt successfully."
