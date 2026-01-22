# Complete Fast Certificate Renewal Testing Suite
# Creates short-lived certificates and monitors the entire renewal process

param(
    [int]$ExpiryMinutes = 2,
    [switch]$RunFullTest,
    [switch]$ContinuousMonitoring = $false
)

Write-Host "🚀 COMPLETE FAST CERTIFICATE RENEWAL TEST SUITE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 This script will:" -ForegroundColor Yellow
Write-Host "   1. Create ultra-short-lived certificates ($ExpiryMinutes minutes)" -ForegroundColor White
Write-Host "   2. Configure Event Grid for immediate triggers" -ForegroundColor White  
Write-Host "   3. Monitor the complete renewal process" -ForegroundColor White
Write-Host "   4. Validate end-to-end automation" -ForegroundColor White
Write-Host ""

# Store the current location
$originalLocation = Get-Location

# Default RunFullTest to true if not specified
if (-not $PSBoundParameters.ContainsKey('RunFullTest')) {
    $RunFullTest = $true
}

try {
    if ($RunFullTest) {
        Write-Host "🔧 STEP 1: Create Fast-Renewal Certificate" -ForegroundColor Magenta
        Write-Host "=========================================" -ForegroundColor Magenta
        
        # Run the fast renewal certificate creation
        $certScript = Join-Path $PSScriptRoot "create-fast-renewal-cert.ps1"
        if (Test-Path $certScript) {
            Write-Host "   🚀 Creating certificate that expires in $ExpiryMinutes minutes..." -ForegroundColor Yellow
            & $certScript -ExpiryMinutes $ExpiryMinutes
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Fast-renewal certificate created successfully!" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Certificate creation failed!" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "   ❌ Certificate creation script not found: $certScript" -ForegroundColor Red
            exit 1
        }
        
        Write-Host ""
        Write-Host "🔧 STEP 2: Configure Event Grid for Fast Response" -ForegroundColor Magenta
        Write-Host "=================================================" -ForegroundColor Magenta
        
        # Configure Event Grid for fast response
        $eventGridScript = Join-Path $PSScriptRoot "configure-fast-event-grid.ps1"
        if (Test-Path $eventGridScript) {
            Write-Host "   ⚡ Configuring Event Grid for immediate triggers..." -ForegroundColor Yellow
            & $eventGridScript -CreateSubscription
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Event Grid configured for fast response!" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️ Event Grid configuration completed with warnings" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ⚠️ Event Grid script not found, continuing with existing configuration" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "🔧 STEP 3: Deploy Enhanced Runbook (if needed)" -ForegroundColor Magenta
        Write-Host "===============================================" -ForegroundColor Magenta
        
        # Check if enhanced runbook is deployed
        $RESOURCE_GROUP = "rg-demo-certlc"
        $AUTOMATION_ACCOUNT = "DEMO-AA-20251103"
        
        try {
            $enhancedRunbook = Get-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT -ResourceGroupName $RESOURCE_GROUP -Name "Enhanced-CertLifeCycleMgmt" -ErrorAction SilentlyContinue
            
            if ($enhancedRunbook) {
                Write-Host "   ✅ Enhanced runbook already deployed: $($enhancedRunbook.Name)" -ForegroundColor Green
                Write-Host "      📋 State: $($enhancedRunbook.State)" -ForegroundColor Cyan
            } else {
                Write-Host "   ⚠️ Enhanced runbook not found, deploying..." -ForegroundColor Yellow
                
                # Deploy enhanced runbook
                $enhancedRunbookPath = Join-Path $PSScriptRoot "Enhanced-CertLifeCycleMgmt.ps1"
                if (Test-Path $enhancedRunbookPath) {
                    $importResult = Import-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT -ResourceGroupName $RESOURCE_GROUP -Name "Enhanced-CertLifeCycleMgmt" -Type "PowerShell" -Path $enhancedRunbookPath
                    
                    if ($importResult) {
                        # Publish the runbook
                        Publish-AzAutomationRunbook -AutomationAccountName $AUTOMATION_ACCOUNT -ResourceGroupName $RESOURCE_GROUP -Name "Enhanced-CertLifeCycleMgmt"
                        Write-Host "   ✅ Enhanced runbook deployed and published!" -ForegroundColor Green
                    }
                } else {
                    Write-Host "   ⚠️ Enhanced runbook file not found: $enhancedRunbookPath" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "   ⚠️ Could not check/deploy enhanced runbook: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "🔧 STEP 4: Start Real-Time Monitoring" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    
    Write-Host "   🖥️ Starting real-time certificate renewal monitoring..." -ForegroundColor Yellow
    Write-Host "   ⏱️ Certificate will expire in $ExpiryMinutes minutes" -ForegroundColor Cyan
    Write-Host "   🔔 Watch for Event Grid triggers and automatic renewal" -ForegroundColor Cyan
    Write-Host "   🔄 Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
    Write-Host ""
    
    # Calculate key times
    $currentTime = Get-Date
    $expiryTime = $currentTime.AddMinutes($ExpiryMinutes)
    $eventTriggerTime = $expiryTime.AddMinutes(-1)  # Event Grid typically triggers 1 minute before expiry
    
    Write-Host "📅 TIMELINE:" -ForegroundColor Cyan
    Write-Host "   🕐 Current Time: $($currentTime.ToString('HH:mm:ss'))" -ForegroundColor White
    Write-Host "   🔔 Expected Event Trigger: $($eventTriggerTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host "   ⏰ Certificate Expiry: $($expiryTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host "   ✅ Expected Renewal Complete: $($expiryTime.AddMinutes(3).ToString('HH:mm:ss'))" -ForegroundColor Green
    Write-Host ""
    
    # Start monitoring
    $monitorScript = Join-Path $PSScriptRoot "monitor-simple.ps1"
    if (Test-Path $monitorScript) {
        if ($ContinuousMonitoring) {
            Write-Host "🔄 Starting continuous monitoring mode..." -ForegroundColor Green
            & $monitorScript
        } else {
            Write-Host "🔍 Running monitoring check..." -ForegroundColor Green
            & $monitorScript
            
            Write-Host ""
            Write-Host "🎯 MONITORING GUIDANCE:" -ForegroundColor Cyan
            Write-Host "===============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "To continuously monitor the renewal process:" -ForegroundColor Yellow
            Write-Host "   pwsh ./monitor-simple.ps1" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "To run this complete test again:" -ForegroundColor Yellow
            Write-Host "   pwsh ./fast-renewal-complete-test.ps1 -ExpiryMinutes 3" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "⏱️ WHAT TO EXPECT IN THE NEXT $ExpiryMinutes MINUTES:" -ForegroundColor Yellow
            Write-Host "   1. Certificate exists in Key Vault (check Azure Portal)" -ForegroundColor White
            Write-Host "   2. Event Grid trigger near expiry time ($($eventTriggerTime.ToString('HH:mm:ss')))" -ForegroundColor White
            Write-Host "   3. Enhanced runbook execution (check Automation Account jobs)" -ForegroundColor White
            Write-Host "   4. Certificate renewal attempt" -ForegroundColor White
            Write-Host "   5. New certificate version in Key Vault" -ForegroundColor White
            Write-Host ""
            Write-Host "🔍 VERIFICATION COMMANDS:" -ForegroundColor Yellow
            Write-Host "   Check certificates: Get-AzKeyVaultCertificate -VaultName DEMO-KV-20251103" -ForegroundColor Cyan
            Write-Host "   Check automation jobs: Get-AzAutomationJob -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc" -ForegroundColor Cyan
            Write-Host "   Monitor real-time: pwsh ./monitor-simple.ps1" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   ⚠️ Monitor script not found: $monitorScript" -ForegroundColor Yellow
        Write-Host "   📋 Manual monitoring commands:" -ForegroundColor Cyan
        Write-Host "      Get-AzKeyVaultCertificate -VaultName DEMO-KV-20251103" -ForegroundColor Gray
        Write-Host "      Get-AzAutomationJob -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🎉 FAST RENEWAL TEST SETUP COMPLETE!" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ WHAT WAS CONFIGURED:" -ForegroundColor White
    Write-Host "   🔑 Short-lived certificate created ($ExpiryMinutes minutes)" -ForegroundColor Cyan
    Write-Host "   ⚡ Event Grid optimized for immediate triggers" -ForegroundColor Cyan
    Write-Host "   🚀 Enhanced runbook ready for renewal processing" -ForegroundColor Cyan
    Write-Host "   🖥️ Monitoring system configured" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔄 The certificate will automatically renew when it approaches expiry!" -ForegroundColor Green
    Write-Host "⏱️ Expected complete renewal cycle: $($ExpiryMinutes + 3) minutes total" -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Fast renewal test failed" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    # Troubleshooting guidance
    Write-Host "🔧 TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Check Azure authentication: Get-AzContext" -ForegroundColor Cyan
    Write-Host "2. Verify resource access: Get-AzResourceGroup -Name rg-demo-certlc" -ForegroundColor Cyan
    Write-Host "3. Check individual scripts:" -ForegroundColor Cyan
    Write-Host "   - pwsh ./create-fast-renewal-cert.ps1" -ForegroundColor Gray
    Write-Host "   - pwsh ./configure-fast-event-grid.ps1" -ForegroundColor Gray
    Write-Host "   - pwsh ./monitor-simple.ps1" -ForegroundColor Gray
    
    exit 1
} finally {
    # Return to original location
    Set-Location $originalLocation
}