# Certificate Lifecycle Monitoring Script
# Monitors the entire renewal process from expiry detection to completion

param(
    [string]$CertificateName = "democert-shortlived",
    [int]$MonitoringDurationMinutes = 25
)

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

Write-Host "🔍 Certificate Lifecycle Monitoring Dashboard" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Gray
Write-Host "📅 Start Time: $(Get-Date)" -ForegroundColor White
Write-Host "🔑 Certificate: $CertificateName" -ForegroundColor White
Write-Host "🏢 Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host "🤖 Automation Account: $AutomationAccountName" -ForegroundColor White
Write-Host "⏱️  Monitoring Duration: $MonitoringDurationMinutes minutes" -ForegroundColor White
Write-Host ""

$startTime = Get-Date
$endTime = $startTime.AddMinutes($MonitoringDurationMinutes)
$checkInterval = 30 # seconds

$previousCertThumbprint = $null
$renewalDetected = $false
$automationTriggered = $false

function Get-CertificateStatus {
    try {
        $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction Stop
        return @{
            Exists = $true
            Thumbprint = $cert.Thumbprint
            Expires = $cert.Expires
            IsExpired = $cert.Expires -lt (Get-Date)
            TimeUntilExpiry = $cert.Expires - (Get-Date)
        }
    }
    catch {
        return @{
            Exists = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-AutomationJobs {
    try {
        $jobs = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName "CertLifeCycleMgmt" -ErrorAction Stop |
                Sort-Object StartTime -Descending |
                Select-Object -First 5
        return $jobs
    }
    catch {
        Write-Host "   ⚠️  Could not retrieve automation jobs: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

function Get-EventGridEvents {
    try {
        # Check for recent Event Grid events related to Key Vault
        $events = Get-AzActivityLog -ResourceGroupName $ResourceGroupName -StartTime $startTime.AddMinutes(-5) -MaxRecord 50 |
                  Where-Object { $_.ResourceId -like "*$KeyVaultName*" -or $_.OperationName -like "*Certificate*" } |
                  Sort-Object EventTimestamp -Descending
        return $events
    }
    catch {
        Write-Host "   ⚠️  Could not retrieve Event Grid events: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

# Initial certificate status
Write-Host "📋 Initial Certificate Status:" -ForegroundColor Yellow
$initialStatus = Get-CertificateStatus
if ($initialStatus.Exists) {
    Write-Host "   ✅ Certificate exists" -ForegroundColor Green
    Write-Host "   🔑 Thumbprint: $($initialStatus.Thumbprint)" -ForegroundColor Gray
    Write-Host "   ⏰ Expires: $($initialStatus.Expires)" -ForegroundColor Gray
    Write-Host "   ⏳ Time until expiry: $([math]::Round($initialStatus.TimeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Yellow
    $previousCertThumbprint = $initialStatus.Thumbprint
} else {
    Write-Host "   ❌ Certificate not found: $($initialStatus.Error)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔄 Starting continuous monitoring..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring early" -ForegroundColor Gray
Write-Host ""

# Monitoring loop
while ((Get-Date) -lt $endTime) {
    $currentTime = Get-Date
    $elapsed = ($currentTime - $startTime).TotalMinutes
    
    Write-Host "⏱️  $($currentTime.ToString('HH:mm:ss')) (T+$([math]::Round($elapsed, 1))m)" -ForegroundColor White
    
    # Check certificate status
    $status = Get-CertificateStatus
    if ($status.Exists) {
        if ($status.IsExpired -and -not $renewalDetected) {
            Write-Host "   🚨 CERTIFICATE EXPIRED! Renewal should trigger soon..." -ForegroundColor Red
            $renewalDetected = $true
        }
        
        # Check if thumbprint changed (renewal completed)
        if ($previousCertThumbprint -and $status.Thumbprint -ne $previousCertThumbprint) {
            Write-Host "   🎉 RENEWAL DETECTED! New certificate issued!" -ForegroundColor Green -BackgroundColor Black
            Write-Host "   📊 Old Thumbprint: $previousCertThumbprint" -ForegroundColor Gray
            Write-Host "   📊 New Thumbprint: $($status.Thumbprint)" -ForegroundColor Green
            Write-Host "   ⏰ New Expiry: $($status.Expires)" -ForegroundColor Green
            $previousCertThumbprint = $status.Thumbprint
        }
        
        $expiryStatus = if ($status.IsExpired) { "EXPIRED" } else { "$([math]::Round($status.TimeUntilExpiry.TotalMinutes, 1))m remaining" }
        Write-Host "   🔑 Certificate Status: $expiryStatus" -ForegroundColor $(if ($status.IsExpired) { "Red" } else { "Gray" })
    } else {
        Write-Host "   ❌ Certificate check failed: $($status.Error)" -ForegroundColor Red
    }
    
    # Check automation jobs
    $recentJobs = Get-AutomationJobs
    $newJobs = $recentJobs | Where-Object { $_.StartTime -gt $startTime }
    
    if ($newJobs) {
        foreach ($job in $newJobs) {
            if (-not $automationTriggered) {
                Write-Host "   🤖 AUTOMATION TRIGGERED!" -ForegroundColor Yellow -BackgroundColor Black
                $automationTriggered = $true
            }
            $statusColor = switch ($job.Status) {
                "Completed" { "Green" }
                "Running" { "Yellow" }
                "Failed" { "Red" }
                default { "Gray" }
            }
            Write-Host "   📋 Job: $($job.JobId) | Status: $($job.Status) | Started: $($job.StartTime)" -ForegroundColor $statusColor
        }
    } else {
        Write-Host "   ⏳ No new automation jobs detected" -ForegroundColor Gray
    }
    
    # Check for Activity Log events
    $events = Get-EventGridEvents
    if ($events) {
        $recentEvents = $events | Where-Object { $_.EventTimestamp -gt $startTime } | Select-Object -First 3
        foreach ($event in $recentEvents) {
            Write-Host "   📡 Event: $($event.OperationName) | Status: $($event.Status)" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    
    # Wait before next check
    Start-Sleep -Seconds $checkInterval
}

Write-Host "⏰ Monitoring completed at $(Get-Date)" -ForegroundColor Cyan
Write-Host ""

# Final summary
Write-Host "📊 MONITORING SUMMARY:" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Gray

$finalStatus = Get-CertificateStatus
if ($finalStatus.Exists) {
    if ($finalStatus.Thumbprint -ne $previousCertThumbprint) {
        Write-Host "✅ RENEWAL SUCCESSFUL!" -ForegroundColor Green -BackgroundColor Black
        Write-Host "   📊 Certificate was successfully renewed" -ForegroundColor Green
        Write-Host "   🔑 Final Thumbprint: $($finalStatus.Thumbprint)" -ForegroundColor Gray
        Write-Host "   ⏰ New Expiry: $($finalStatus.Expires)" -ForegroundColor Gray
    } else {
        Write-Host "⏳ RENEWAL PENDING" -ForegroundColor Yellow
        Write-Host "   📊 Certificate renewal may still be in progress" -ForegroundColor Yellow
        Write-Host "   💡 Continue monitoring manually or extend monitoring time" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ CERTIFICATE MISSING" -ForegroundColor Red
    Write-Host "   💡 Check Azure Portal for any issues" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔍 Additional Monitoring Commands:" -ForegroundColor Yellow
Write-Host "az keyvault certificate show --vault-name $KeyVaultName --name $CertificateName" -ForegroundColor White
Write-Host "# Check Azure Portal → Automation Account → $AutomationAccountName → Jobs" -ForegroundColor Gray
Write-Host "# Check Azure Portal → Log Analytics → $WorkspaceName → Logs" -ForegroundColor Gray