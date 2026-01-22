# Update Azure Automation Runbook with Enhanced Version
# Replaces the existing CertLifeCycleMgmt runbook with improved logic

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"
$RUNBOOK_NAME = "CertLifeCycleMgmt"
$ENHANCED_RUNBOOK_PATH = "./current-scripts/Enhanced-CertLifeCycleMgmt.ps1"

Write-Host "🚀 UPDATING AZURE AUTOMATION RUNBOOK" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check authentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "Loading Azure modules..." -ForegroundColor Yellow
    Import-Module Az.Automation -Force
    Write-Host "   Azure modules loaded successfully" -ForegroundColor Green
    Write-Host ""

    # Check if enhanced runbook file exists
    if (-not (Test-Path $ENHANCED_RUNBOOK_PATH)) {
        Write-Host "❌ Enhanced runbook file not found: $ENHANCED_RUNBOOK_PATH" -ForegroundColor Red
        return
    }
    
    Write-Host "1. Backing up current runbook..." -ForegroundColor Yellow
    try {
        Export-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name $RUNBOOK_NAME -OutputFolder "./current-scripts" -Force
        Write-Host "   ✅ Current runbook backed up as: ./current-scripts/$RUNBOOK_NAME.ps1" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Backup failed (continuing anyway): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "2. Importing enhanced runbook..." -ForegroundColor Yellow
    
    try {
        # Import the enhanced runbook (this will overwrite the existing one)
        Import-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Path $ENHANCED_RUNBOOK_PATH -Type PowerShell -Name $RUNBOOK_NAME -Force
        Write-Host "   ✅ Enhanced runbook imported successfully" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Runbook import failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "3. Publishing enhanced runbook..." -ForegroundColor Yellow
    
    try {
        Publish-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name $RUNBOOK_NAME
        Write-Host "   ✅ Enhanced runbook published successfully" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Runbook publishing failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "4. Verifying runbook update..." -ForegroundColor Yellow
    
    try {
        $runbook = Get-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name $RUNBOOK_NAME
        Write-Host "   ✅ Runbook verified:" -ForegroundColor Green
        Write-Host "      Name: $($runbook.Name)" -ForegroundColor White
        Write-Host "      State: $($runbook.State)" -ForegroundColor White
        Write-Host "      Last Modified: $($runbook.LastModifiedTime)" -ForegroundColor White
    } catch {
        Write-Host "   ⚠️  Verification failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "5. Testing enhanced automation with new certificate..." -ForegroundColor Yellow
    
    # Create a test certificate to trigger the enhanced workflow
    try {
        $testCertName = "test-enhanced-$(Get-Date -Format 'MMdd-HHmm')"
        Write-Host "   Creating test certificate: $testCertName" -ForegroundColor White
        
        $certPolicy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=$testCertName.contoso.com" -IssuerName "Self" -ValidityInMonths 1
        $certOperation = Add-AzKeyVaultCertificate -VaultName "DEMO-KV-20251103" -Name $testCertName -CertificatePolicy $certPolicy
        
        Write-Host "   ✅ Test certificate created: $testCertName" -ForegroundColor Green
        Write-Host "      This should trigger the enhanced automation workflow" -ForegroundColor White
    } catch {
        Write-Host "   ⚠️  Test certificate creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎉 ENHANCEMENTS SUMMARY:" -ForegroundColor Green
    Write-Host "========================" -ForegroundColor Green
    Write-Host "✅ Enhanced OID extraction with multiple fallbacks" -ForegroundColor White
    Write-Host "✅ Default certificate template support (WebServer)" -ForegroundColor White
    Write-Host "✅ Improved error handling and logging" -ForegroundColor White
    Write-Host "✅ Better email notification with fallbacks" -ForegroundColor White
    Write-Host "✅ Support for both webhook and queue processing" -ForegroundColor White
    Write-Host "✅ Template detection from certificate subject" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 MONITORING:" -ForegroundColor Cyan
    Write-Host "- Check automation jobs for 'Enhanced Certificate Lifecycle Management'" -ForegroundColor White
    Write-Host "- Monitor Key Vault for certificate renewal activity" -ForegroundColor White
    Write-Host "- Watch for detailed logging in job output" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ RUNBOOK UPDATE COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ RUNBOOK UPDATE FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}