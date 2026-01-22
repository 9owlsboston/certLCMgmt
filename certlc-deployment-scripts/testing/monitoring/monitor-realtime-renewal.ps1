# Real-Time Monitoring of Certificate Lifecycle Automation
# User just created a 2-minute certificate from DC01 - watch for automation response

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
$CertificateName = "democert-shortlived"

Write-Host "🔍 REAL-TIME CERTIFICATE LIFECYCLE MONITORING" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Gray
Write-Host "📋 Certificate: $CertificateName" -ForegroundColor Yellow
Write-Host "⏰ Started monitoring at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Function to check automation jobs
function Check-AutomationJobs {
    try {
        $since = (Get-Date).AddMinutes(-10)
        $jobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime $since
        $certJobs = $jobs | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }
        
        if ($certJobs) {
            foreach ($job in $certJobs) {
                $timeAgo = [math]::Round(((Get-Date) - $job.StartTime).TotalMinutes, 1)
                Write-Host "   ✅ Job: $($job.Status) - Started $timeAgo min ago" -ForegroundColor Green
            }
            return $true
        }
        return $false
    }
    catch {
        Write-Host "   ❌ Error checking jobs: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check certificate status
function Check-CertificateStatus {
    try {
        $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction SilentlyContinue
        if ($cert) {
            $now = Get-Date
            if ($cert.Expires -gt $now) {
                $minutesLeft = [math]::Round(($cert.Expires - $now).TotalMinutes, 1)
                Write-Host "   ⏰ Certificate expires in $minutesLeft minutes" -ForegroundColor Yellow
                return "active"
            } else {
                $expiredMinutes = [math]::Round(($now - $cert.Expires).TotalMinutes, 1)
                Write-Host "   ❌ Certificate EXPIRED $expiredMinutes minutes ago" -ForegroundColor Red
                return "expired"
            }
        } else {
            Write-Host "   ❌ Certificate not found" -ForegroundColor Red
            return "missing"
        }
    }
    catch {
        Write-Host "   ❌ Error checking certificate: $($_.Exception.Message)" -ForegroundColor Red
        return "error"
    }
}

# Initial status check
Write-Host "📊 INITIAL STATUS CHECK:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Gray

Write-Host "1. Certificate status:" -ForegroundColor Yellow
$certStatus = Check-CertificateStatus

Write-Host "`n2. Recent automation jobs (last 10 minutes):" -ForegroundColor Yellow
$hasRecentJobs = Check-AutomationJobs

Write-Host "`n🎯 WHAT TO WATCH FOR:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
Write-Host "1. Certificate expires (in ~2 minutes)" -ForegroundColor White
Write-Host "2. Event Grid publishes CertificateNearExpiry event" -ForegroundColor White
Write-Host "3. Event Grid delivers event to webhook" -ForegroundColor White
Write-Host "4. Automation Account receives webhook call" -ForegroundColor White
Write-Host "5. CertLifeCycleMgmt runbook starts execution" -ForegroundColor White
Write-Host "6. New certificate gets created/renewed" -ForegroundColor White

Write-Host "`n⏱️  MONITORING LOOP (will check every 30 seconds)..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

$monitoringStart = Get-Date
$lastJobCount = 0

# Get current job count baseline
try {
    $allJobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime (Get-Date).AddHours(-1)
    $lastJobCount = ($allJobs | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }).Count
    Write-Host "📊 Baseline: $lastJobCount CertLifeCycleMgmt jobs in last hour" -ForegroundColor Gray
}
catch {
    Write-Host "📊 Could not get baseline job count" -ForegroundColor Gray
}

# Monitoring loop
$round = 1
while ($true) {
    Start-Sleep -Seconds 30
    
    $now = Get-Date
    $elapsed = [math]::Round(($now - $monitoringStart).TotalMinutes, 1)
    
    Write-Host "`n🔄 CHECK #$round (${elapsed} min elapsed - $(Get-Date -Format 'HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Gray
    
    # Check certificate status
    Write-Host "📋 Certificate:" -ForegroundColor Yellow
    $currentCertStatus = Check-CertificateStatus
    
    # Check for new jobs
    Write-Host "`n🤖 Automation Jobs:" -ForegroundColor Yellow
    try {
        $recentJobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime (Get-Date).AddHours(-1)
        $certJobs = $recentJobs | Where-Object { $_.RunbookName -eq "CertLifeCycleMgmt" }
        $currentJobCount = $certJobs.Count
        
        if ($currentJobCount -gt $lastJobCount) {
            $newJobs = $currentJobCount - $lastJobCount
            Write-Host "   🎉 NEW JOBS DETECTED! $newJobs new CertLifeCycleMgmt job(s)" -ForegroundColor Green -BackgroundColor Black
            
            # Show the newest jobs
            $newestJobs = $certJobs | Sort-Object StartTime -Descending | Select-Object -First $newJobs
            foreach ($job in $newestJobs) {
                $timeAgo = [math]::Round(((Get-Date) - $job.StartTime).TotalMinutes, 1)
                Write-Host "   🆕 Job: $($job.Status) - Started $timeAgo min ago - ID: $($job.JobId)" -ForegroundColor Green
            }
            $lastJobCount = $currentJobCount
        } else {
            Write-Host "   📊 No new jobs (total: $currentJobCount)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   ❌ Error checking for new jobs: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Status summary
    if ($currentCertStatus -eq "expired") {
        Write-Host "`n⚠️  Certificate has expired - automation should trigger soon!" -ForegroundColor Yellow -BackgroundColor Black
    } elseif ($currentCertStatus -eq "active") {
        Write-Host "`n⏰ Certificate still active - waiting for expiry..." -ForegroundColor Gray
    }
    
    $round++
    
    # Stop after 15 minutes of monitoring
    if ($elapsed -gt 15) {
        Write-Host "`n⏱️  Monitoring complete (15 minutes elapsed)" -ForegroundColor Yellow
        break
    }
}

Write-Host "`n📊 MONITORING SUMMARY:" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Gray
Write-Host "🕐 Monitoring duration: $elapsed minutes" -ForegroundColor Gray
Write-Host "🔄 Checks performed: $($round - 1)" -ForegroundColor Gray
Write-Host "📋 Final certificate status: $currentCertStatus" -ForegroundColor Gray

if ($currentJobCount -gt $lastJobCount) {
    Write-Host "🎉 SUCCESS: Automation system responded to certificate expiry!" -ForegroundColor Green
} else {
    Write-Host "⏳ No new automation jobs detected during monitoring period" -ForegroundColor Yellow
    Write-Host "💡 Check Azure Portal for Event Grid metrics and job history" -ForegroundColor Gray
}