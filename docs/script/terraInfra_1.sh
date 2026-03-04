#!/bin/bash
set -e

# 1. Create the Directory Structure
mkdir -p terraform && cd terraform
mkdir -p modules/{vpc,alb,eks,ec2,bootstrap,security_group} \
         modules/secret/{iam,key_pair} \
         environments/{dev,staging,prod}

# 2. Populate Networking & Compute Modules
touch modules/vpc/{main,variables,output}.tf
touch modules/alb/{main,variables,output}.tf
touch modules/ec2/{main,variables,output}.tf
touch modules/security_group/{main,variables,output}.tf

# 3. Populate EKS Module (with Addons)
touch modules/eks/{main,variables,output,addons}.tf

# 4. Populate Secret/Security Modules
touch modules/secret/iam/{main,variables,output}.tf
touch modules/secret/key_pair/{main,variables,output}.tf

# 5. Populate Global Bootstrap (Versions only)
touch modules/bootstrap/{versions}.tf

# 6. Populate Environment Folders (Root Modules)
for env in dev staging prod; do
    touch environments/$env/{main,variables,output,backend,providers}.tf
    touch environments/$env/terraform.tfvars
done

echo "✅ Terraform Project Structure Initialized Successfully."
