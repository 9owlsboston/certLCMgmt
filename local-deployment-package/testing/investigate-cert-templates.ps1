# Certificate Template Investigation Script
# Diagnoses certificate template issues and provides comprehensive fix

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"
$KEY_VAULT_NAME = "DEMO-KV-20251103"

Write-Host "🔍 CERTIFICATE TEMPLATE INVESTIGATION" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check authentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "1. Analyzing existing certificates in Key Vault..." -ForegroundColor Yellow
    $certificates = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME
    
    Write-Host "   Found $($certificates.Count) certificates:" -ForegroundColor Green
    foreach ($cert in $certificates) {
        Write-Host "   - $($cert.Name) | Created: $($cert.Created.ToString('MM/dd HH:mm'))" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "2. Examining certificate extensions for template information..." -ForegroundColor Yellow
    
    foreach ($cert in $certificates | Select-Object -First 3) {
        Write-Host "   📜 Certificate: $($cert.Name)" -ForegroundColor Cyan
        
        $fullCert = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $cert.Name
        $certObj = $fullCert.Certificate
        
        Write-Host "     Subject: $($certObj.Subject)" -ForegroundColor White
        Write-Host "     Issuer: $($certObj.Issuer)" -ForegroundColor White
        Write-Host "     Extensions found: $($certObj.Extensions.Count)" -ForegroundColor White
        
        # Check for certificate template extensions
        $templateExtensions = @()
        foreach ($ext in $certObj.Extensions) {
            if ($ext.Oid.Value -eq "1.3.6.1.4.1.311.20.2" -or $ext.Oid.Value -eq "1.3.6.1.4.1.311.21.7") {
                $templateExtensions += $ext
                Write-Host "     ✅ Template Extension Found: OID $($ext.Oid.Value)" -ForegroundColor Green
                Write-Host "     Raw Data: $($ext.Format(0))" -ForegroundColor Gray
            }
        }
        
        if ($templateExtensions.Count -eq 0) {
            Write-Host "     ❌ No template extensions found" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "3. Checking Automation Account variables..." -ForegroundColor Yellow
    $variables = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP
    
    $relevantVars = $variables | Where-Object { $_.Name -like "*Template*" -or $_.Name -like "*CA*" -or $_.Name -like "*OID*" }
    if ($relevantVars) {
        Write-Host "   Template-related variables:" -ForegroundColor Green
        foreach ($var in $relevantVars) {
            Write-Host "   - $($var.Name): $($var.Value)" -ForegroundColor White
        }
    } else {
        Write-Host "   ❌ No template-related variables found" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "4. Proposed Solutions:" -ForegroundColor Magenta
    Write-Host "   A. Set default certificate template in Automation Variables" -ForegroundColor White
    Write-Host "   B. Enhance OID extraction logic with multiple fallbacks" -ForegroundColor White
    Write-Host "   C. Configure Key Vault certificates with proper template extensions" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🎯 RECOMMENDED IMMEDIATE FIX:" -ForegroundColor Green
    Write-Host "Set default template variable: DefaultCertificateTemplate = 'WebServer'" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Would you like to apply the recommended fix? (Creates default template variable)" -ForegroundColor Cyan
    
} catch {
    Write-Host "Investigation failed: $($_.Exception.Message)" -ForegroundColor Red
}