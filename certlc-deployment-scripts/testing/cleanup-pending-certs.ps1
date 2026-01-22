# Certificate Cleanup Script for Windows
# Removes pending/problematic certificates from Key Vault

param(
    [string]$CertificateNamePattern = "democert*"
)

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$KEY_VAULT_NAME = "DEMO-KV-20251103"

Write-Host "🧹 Key Vault Certificate Cleanup Tool" -ForegroundColor Cyan
Write-Host "🔑 Key Vault: $KEY_VAULT_NAME" -ForegroundColor Yellow
Write-Host "🔍 Pattern: $CertificateNamePattern" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check authentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "❌ Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "1. Listing certificates matching pattern..." -ForegroundColor Yellow
    $certificates = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME | Where-Object { $_.Name -like $CertificateNamePattern }
    
    if ($certificates.Count -eq 0) {
        Write-Host "   ✅ No certificates found matching pattern '$CertificateNamePattern'" -ForegroundColor Green
        return
    }

    Write-Host "   📋 Found $($certificates.Count) certificate(s):" -ForegroundColor White
    foreach ($cert in $certificates) {
        Write-Host "   - $($cert.Name) (Created: $($cert.Created))" -ForegroundColor Gray
    }

    Write-Host ""
    $confirmation = Read-Host "❓ Do you want to delete these certificates? (y/N)"
    
    if ($confirmation -eq "y" -or $confirmation -eq "Y") {
        Write-Host ""
        Write-Host "2. Deleting certificates..." -ForegroundColor Yellow
        
        foreach ($cert in $certificates) {
            try {
                Write-Host "   🗑️ Deleting: $($cert.Name)" -ForegroundColor Yellow
                Remove-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $cert.Name -Force -Confirm:$false
                Write-Host "   ✅ Deleted: $($cert.Name)" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed to delete $($cert.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Write-Host "✅ Cleanup completed!" -ForegroundColor Green
        Write-Host "💡 Wait 30-60 seconds before creating new certificates" -ForegroundColor Yellow
        
    } else {
        Write-Host "❌ Cleanup cancelled by user" -ForegroundColor Yellow
    }

} catch {
    Write-Host ""
    Write-Host "❌ CLEANUP FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}