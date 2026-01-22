# Certificate Renewal Troubleshooting Script
# Diagnoses why automatic renewal failed

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config) {
    Write-Host "❌ Could not load configuration" -ForegroundColor Red
    exit 1
}

$KeyVaultName = $config['KEY_VAULT_NAME']
$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']
$WorkspaceName = $config['LOG_ANALYTICS_WORKSPACE_NAME']
$EventGridName = $config['EVENT_GRID_NAME']
$CertificateName = "democert-shortlived"

Write-Host "🔍 Certificate Renewal Failure Analysis" -ForegroundColor Red
Write-Host "=======================================" -ForegroundColor Gray
Write-Host "📅 Analysis Time: $(Get-Date)" -ForegroundColor White
Write-Host "🔑 Certificate: $CertificateName" -ForegroundColor White
Write-Host "🏢 Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host ""

# Step 1: Check current certificate status
Write-Host "1. 📋 Checking certificate status..." -ForegroundColor Yellow
try {
    $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction Stop
    $isExpired = $cert.Expires -lt (Get-Date)
    $timeSinceExpiry = if ($isExpired) { (Get-Date) - $cert.Expires } else { $null }
    
    Write-Host "   ✅ Certificate found" -ForegroundColor Green
    Write-Host "   🔑 Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "   ⏰ Expires: $($cert.Expires)" -ForegroundColor Gray
    Write-Host "   📊 Status: $(if ($isExpired) { 'EXPIRED' } else { 'ACTIVE' })" -ForegroundColor $(if ($isExpired) { "Red" } else { "Green" })
    
    if ($isExpired) {
        Write-Host "   ⏳ Expired: $([math]::Round($timeSinceExpiry.TotalMinutes, 1)) minutes ago" -ForegroundColor Red
        Write-Host "   🚨 Renewal should have been triggered!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Certificate not found: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 2: Check Automation Account status
Write-Host "`n2. 🤖 Checking Automation Account..." -ForegroundColor Yellow
try {
    $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction Stop
    Write-Host "   ✅ Automation Account found: $($automationAccount.AutomationAccountName)" -ForegroundColor Green
    Write-Host "   📍 Location: $($automationAccount.Location)" -ForegroundColor Gray
    Write-Host "   📊 Status: $($automationAccount.State)" -ForegroundColor Gray
    
    # Check if automation account is enabled
    if ($automationAccount.State -ne "Ok") {
        Write-Host "   ⚠️  Automation Account state is not 'Ok'" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Cannot access Automation Account: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Check CertLifeCycleMgmt runbook
Write-Host "`n3. 📜 Checking CertLifeCycleMgmt runbook..." -ForegroundColor Yellow
try {
    $runbook = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "CertLifeCycleMgmt" -ErrorAction Stop
    Write-Host "   ✅ Runbook found: $($runbook.RunbookName)" -ForegroundColor Green
    Write-Host "   📊 Status: $($runbook.State)" -ForegroundColor Gray
    Write-Host "   📝 Type: $($runbook.RunbookType)" -ForegroundColor Gray
    
    if ($runbook.State -ne "Published") {
        Write-Host "   ⚠️  Runbook is not in 'Published' state" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ CertLifeCycleMgmt runbook not found: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   💡 This could be why renewal didn't happen!" -ForegroundColor Yellow
}

# Step 4: Check recent automation jobs
Write-Host "`n4. 📋 Checking recent automation jobs..." -ForegroundColor Yellow
try {
    $recentJobs = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "CertLifeCycleMgmt" -ErrorAction Stop |
                  Where-Object { $_.StartTime -gt (Get-Date).AddHours(-2) } |
                  Sort-Object StartTime -Descending |
                  Select-Object -First 10
    
    if ($recentJobs) {
        Write-Host "   📊 Found $($recentJobs.Count) recent jobs:" -ForegroundColor Green
        foreach ($job in $recentJobs) {
            $statusColor = switch ($job.Status) {
                "Completed" { "Green" }
                "Running" { "Yellow" }
                "Failed" { "Red" }
                "Stopped" { "Red" }
                default { "Gray" }
            }
            Write-Host "   📋 Job ID: $($job.JobId)" -ForegroundColor Gray
            Write-Host "      Status: $($job.Status) | Started: $($job.StartTime) | Ended: $($job.EndTime)" -ForegroundColor $statusColor
            
            if ($job.Status -eq "Failed") {
                # Get job output for failed jobs
                try {
                    $jobOutput = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -JobId $job.JobId -Stream "Error" -ErrorAction SilentlyContinue
                    if ($jobOutput) {
                        Write-Host "      ❌ Error Output:" -ForegroundColor Red
                        foreach ($output in $jobOutput | Select-Object -First 3) {
                            Write-Host "         $($output.Summary)" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Host "      ⚠️  Could not retrieve error details" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "   ❌ No recent automation jobs found!" -ForegroundColor Red
        Write-Host "   💡 This indicates the automation was never triggered" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Cannot retrieve automation jobs: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Check Event Grid Topic
Write-Host "`n5. 📡 Checking Event Grid configuration..." -ForegroundColor Yellow
try {
    $eventGridTopic = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $EventGridName -ErrorAction Stop
    Write-Host "   ✅ Event Grid Topic found: $($eventGridTopic.TopicName)" -ForegroundColor Green
    Write-Host "   📍 Endpoint: $($eventGridTopic.Endpoint)" -ForegroundColor Gray
    
    # Check Event Grid subscriptions
    try {
        $subscriptions = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName -TopicName $EventGridName -ErrorAction Stop
        if ($subscriptions) {
            Write-Host "   📊 Event subscriptions found: $($subscriptions.Count)" -ForegroundColor Green
            foreach ($sub in $subscriptions) {
                Write-Host "   📋 Subscription: $($sub.EventSubscriptionName)" -ForegroundColor Gray
                Write-Host "      Endpoint: $($sub.Destination.EndpointUrl)" -ForegroundColor Gray
                Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ❌ No Event Grid subscriptions found!" -ForegroundColor Red
            Write-Host "   💡 This could be why automation wasn't triggered" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ⚠️  Could not retrieve Event Grid subscriptions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Event Grid Topic not found: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   💡 This could be why renewal events weren't sent" -ForegroundColor Yellow
}

# Step 6: Check Key Vault Event Grid integration
Write-Host "`n6. 🔗 Checking Key Vault Event Grid integration..." -ForegroundColor Yellow
try {
    # Check if Key Vault has Event Grid integration configured
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "   ✅ Key Vault found: $($keyVault.VaultName)" -ForegroundColor Green
    
    # Check diagnostic settings (where Event Grid events are configured)
    try {
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $keyVault.ResourceId -ErrorAction Stop
        if ($diagnosticSettings) {
            Write-Host "   ✅ Diagnostic settings configured" -ForegroundColor Green
            foreach ($setting in $diagnosticSettings) {
                Write-Host "   📋 Setting: $($setting.Name)" -ForegroundColor Gray
                if ($setting.EventHubName -or $setting.WorkspaceId -or $setting.StorageAccountId) {
                    Write-Host "      Target configured for events" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "   ❌ No diagnostic settings found!" -ForegroundColor Red
            Write-Host "   💡 Key Vault events may not be flowing to Event Grid" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ⚠️  Could not retrieve diagnostic settings: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Cannot access Key Vault: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 7: Check certificate tags (renewal trigger)
Write-Host "`n7. 🏷️  Checking certificate tags..." -ForegroundColor Yellow
try {
    $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction Stop
    if ($cert.Tags -and $cert.Tags.Count -gt 0) {
        Write-Host "   ✅ Certificate has tags:" -ForegroundColor Green
        foreach ($tag in $cert.Tags.GetEnumerator()) {
            Write-Host "   🏷️  $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
        
        if ($cert.Tags.ContainsKey("recipient")) {
            Write-Host "   ✅ 'recipient' tag found - automation should trigger" -ForegroundColor Green
        } else {
            Write-Host "   ❌ 'recipient' tag missing!" -ForegroundColor Red
            Write-Host "   💡 Automation may require this tag to process renewals" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Certificate has no tags!" -ForegroundColor Red
        Write-Host "   💡 Tags may be required for automation to process this certificate" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Cannot retrieve certificate tags: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary and recommendations
Write-Host "`n🔧 DIAGNOSIS SUMMARY & RECOMMENDATIONS:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Gray

Write-Host "`n🎯 Most Likely Issues:" -ForegroundColor Yellow

$issues = @()

# Check for common issues
if (-not $recentJobs) {
    $issues += "❌ No automation jobs triggered - Event Grid integration problem"
}

Write-Host "`n💡 Troubleshooting Steps:" -ForegroundColor Yellow
Write-Host "1. Manual trigger test:" -ForegroundColor White
Write-Host "   Start-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name 'CertLifeCycleMgmt'" -ForegroundColor Gray

Write-Host "`n2. Check Event Grid manually:" -ForegroundColor White
Write-Host "   # Go to Azure Portal → Event Grid Topics → $EventGridName" -ForegroundColor Gray
Write-Host "   # Check Metrics for 'Published Events' and 'Delivered Events'" -ForegroundColor Gray

Write-Host "`n3. Check Key Vault Activity Log:" -ForegroundColor White
Write-Host "   # Go to Azure Portal → Key Vault → $KeyVaultName → Activity log" -ForegroundColor Gray
Write-Host "   # Look for certificate expiry events" -ForegroundColor Gray

Write-Host "`n4. Verify webhook endpoint:" -ForegroundColor White
Write-Host "   # Check if Automation Account webhook is correctly configured in Event Grid" -ForegroundColor Gray

Write-Host "`n5. Test certificate renewal manually:" -ForegroundColor White
Write-Host "   # Run the CertLifeCycleMgmt runbook manually to see if it works" -ForegroundColor Gray

Write-Host "`n🚀 Quick Fix Attempts:" -ForegroundColor Cyan
Write-Host "Would you like me to:" -ForegroundColor White
Write-Host "1. Try to manually trigger the runbook" -ForegroundColor Gray
Write-Host "2. Create a new test certificate with proper configuration" -ForegroundColor Gray
Write-Host "3. Check and fix Event Grid subscriptions" -ForegroundColor Gray
Write-Host "4. Verify all required tags are present" -ForegroundColor Gray