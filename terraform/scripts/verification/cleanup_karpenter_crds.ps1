#============================================================
#  Karpenter CRD Cleanup Script
#  Use this to fix "API did not recognize GroupVersionKind" errors
#============================================================
#
# Usage: .\cleanup_karpenter_crds.ps1
#
# This script:
# 1. Checks current CRD versions
# 2. Removes old v1beta1 CRDs if needed
# 3. Forces Helm to reinstall CRDs
#
#============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Karpenter CRD Cleanup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "ERROR: kubectl not found. Please install kubectl and configure kubeconfig." -ForegroundColor Red
    exit 1
}

# Get current cluster context
$context = kubectl config current-context 2>$null
Write-Host "Current K8s Context: $context" -ForegroundColor Yellow
Write-Host ""

#============================================================
# Step 1: Check Current CRD Versions
#============================================================
Write-Host "Step 1: Checking current CRD versions..." -ForegroundColor Green

$ec2NodeClassCRD = kubectl get crd ec2nodeclasses.karpenter.k8s.aws -o json 2>$null
$nodePoolCRD = kubectl get crd nodepools.karpenter.sh -o json 2>$null

if ($ec2NodeClassCRD) {
    Write-Host "  EC2NodeClass CRD found" -ForegroundColor Green
    $versions = ($ec2NodeClassCRD | ConvertFrom-Json).spec.versions | Select-Object -ExpandProperty name
    Write-Host "  Versions: $($versions -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "  EC2NodeClass CRD NOT found" -ForegroundColor Red
}

if ($nodePoolCRD) {
    Write-Host "  NodePool CRD found" -ForegroundColor Green
    $versions = ($nodePoolCRD | ConvertFrom-Json).spec.versions | Select-Object -ExpandProperty name
    Write-Host "  Versions: $($versions -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "  NodePool CRD NOT found" -ForegroundColor Red
}

Write-Host ""

#============================================================
# Step 2: Check Karpenter Helm Release
#============================================================
Write-Host "Step 2: Checking Karpenter Helm release..." -ForegroundColor Green

$helmRelease = helm list -n karpenter 2>$null | Select-String "karpenter"

if ($helmRelease) {
    Write-Host "  Karpenter Helm release found" -ForegroundColor Green
    Write-Host "  $helmRelease" -ForegroundColor Yellow
} else {
    Write-Host "  Karpenter Helm release NOT found" -ForegroundColor Yellow
}

Write-Host ""

#============================================================
# Step 3: Delete Old Kubernetes Manifests (if they exist)
#============================================================
Write-Host "Step 3: Cleaning up old Karpenter manifests..." -ForegroundColor Green

# Delete EC2NodeClass if it exists
kubectl delete EC2NodeClass default --ignore-not-found -n karpenter 2>$null | Out-Null
Write-Host "  Deleted EC2NodeClass/default (if existed)" -ForegroundColor Gray

# Delete NodePool if it exists
kubectl delete NodePool default --ignore-not-found -n karpenter 2>$null | Out-Null
Write-Host "  Deleted NodePool/default (if existed)" -ForegroundColor Gray

Write-Host ""

#============================================================
# Step 4: Force Helm Upgrade (Reinstall CRDs)
#============================================================
Write-Host "Step 4: Force upgrading Karpenter Helm chart..." -ForegroundColor Green
Write-Host "  This will reinstall CRDs with correct v1 API version" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Continue with Helm upgrade? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Aborted. Run 'terragrunt apply' to let Terraform handle it." -ForegroundColor Yellow
    exit 0
}

helm upgrade karpenter oci://public.ecr.aws/karpenter/karpenter `
    --version 1.0.8 `
    --namespace karpenter `
    --install `
    --force `
    --reset-values `
    --set "settings.clusterName=finishline-infra-app-dev-eks" `
    --set "replicas=1" `
    --timeout 10m

Write-Host ""

#============================================================
# Step 5: Verify CRDs
#============================================================
Write-Host "Step 5: Verifying CRDs after upgrade..." -ForegroundColor Green

kubectl wait --for=condition=established crd/ec2nodeclasses.karpenter.k8s.aws --timeout=120s
kubectl wait --for=condition=established crd/nodepools.karpenter.sh --timeout=120s

Write-Host ""
Write-Host "Final CRD status:" -ForegroundColor Green
kubectl get crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh -o custom-columns=NAME:.metadata.name,VERSIONS:.spec.versions[*].name 2>$null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run 'terragrunt plan' to verify the fix" -ForegroundColor Gray
Write-Host "  2. Run 'terragrunt apply' to apply changes" -ForegroundColor Gray
Write-Host ""
