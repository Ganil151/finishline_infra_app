#!/bin/bash
#===============================================================================
# Jumphost User Data Script - EC2 Optimized (Final Fixed Version)
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="jumphost"
readonly LOG_FILE="/var/log/${SCRIPT_NAME}.log"
readonly SIGNAL_FILE="/var/log/${SCRIPT_NAME}.complete"
export PATH=$PATH:/usr/local/bin

# Root Check & Log Initialization
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Attempting sudo..."
   exec sudo bash "$0" "$@"
fi

touch "${LOG_FILE}"
chmod 644 "${LOG_FILE}"

log_info() { echo -e "\e[32m[INFO]\e[0m $1" | tee -a "${LOG_FILE}"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m $1" | tee -a "${LOG_FILE}"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1" | tee -a "${LOG_FILE}"; }

is_installed() {
    command -v "$1" &>/dev/null
}

set_hostname() {
    local hostname="jumphost"
    log_info "Setting hostname to ${hostname}..."
    hostnamectl set-hostname "${hostname}" 2>/dev/null || hostname "${hostname}"
}

get_instance_id() {
    local token
    token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown"
}

wait_for_network() {
    log_info "Checking network connectivity..."
    local retry=0
    while ! curl -s --head http://www.google.com | grep "200 OK" > /dev/null && [ $retry -lt 12 ]; do
        log_warn "Waiting for network... ($((retry + 1))/12)"
        sleep 10
        retry=$((retry + 1))
    done
}

install_tool() {
    local name="$1"
    local cmd="$2"
    local check="$3"
    
    if is_installed "${check}"; then
        log_info "${name} already installed, skipping."
        return 0
    fi
    
    log_info "Installing ${name}..."
    if eval "${cmd}" >> "${LOG_FILE}" 2>&1; then
        log_info "Successfully installed ${name}"
        return 0
    else
        log_error "Failed to install ${name}"
        return 1
    fi
}

# --- Execution ---
log_info "=============================================="
log_info "Provisioning Instance: $(get_instance_id)"
log_info "=============================================="

set_hostname
wait_for_network

log_info "Installing core dependencies (unzip, tar, openssl)..."
yum install -y -q unzip tar openssl yum-utils

# AWS CLI v2
install_tool "AWS CLI v2" \
    "curl -s 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip' && unzip -q -o /tmp/awscliv2.zip -d /tmp && /tmp/aws/install --update" "aws"

# kubectl
install_tool "kubectl" \
    "curl -sLO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl" "kubectl"

# HELM (Fixed: Direct Binary Installation)
# We pull the latest Linux-amd64 release directly to bypass the shell-script wrapper failure
install_tool "Helm" \
    "curl -sL https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz | tar -xz -C /tmp && mv /tmp/linux-amd64/helm /usr/local/bin/helm && chmod +x /usr/local/bin/helm" "helm"

# eksctl
install_tool "eksctl" \
    "curl -sL 'https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz' | tar xz -C /tmp && mv /tmp/eksctl /usr/local/bin/ && chmod +x /usr/local/bin/eksctl" "eksctl"

# Utils
install_tool "jq" "yum install -y jq" "jq"
install_tool "git" "yum install -y git" "git"
install_tool "pip3" "yum install -y python3-pip" "pip3"

# yq
install_tool "yq" \
    "curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq" "yq"

# Terraform
install_tool "Terraform" \
    "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo && yum install -y terraform" \
    "terraform"

# Terragrunt
install_tool "Terragrunt" \
    "curl -sL \"https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64\" -o /usr/local/bin/terragrunt && chmod +x /usr/local/bin/terragrunt" \
    "terragrunt"

# Docker
if ! is_installed "docker"; then
    log_info "Installing Docker..."
    if grep -q "Amazon Linux release 2023" /etc/system-release; then
        yum install -y docker && systemctl enable --now docker
    else
        amazon-linux-extras install docker -y && systemctl enable --now docker
    fi
    usermod -a -G docker ec2-user || true
fi

# Configure EKS kubeconfig with correct API version
configure_kubeconfig() {
    log_info "Configuring EKS kubeconfig..."
    local cluster_name="finishline-infra-app-dev-eks"
    local region="us-east-1"
    local kubeconfig_dir="/home/ec2-user/.kube"
    local kubeconfig_file="${kubeconfig_dir}/config"
    
    # Create .kube directory
    mkdir -p "${kubeconfig_dir}"
    chown ec2-user:ec2-user "${kubeconfig_dir}"
    
    # Generate kubeconfig
    aws eks update-kubeconfig --name "${cluster_name}" --region "${region}" --kubeconfig "${kubeconfig_file}"
    
    # Fix API version (v1alpha1 is deprecated, use v1beta1)
    if [ -f "${kubeconfig_file}" ]; then
        sed -i 's|client.authentication.k8s.io/v1alpha1|client.authentication.k8s.io/v1beta1|g' "${kubeconfig_file}"
        chown ec2-user:ec2-user "${kubeconfig_file}"
        chmod 600 "${kubeconfig_file}"
        log_info "Kubeconfig configured with correct API version (v1beta1)"
    fi
}

# Run kubeconfig configuration (will fail gracefully if cluster doesn't exist yet)
configure_kubeconfig || log_warn "Kubeconfig configuration skipped (cluster may not exist yet)"

# Final Check
echo "Setup Complete: $(date)" > "${SIGNAL_FILE}"
log_info "=============================================="
log_info "Installation Summary:"
for tool in aws kubectl helm eksctl jq git yq terraform terragrunt docker; do
    if is_installed "$tool"; then
        log_info "  - $tool: INSTALLED ($(which "$tool"))"
    else
        log_error "  - $tool: FAILED"
    fi
done
log_info "=============================================="