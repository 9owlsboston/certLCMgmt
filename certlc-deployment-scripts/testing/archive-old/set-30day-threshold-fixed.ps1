# Set Renewal Threshold for Immediate Testing
# Forces renewal for certificates within 30 days of expiry

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"

Write-Host "⚙️ Setting Certificate Renewal Threshold for Immediate Testing" -ForegroundColor Cyan
Write-Host "🔧 Automation Account: $AUTOMATION_ACCOUNT_NAME" -ForegroundColor Yellow
Write-Host "🏢 Resource Group: $RESOURCE_GROUP" -ForegroundColor Yellow
Write-Host "⏰ Threshold: 30 days (triggers renewal for December expiry)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check authentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "❌ Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "1. Setting CertRenewalThresholdDays to 30 days..." -ForegroundColor Yellow
    
    # Set the automation variable for 30-day threshold
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "CertRenewalThresholdDays" -Value 30 -Encrypted $false
    Write-Host "   ✅ CertRenewalThresholdDays set to 30 days" -ForegroundColor Green

    Write-Host ""
    Write-Host "2. Verifying threshold setting..." -ForegroundColor Yellow
    $threshold = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "CertRenewalThresholdDays"
    Write-Host "   ✅ Current threshold: $($threshold.Value) days" -ForegroundColor Green

    Write-Host ""
    Write-Host "✅ THRESHOLD CONFIGURATION COMPLETED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 IMMEDIATE TESTING IMPACT:" -ForegroundColor Magenta
    Write-Host "- ALL certificates expiring within 30 days will trigger renewal" -ForegroundColor White
    Write-Host "- December 3rd expiry is within 30 days of today (November 3rd)" -ForegroundColor White
    Write-Host "- Automation should detect and process certificates immediately" -ForegroundColor White
    Write-Host ""
    Write-Host "⏰ EXPECTED TIMELINE:" -ForegroundColor Cyan
    Write-Host "- Event Grid detection: Within 5-10 minutes" -ForegroundColor White
    Write-Host "- Automation job execution: Within 10-15 minutes" -ForegroundColor White
    Write-Host "- Certificate renewal completion: Within 20-30 minutes" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 MONITORING COMMANDS:" -ForegroundColor Yellow
    Write-Host "- Check jobs: Get-AzAutomationJob -AutomationAccountName '$AUTOMATION_ACCOUNT_NAME' -ResourceGroupName '$RESOURCE_GROUP'" -ForegroundColor Gray
    Write-Host "- Check certificates: Get-AzKeyVaultCertificate -VaultName 'DEMO-KV-20251103'" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "❌ THRESHOLD CONFIGURATION FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Script completed successfully!" -ForegroundColor Green