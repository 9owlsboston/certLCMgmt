# Quick Check: Why Is Automation System No Longer Running Jobs?
# Earlier we saw 11 successful CertLifeCycleMgmt jobs, but now it's inactive

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config) {
    Write-Host "❌ Could not load configuration" -ForegroundColor Red
    exit 1
}

$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']

Write-Host "🔍 AUTOMATION SYSTEM STATUS CHECK" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Gray
Write-Host "⏰ Current time: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# 1. Check Automation Account status
Write-Host "1. 🤖 Automation Account status..." -ForegroundColor Yellow
try {
    $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    if ($automationAccount) {
        Write-Host "   ✅ Automation Account: $($automationAccount.AutomationAccountName)" -ForegroundColor Green
        Write-Host "   📍 Location: $($automationAccount.Location)" -ForegroundColor Gray
        Write-Host "   🔄 State: $($automationAccount.State)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   ❌ Error accessing Automation Account: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Check recent job pattern
Write-Host "`n2. 📊 Job execution pattern..." -ForegroundColor Yellow
try {
    $last24Hours = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime (Get-Date).AddHours(-24)
    $certJobs = $last24Hours | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" } | Sort-Object StartTime -Descending
    
    if ($certJobs) {
        Write-Host "   📋 Last 5 CertLifeCycleMgmt jobs:" -ForegroundColor Green
        $lastFive = $certJobs | Select-Object -First 5
        foreach ($job in $lastFive) {
            $timeAgo = [math]::Round(((Get-Date) - $job.StartTime).TotalHours, 1)
            Write-Host "   📌 $($job.StartTime) ($timeAgo hrs ago) - $($job.Status)" -ForegroundColor Gray
        }
        
        # Check gap since last job
        $lastJob = $certJobs | Select-Object -First 1
        $timeSinceLastJob = [math]::Round(((Get-Date) - $lastJob.StartTime).TotalHours, 1)
        
        if ($timeSinceLastJob -gt 4) {
            Write-Host "`n   ⚠️  LONG GAP: $timeSinceLastJob hours since last job!" -ForegroundColor Yellow
            Write-Host "   💡 This suggests the automation system may have stopped" -ForegroundColor Yellow
        } else {
            Write-Host "`n   ✅ Recent activity: Last job $timeSinceLastJob hours ago" -ForegroundColor Green
        }
    } else {
        Write-Host "   ❌ No CertLifeCycleMgmt jobs found in last 24 hours!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking job history: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Check runbook status
Write-Host "`n3. 📋 Runbook status..." -ForegroundColor Yellow
try {
    $runbook = Get-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "CertLifeCycleMgmt"
    if ($runbook) {
        Write-Host "   ✅ Runbook: $($runbook.RunbookName)" -ForegroundColor Green
        Write-Host "   🔄 State: $($runbook.State)" -ForegroundColor Gray
        Write-Host "   📝 Type: $($runbook.RunbookType)" -ForegroundColor Gray
        Write-Host "   📅 Last Modified: $($runbook.LastModifiedTime)" -ForegroundColor Gray
        
        if ($runbook.State -ne "Published") {
            Write-Host "   ⚠️  Runbook is not in Published state!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ CertLifeCycleMgmt runbook not found!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking runbook: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check webhook status
Write-Host "`n4. 🪝 Webhook status..." -ForegroundColor Yellow
try {
    $webhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "clc-webhook"
    if ($webhook) {
        Write-Host "   ✅ Webhook: $($webhook.Name)" -ForegroundColor Green
        Write-Host "   🔗 Runbook: $($webhook.RunbookName)" -ForegroundColor Gray
        Write-Host "   ✅ Enabled: $($webhook.IsEnabled)" -ForegroundColor Gray
        Write-Host "   📅 Expires: $($webhook.ExpiryTime)" -ForegroundColor Gray
        
        if (-not $webhook.IsEnabled) {
            Write-Host "   ❌ Webhook is DISABLED!" -ForegroundColor Red
        }
        
        if ($webhook.ExpiryTime -lt (Get-Date)) {
            Write-Host "   ❌ Webhook is EXPIRED!" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Webhook 'clc-webhook' not found!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error checking webhook: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Manual trigger test
Write-Host "`n5. 🧪 Testing manual runbook trigger..." -ForegroundColor Yellow
Write-Host "   💡 This will test if the runbook can still execute" -ForegroundColor Gray

try {
    $testJob = Start-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "CertLifeCycleMgmt"
    if ($testJob) {
        Write-Host "   ✅ Manual trigger successful!" -ForegroundColor Green
        Write-Host "   🆔 Job ID: $($testJob.JobId)" -ForegroundColor Gray
        Write-Host "   🔄 Status: $($testJob.Status)" -ForegroundColor Gray
        
        # Wait a few seconds and check status
        Start-Sleep -Seconds 5
        $jobStatus = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $testJob.JobId
        Write-Host "   📊 Updated Status: $($jobStatus.Status)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Manual trigger failed!" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Error triggering runbook: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 SUMMARY:" -ForegroundColor Cyan
Write-Host "==========" -ForegroundColor Gray
Write-Host "Based on this analysis, the automation system may be:" -ForegroundColor White
Write-Host ""
Write-Host "1. 🔄 SCHEDULED: Only runs on specific schedule (not event-driven)" -ForegroundColor Yellow
Write-Host "2. ❌ INACTIVE: System stopped/disabled" -ForegroundColor Red
Write-Host "3. 🔧 MISCONFIGURED: Event Grid not reaching webhook" -ForegroundColor Red
Write-Host "4. ⏰ TIME-BASED: Only runs during specific hours" -ForegroundColor Yellow

Write-Host "`n💡 The manual trigger test above will help determine if the issue is" -ForegroundColor Cyan
Write-Host "   with the runbook itself or the Event Grid triggering mechanism." -ForegroundColor Cyan