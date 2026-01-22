# Testing Script Menu
# Quick reference for which script to run

Write-Host "🧪 Certificate Testing Scripts Menu" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Gray

Write-Host "`n📋 Available Scripts:" -ForegroundColor Yellow

Write-Host "`n1️⃣  verify-config.ps1" -ForegroundColor White
Write-Host "   Purpose: Verify .env configuration loading works" -ForegroundColor Gray
Write-Host "   When: Run first to confirm setup" -ForegroundColor Gray

Write-Host "`n2️⃣  diagnose-dc01-network.ps1" -ForegroundColor White  
Write-Host "   Purpose: Comprehensive network connectivity testing" -ForegroundColor Gray
Write-Host "   When: Run on DC01 if having network/DNS issues" -ForegroundColor Gray

Write-Host "`n3️⃣  test-keyvault-dns.ps1" -ForegroundColor White
Write-Host "   Purpose: Specific Key Vault DNS resolution testing" -ForegroundColor Gray  
Write-Host "   When: Run if Key Vault DNS fails" -ForegroundColor Gray

Write-Host "`n4️⃣  create-shortlived-cert-robust.ps1" -ForegroundColor White
Write-Host "   Purpose: Create 2-minute expiry certificate for testing" -ForegroundColor Gray
Write-Host "   When: Main script for certificate creation testing" -ForegroundColor Gray

Write-Host "`n🛠️  Utility Scripts:" -ForegroundColor Yellow
Write-Host "   • create-expired-cert.ps1 - Create already-expired certificates" -ForegroundColor Gray
Write-Host "   • manual-cert-creation.ps1 - Manual certificate process" -ForegroundColor Gray
Write-Host "   • install-azure-modules-dc01.ps1 - Install Azure modules" -ForegroundColor Gray

Write-Host "`n🎯 Recommended Workflow:" -ForegroundColor Cyan
Write-Host "   1. .\verify-config.ps1" -ForegroundColor Green
Write-Host "   2. If issues on DC01: .\diagnose-dc01-network.ps1" -ForegroundColor Yellow  
Write-Host "   3. If DNS issues: .\test-keyvault-dns.ps1" -ForegroundColor Yellow
Write-Host "   4. .\create-shortlived-cert-robust.ps1" -ForegroundColor Green

Write-Host "`n💡 Pro Tips:" -ForegroundColor Cyan
Write-Host "   • All scripts now use .env configuration automatically" -ForegroundColor White
Write-Host "   • Run verify-config.ps1 first if you're unsure" -ForegroundColor White
Write-Host "   • Network diagnostics help identify DC01 vs local machine differences" -ForegroundColor White
Write-Host "   • Obsolete scripts moved to .\archive\ folder" -ForegroundColor White

Write-Host "`n📂 Current Key Vault (from .env): " -NoNewline -ForegroundColor Gray

try {
    Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force -ErrorAction SilentlyContinue
    $config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env" -ErrorAction SilentlyContinue
    if ($config -and $config['KEY_VAULT_NAME']) {
        Write-Host "$($config['KEY_VAULT_NAME'])" -ForegroundColor Green
    } else {
        Write-Host "Could not load from .env" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error loading config" -ForegroundColor Red
}

Write-Host ""