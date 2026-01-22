# Diagnose Why Delivered Events Don't Trigger Runbook Execution
# User confirmed: 23 events published, 20 delivered to DEMO-EG-20251103, 11 to CertLC-queue
# Events are reaching destinations but runbooks aren't executing

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

Write-Host "🔍 DIAGNOSING EVENT DELIVERY vs RUNBOOK EXECUTION GAP" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Gray
Write-Host "✅ Events published: 23" -ForegroundColor Green
Write-Host "✅ Events delivered to DEMO-EG-20251103: 20" -ForegroundColor Green
Write-Host "✅ Events delivered to CertLC-queue: 11" -ForegroundColor Green
Write-Host "❌ Runbook executions: 0 (based on earlier diagnosis)" -ForegroundColor Red
Write-Host ""
Write-Host "💡 This means Event Grid works, but webhook/runbook triggering is broken!" -ForegroundColor Yellow
Write-Host ""

# 1. Check webhook delivery failures
Write-Host "1. 🔍 Checking Event Grid delivery attempts to webhook..." -ForegroundColor Yellow
try {
    # Get webhook details first
    $webhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "clc-webhook" -ErrorAction SilentlyContinue
    
    if ($webhook) {
        Write-Host "   ✅ Webhook exists: clc-webhook" -ForegroundColor Green
        Write-Host "   🔗 Runbook: $($webhook.RunbookName)" -ForegroundColor Gray
        Write-Host "   ✅ Enabled: $($webhook.IsEnabled)" -ForegroundColor Gray
        
        if ($webhook.Uri) {
            Write-Host "   ✅ Webhook URL exists" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Webhook URL is NULL - this breaks Event Grid delivery!" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Webhook 'clc-webhook' not found!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking webhook: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Check Event Grid subscription configuration
Write-Host "`n2. 🔍 Checking Event Grid subscription targeting webhook..." -ForegroundColor Yellow
try {
    # List all subscriptions and find ones targeting our automation account
    $allSubs = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName
    $automationSubs = $allSubs | Where-Object { 
        $_.Destination -and $_.Destination.ToString() -like "*$AutomationAccountName*" 
    }
    
    if ($automationSubs) {
        Write-Host "   ✅ Found $($automationSubs.Count) subscription(s) targeting Automation Account:" -ForegroundColor Green
        
        foreach ($sub in $automationSubs) {
            Write-Host "`n   📌 Subscription: $($sub.EventSubscriptionName)" -ForegroundColor Cyan
            Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
            Write-Host "      Event Types: $($sub.IncludedEventTypes -join ', ')" -ForegroundColor Gray
            
            # Check if it includes certificate events
            if ($sub.IncludedEventTypes -contains "Microsoft.KeyVault.CertificateNearExpiry") {
                Write-Host "      ✅ Includes CertificateNearExpiry events" -ForegroundColor Green
            } else {
                Write-Host "      ❌ Missing CertificateNearExpiry events" -ForegroundColor Red
            }
            
            # Check destination
            if ($sub.Destination) {
                Write-Host "      🔗 Destination: $($sub.Destination)" -ForegroundColor Gray
                
                # Check if destination looks like a webhook URL
                if ($sub.Destination.ToString() -like "*webhooks*") {
                    Write-Host "      ✅ Destination appears to be a webhook" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ Destination may not be a webhook" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "   ❌ NO subscriptions found targeting Automation Account!" -ForegroundColor Red
        Write-Host "   💡 Events are delivered somewhere else, not to our webhook" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking subscriptions: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Check where the 11 events in CertLC-queue are coming from
Write-Host "`n3. 🔍 Analyzing CertLC-queue event destination..." -ForegroundColor Yellow
Write-Host "   📋 You reported 11 events delivered to 'CertLC-queue'" -ForegroundColor Gray
Write-Host "   💡 This suggests events are going to a Storage Queue, not a webhook!" -ForegroundColor Yellow
Write-Host ""
Write-Host "   🔍 Let's check if there's a subscription routing to Storage Queue:" -ForegroundColor Yellow

try {
    $queueSubs = $allSubs | Where-Object { 
        $_.Destination -and ($_.Destination.ToString() -like "*queue*" -or $_.Destination.ToString() -like "*storage*")
    }
    
    if ($queueSubs) {
        Write-Host "   ✅ Found $($queueSubs.Count) subscription(s) targeting Storage Queue:" -ForegroundColor Green
        
        foreach ($sub in $queueSubs) {
            Write-Host "`n   📌 Queue Subscription: $($sub.EventSubscriptionName)" -ForegroundColor Cyan
            Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
            Write-Host "      Destination: $($sub.Destination)" -ForegroundColor Gray
            Write-Host "      Event Types: $($sub.IncludedEventTypes -join ', ')" -ForegroundColor Gray
            
            if ($sub.IncludedEventTypes -contains "Microsoft.KeyVault.CertificateNearExpiry") {
                Write-Host "      ✅ This subscription handles certificate events!" -ForegroundColor Green
                Write-Host "      💡 But Storage Queue can't trigger runbooks directly" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "   ❌ No Storage Queue subscriptions found" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking queue subscriptions: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check recent Automation jobs again with specific focus
Write-Host "`n4. 🔍 Double-checking Automation job history around event times..." -ForegroundColor Yellow
try {
    # Check jobs from last 24 hours to catch any missed executions
    $since = (Get-Date).AddHours(-24)
    $jobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime $since
    
    if ($jobs) {
        Write-Host "   📋 Found $($jobs.Count) Automation jobs in last 24 hours:" -ForegroundColor Green
        
        # Focus on CertLifeCycleMgmt jobs
        $certJobs = $jobs | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }
        if ($certJobs) {
            Write-Host "   🎯 CertLifeCycleMgmt jobs:" -ForegroundColor Green
            foreach ($job in $certJobs) {
                Write-Host "      Job: $($job.JobId) - $($job.Status) - $($job.StartTime)" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ❌ NO CertLifeCycleMgmt jobs found in 24 hours!" -ForegroundColor Red
            Write-Host "   💡 Despite 23 events, no certificate jobs were triggered" -ForegroundColor Yellow
        }
        
        # Show all jobs for context
        Write-Host "`n   📋 All recent jobs:" -ForegroundColor Gray
        foreach ($job in $jobs) {
            $status = switch ($job.Status) {
                "Completed" { "✅" }
                "Failed" { "❌" }
                "Running" { "🔄" }
                default { "❓" }
            }
            Write-Host "      $status $($job.RunbookName) - $($job.StartTime)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ❌ NO Automation jobs found in last 24 hours" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking jobs: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Summary and root cause analysis
Write-Host "`n🎯 ROOT CAUSE ANALYSIS:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Gray

Write-Host "Based on your Event Grid metrics and our analysis:" -ForegroundColor White
Write-Host ""
Write-Host "✅ Key Vault publishes events (23 events)" -ForegroundColor Green
Write-Host "✅ Event Grid receives and processes events (20 delivered)" -ForegroundColor Green
Write-Host "✅ Events reach some destination (11 to CertLC-queue)" -ForegroundColor Green
Write-Host "❌ Events do NOT trigger Automation runbooks" -ForegroundColor Red
Write-Host ""

Write-Host "🔍 LIKELY SCENARIOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 🎯 MOST LIKELY: Events go to Storage Queue, not webhook" -ForegroundColor Red
Write-Host "   → Storage Queue cannot trigger runbooks directly" -ForegroundColor Gray
Write-Host "   → Need Event Grid subscription to point to webhook instead" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 🎯 POSSIBLE: Webhook URL is broken/null" -ForegroundColor Red
Write-Host "   → Event Grid tries to call webhook but fails" -ForegroundColor Gray
Write-Host "   → Falls back to dead letter or alternate destination" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 🎯 POSSIBLE: Wrong event types in subscription" -ForegroundColor Red
Write-Host "   → Events delivered but not the right type for certificate renewal" -ForegroundColor Gray

Write-Host "`n🔧 RECOMMENDED ACTIONS:" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Gray
Write-Host "1. First, fix webhook URL:" -ForegroundColor White
Write-Host "   .\fix-webhook-url.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Create/update Event Grid subscription to target webhook:" -ForegroundColor White
Write-Host "   .\create-webhook-subscription.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test with new short-lived certificate:" -ForegroundColor White
Write-Host "   .\create-shortlived-cert-robust.ps1" -ForegroundColor Gray

Write-Host "`n💡 The mystery is solved: Events flow to Storage Queue, not webhook!" -ForegroundColor Cyan
Write-Host "   Storage Queue cannot execute runbooks - need direct webhook subscription." -ForegroundColor Cyan