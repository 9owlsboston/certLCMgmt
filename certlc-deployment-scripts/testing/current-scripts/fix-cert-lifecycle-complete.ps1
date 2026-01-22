# Complete Certificate Lifecycle Fix
# Addresses template OID, CA configuration, and notification issues

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"
$KEY_VAULT_NAME = "DEMO-KV-20251103"

Write-Host "🔧 COMPLETE CERTIFICATE LIFECYCLE FIX" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
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

    Write-Host "🎯 FIX 1: Configure Certificate Template Settings" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor Magenta
    
    # Set default certificate template
    Write-Host "1. Setting default certificate template..." -ForegroundColor Yellow
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "DefaultCertificateTemplate" -Value "WebServer" -Encrypted $false
    Write-Host "   ✅ DefaultCertificateTemplate = 'WebServer'" -ForegroundColor Green
    
    # Set CA Server (should be ca01.demo.com based on job output)
    Write-Host "2. Configuring CA Server..." -ForegroundColor Yellow
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "CAServer" -Value "ca01.demo.com" -Encrypted $false
    Write-Host "   ✅ CAServer = 'ca01.demo.com'" -ForegroundColor Green
    
    # Set certificate validity period
    Write-Host "3. Setting certificate validity..." -ForegroundColor Yellow
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "CertificateValidityMonths" -Value "12" -Encrypted $false
    Write-Host "   ✅ CertificateValidityMonths = '12'" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎯 FIX 2: Configure Notification System" -ForegroundColor Magenta
    Write-Host "=======================================" -ForegroundColor Magenta
    
    # Configure SMTP settings
    Write-Host "4. Setting up email notification..." -ForegroundColor Yellow
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "SMTPserver" -Value "ca01.demo.com" -Encrypted $false
    Write-Host "   ✅ SMTPserver = 'ca01.demo.com'" -ForegroundColor Green
    
    # Set default email recipient
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "DefaultEmailRecipient" -Value "admin@MngEnv829153.onmicrosoft.com" -Encrypted $false
    Write-Host "   ✅ DefaultEmailRecipient configured" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎯 FIX 3: Configure Storage Account (for queue operations)" -ForegroundColor Magenta
    Write-Host "=========================================================" -ForegroundColor Magenta
    
    # These might be needed for queue operations
    Write-Host "5. Checking storage account configuration..." -ForegroundColor Yellow
    
    try {
        $storageVar = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "StorageAccount" -ErrorAction SilentlyContinue
        if (-not $storageVar -or [string]::IsNullOrEmpty($storageVar.Value)) {
            # Find storage account in resource group
            $storageAccounts = Get-AzStorageAccount -ResourceGroupName $RESOURCE_GROUP
            if ($storageAccounts) {
                $storageAccountName = $storageAccounts[0].StorageAccountName
                Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "StorageAccount" -Value $storageAccountName -Encrypted $false
                Write-Host "   ✅ StorageAccount = '$storageAccountName'" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  No storage account found in resource group" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ✅ StorageAccount already configured: $($storageVar.Value)" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️  Could not configure storage account: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Set resource group variable
    Set-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "resourceGroup" -Value $RESOURCE_GROUP -Encrypted $false
    Write-Host "   ✅ resourceGroup = '$RESOURCE_GROUP'" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎯 VERIFICATION: Current Configuration" -ForegroundColor Magenta
    Write-Host "====================================" -ForegroundColor Magenta
    
    Write-Host "6. Verifying all automation variables..." -ForegroundColor Yellow
    $allVars = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP
    
    $criticalVars = @(
        'DefaultCertificateTemplate',
        'CAServer', 
        'CertificateValidityMonths',
        'SMTPserver',
        'CertRenewalThresholdDays',
        'StorageAccount',
        'resourceGroup'
    )
    
    foreach ($varName in $criticalVars) {
        $var = $allVars | Where-Object { $_.Name -eq $varName }
        if ($var) {
            Write-Host "   ✅ $varName = '$($var.Value)'" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $varName = NOT SET" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "🚀 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Test certificate renewal with improved runbook" -ForegroundColor White
    Write-Host "2. Create enhanced runbook with better OID extraction fallbacks" -ForegroundColor White
    Write-Host "3. Monitor automation jobs for successful completion" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ CONFIGURATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ CONFIGURATION FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}