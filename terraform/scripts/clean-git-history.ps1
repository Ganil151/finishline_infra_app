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

Write-Host "============================================================"
Write-Host "  Clean Git History - Remove Exposed OIDC Thumbprint"
Write-Host "============================================================"
Write-Host ""
Write-Host "WARNING: This will rewrite git history!"
Write-Host ""
Write-Host "BEFORE RUNNING: Edit this script and replace"
Write-Host "<YOUR-EXPOSED-THUMBPRINT> with the actual exposed value"
Write-Host ""
$confirm = Read-Host "Have you updated the THUMBPRINT variable? (y/n)"

if ($confirm -ne 'y') {
    Write-Host "Please edit the script first. Aborted."
    exit 0
}

$repoPath = "C:\Users\ganil\Documents\finishline_infra_app"
$THUMBPRINT = "<YOUR-EXPOSED-THUMBPRINT>"  # <-- REPLACE THIS WITH THE ACTUAL EXPOSED VALUE

Set-Location $repoPath

Write-Host ""
Write-Host "Step 1: Checking for BFG Repo-Cleaner..."
$bfgPath = (Get-Command bfg -ErrorAction SilentlyContinue).Source

# Create temp file with thumbprint replacement
$tempFile = "$env:TEMP\thumbprint-replacement.txt"
"$THUMBPRINT==>REDACTED_OIDC_THUMBPRINT" | Out-File -FilePath $tempFile -Encoding ASCII

if ($null -eq $bfgPath) {
    Write-Host "BFG not found. Downloading BFG Repo-Cleaner..."
    $bfgUrl = "https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar"
    $bfgJar = "$env:TEMP\bfg.jar"
    Invoke-WebRequest -Uri $bfgUrl -OutFile $bfgJar
    Write-Host "BFG downloaded to: $bfgJar"

    Write-Host ""
    Write-Host "Step 2: Running BFG to remove thumbprint from history..."
    java -jar $bfgJar --replace-text $tempFile --no-blob-protection $repoPath

} else {
    Write-Host "Step 2: Running BFG to remove thumbprint from history..."
    bfg --replace-text $tempFile --no-blob-protection $repoPath
}

# Cleanup temp file
Remove-Item $tempFile -Force

Write-Host ""
Write-Host "Step 3: Running git gc to clean up..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

Write-Host ""
Write-Host "Step 4: Verifying thumbprint is removed from history..."
$found = git log -p --all | Select-String $THUMBPRINT
if ($found) {
    Write-Host "WARNING: Thumbprint still found in history!" -ForegroundColor Red
} else {
    Write-Host "✓ Thumbprint successfully removed from history" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================================"
Write-Host "  NEXT STEPS (REQUIRED)"
Write-Host "============================================================"
Write-Host ""
Write-Host "1. Force push to origin:"
Write-Host "   git push --force --with-branches"
Write-Host ""
Write-Host "2. All collaborators must re-clone:"
Write-Host "   git clone <repository-url>"
Write-Host ""
Write-Host "3. Verify the current file is correct:"
Write-Host "   cat terraform/environments/dev/terragrunt.hcl | grep oidc_thumbprint"
Write-Host ""
