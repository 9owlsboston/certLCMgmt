# Diagnose Why Event Grid → Automation Account → Certificate Renewal Chain Failed
# Based on user evidence: Event fired, runbook exists, but no renewal occurred

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config) {
    Write-Host "❌ Could not load configuration" -ForegroundColor Red
    exit 1
}

$KeyVaultName = $config['KEY_VAULT_NAME']
$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME']
$EventGridName = $config['EVENT_GRID_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']
$CertificateName = "democert-shortlived"

Write-Host "🔍 DIAGNOSING AUTOMATION CHAIN FAILURE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray
Write-Host "Evidence from user:" -ForegroundColor Yellow
Write-Host "✅ CertLifeCycleMgmt runbook exists (updated 4:57 PM)" -ForegroundColor Green
Write-Host "✅ Event Grid CertificateNearExpiry event succeeded" -ForegroundColor Green  
Write-Host "✅ Certificate has recipient tag with email" -ForegroundColor Green
Write-Host "❌ Certificate expired without renewal" -ForegroundColor Red
Write-Host ""

# 1. Check Automation Account runbook job history
Write-Host "1. 🔍 Checking Automation Account job history..." -ForegroundColor Yellow
try {
    # Get jobs from the last 2 hours (when certificate expired)
    $since = (Get-Date).AddHours(-2)
    $jobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime $since
    
    if ($jobs) {
        Write-Host "   📋 Recent Automation jobs found:" -ForegroundColor Green
        foreach ($job in $jobs) {
            $status = switch ($job.Status) {
                "Completed" { "✅" }
                "Failed" { "❌" }
                "Running" { "🔄" }
                "Suspended" { "⏸️" }
                default { "❓" }
            }
            Write-Host "   $status $($job.RunbookName) - $($job.Status) - $($job.StartTime)" -ForegroundColor Gray
        }
        
        # Check specifically for CertLifeCycleMgmt jobs
        $certJobs = $jobs | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }
        if ($certJobs) {
            Write-Host "   🎯 CertLifeCycleMgmt jobs found!" -ForegroundColor Green
            foreach ($certJob in $certJobs) {
                Write-Host "      Job ID: $($certJob.JobId)" -ForegroundColor Gray
                Write-Host "      Status: $($certJob.Status)" -ForegroundColor Gray
                Write-Host "      Start: $($certJob.StartTime)" -ForegroundColor Gray
                Write-Host "      End: $($certJob.EndTime)" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ❌ NO CertLifeCycleMgmt jobs found in last 2 hours!" -ForegroundColor Red
            Write-Host "   💡 This means Event Grid event did NOT trigger the runbook" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ No Automation jobs found in last 2 hours" -ForegroundColor Red
        Write-Host "   💡 Event Grid events are not triggering Automation Account" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking Automation jobs: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Check Event Grid Topic and Subscriptions
Write-Host "`n2. 🔍 Checking Event Grid configuration..." -ForegroundColor Yellow
try {
    # Check if Event Grid topic exists
    $eventGridTopic = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $EventGridName -ErrorAction SilentlyContinue
    if ($eventGridTopic) {
        Write-Host "   ✅ Event Grid topic exists: $($eventGridTopic.Name)" -ForegroundColor Green
        Write-Host "   📍 Endpoint: $($eventGridTopic.Endpoint)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Event Grid topic NOT found: $EventGridName" -ForegroundColor Red
    }
    
    # Check Event Grid subscriptions
    $subscriptions = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName
    $kvSubscriptions = $subscriptions | Where-Object { $_.Topic -like "*$KeyVaultName*" -or $_.EventSubscriptionName -like "*cert*" }
    
    if ($kvSubscriptions) {
        Write-Host "   📋 Key Vault Event Grid subscriptions found:" -ForegroundColor Green
        foreach ($sub in $kvSubscriptions) {
            Write-Host "   📌 $($sub.EventSubscriptionName)" -ForegroundColor Gray
            Write-Host "      Topic: $($sub.Topic)" -ForegroundColor Gray
            Write-Host "      Endpoint: $($sub.Destination)" -ForegroundColor Gray
            Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ❌ NO Event Grid subscriptions found for Key Vault events!" -ForegroundColor Red
        Write-Host "   💡 This is likely the root cause - no subscription to forward events" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking Event Grid: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Check if webhook endpoint is configured for Automation Account
Write-Host "`n3. 🔍 Checking Automation Account webhook configuration..." -ForegroundColor Yellow
try {
    $webhooks = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName
    
    if ($webhooks) {
        Write-Host "   📋 Automation webhooks found:" -ForegroundColor Green
        foreach ($webhook in $webhooks) {
            Write-Host "   🪝 $($webhook.Name)" -ForegroundColor Gray
            Write-Host "      Runbook: $($webhook.RunbookName)" -ForegroundColor Gray
            Write-Host "      Enabled: $($webhook.IsEnabled)" -ForegroundColor Gray
            Write-Host "      Expires: $($webhook.ExpiryTime)" -ForegroundColor Gray
        }
        
        $certWebhook = $webhooks | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }
        if ($certWebhook) {
            Write-Host "   ✅ CertLifeCycleMgmt webhook found!" -ForegroundColor Green
            if ($certWebhook.IsEnabled) {
                Write-Host "   ✅ Webhook is enabled" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Webhook is DISABLED!" -ForegroundColor Red
            }
            if ($certWebhook.ExpiryTime -gt (Get-Date)) {
                Write-Host "   ✅ Webhook not expired" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Webhook is EXPIRED!" -ForegroundColor Red
            }
        } else {
            Write-Host "   ❌ NO webhook found for CertLifeCycleMgmt runbook!" -ForegroundColor Red
            Write-Host "   💡 Event Grid cannot trigger runbook without webhook" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ NO webhooks found in Automation Account!" -ForegroundColor Red
        Write-Host "   💡 This explains why Event Grid events don't trigger runbooks" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking webhooks: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check certificate current status
Write-Host "`n4. 🔍 Checking certificate current status..." -ForegroundColor Yellow
try {
    $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction SilentlyContinue
    if ($cert) {
        Write-Host "   ✅ Certificate found: $CertificateName" -ForegroundColor Green
        Write-Host "   📅 Expires: $($cert.Expires)" -ForegroundColor Gray
        
        $now = Get-Date
        if ($cert.Expires -lt $now) {
            $expiredMinutes = [math]::Round(($now - $cert.Expires).TotalMinutes, 1)
            Write-Host "   ❌ Certificate EXPIRED $expiredMinutes minutes ago" -ForegroundColor Red
        } else {
            $minutesLeft = [math]::Round(($cert.Expires - $now).TotalMinutes, 1)
            Write-Host "   ⏰ Certificate expires in $minutesLeft minutes" -ForegroundColor Yellow
        }
        
        # Check tags
        if ($cert.Tags -and $cert.Tags.ContainsKey("recipient")) {
            Write-Host "   ✅ Recipient tag: $($cert.Tags["recipient"])" -ForegroundColor Green
        } else {
            Write-Host "   ❌ NO recipient tag found!" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Certificate not found: $CertificateName" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking certificate: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Summary and next steps
Write-Host "`n🎯 DIAGNOSIS SUMMARY:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Gray
Write-Host "Based on the evidence, the most likely causes are:" -ForegroundColor White
Write-Host ""
Write-Host "1. ❌ Missing Event Grid Subscription" -ForegroundColor Red
Write-Host "   - Key Vault events not forwarded to Automation Account" -ForegroundColor Gray
Write-Host ""
Write-Host "2. ❌ Missing or Broken Webhook" -ForegroundColor Red  
Write-Host "   - Automation Account cannot receive Event Grid events" -ForegroundColor Gray
Write-Host ""
Write-Host "3. ❌ Webhook Expired or Disabled" -ForegroundColor Red
Write-Host "   - Webhook exists but not functional" -ForegroundColor Gray

Write-Host "`n🔧 RECOMMENDED FIXES:" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Gray
Write-Host "Run these scripts to fix the automation chain:" -ForegroundColor White
Write-Host ""
Write-Host "1. Create missing Event Grid subscription:" -ForegroundColor Green
Write-Host "   .\create-event-grid-subscription.ps1" -ForegroundColor White
Write-Host ""
Write-Host "2. Create/update Automation webhook:" -ForegroundColor Green  
Write-Host "   .\create-automation-webhook.ps1" -ForegroundColor White
Write-Host ""
Write-Host "3. Test end-to-end automation:" -ForegroundColor Green
Write-Host "   .\test-manual-renewal.ps1" -ForegroundColor White

Write-Host "`n💡 The fact that you see Event Grid events means Key Vault is working," -ForegroundColor Cyan
Write-Host "   but they're not reaching the Automation Account to trigger renewal." -ForegroundColor Cyan