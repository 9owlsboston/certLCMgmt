#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Real-time monitoring of certificate lifecycle automation after threshold fix
.DESCRIPTION
    Monitors automation jobs, Event Grid events, and certificate status to validate
    that the CertRenewalThresholdDays=1 fix enables test certificate processing
#>

# Import configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Load .env file manually
$envPath = "$projectRoot/.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            # Remove quotes from the value
            $value = $matches[2].Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($matches[1], $value, "Process")
        }
    }
}

Write-Host "🔍 REAL-TIME AUTOMATION MONITORING" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "📊 Target: $($env:AUTOMATION_ACCOUNT_NAME)" -ForegroundColor White
Write-Host "🎯 Threshold: CertRenewalThresholdDays = 1 day (FIXED!)" -ForegroundColor Green
Write-Host "⏰ Monitoring started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Get baseline
Write-Host "📋 Getting baseline automation job count..." -ForegroundColor Yellow
$baselineJobs = Get-AzAutomationJob -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -RunbookName "CertLifeCycleMgmt"
$baselineCount = $baselineJobs.Count
Write-Host "Current job count: $baselineCount" -ForegroundColor White

# Get latest certificate info
Write-Host ""
Write-Host "🔑 Checking current test certificates..." -ForegroundColor Yellow
try {
    $certificates = Get-AzKeyVaultCertificate -VaultName $env:KEY_VAULT_NAME
    $testCerts = $certificates | Where-Object { $_.Name -like "*test*" -or $_.Name -like "*short*" -or $_.Name -like "*demo*" }
    
    if ($testCerts) {
        Write-Host "Found test certificates:" -ForegroundColor Green
        foreach ($cert in $testCerts) {
            $certDetail = Get-AzKeyVaultCertificate -VaultName $env:KEY_VAULT_NAME -Name $cert.Name
            $expiryTime = $certDetail.Certificate.NotAfter
            $timeUntilExpiry = $expiryTime - (Get-Date)
            
            $status = if ($timeUntilExpiry.TotalMinutes -le 0) { "🔴 EXPIRED" } 
                     elseif ($timeUntilExpiry.TotalMinutes -le 5) { "🟡 EXPIRING SOON" }
                     else { "🟢 ACTIVE" }
            
            Write-Host "  📄 $($cert.Name): $status" -ForegroundColor White
            Write-Host "     Expires: $($expiryTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "     Time left: $([math]::Round($timeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Gray
        }
    } else {
        Write-Host "No test certificates found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error checking certificates: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔄 Starting real-time monitoring (checking every 30 seconds)..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

$iteration = 0
while ($true) {
    $iteration++
    $currentTime = Get-Date -Format 'HH:mm:ss'
    
    Write-Host "[$currentTime] Check #$iteration" -ForegroundColor Cyan
    
    # Check for new automation jobs
    try {
        $currentJobs = Get-AzAutomationJob -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -RunbookName "CertLifeCycleMgmt"
        $newJobCount = $currentJobs.Count
        
        if ($newJobCount -gt $baselineCount) {
            $newJobs = $currentJobs | Select-Object -First ($newJobCount - $baselineCount) | Sort-Object CreationTime -Descending
            
            Write-Host "🚨 NEW AUTOMATION JOB(S) DETECTED!" -ForegroundColor Green
            foreach ($job in $newJobs) {
                Write-Host "  📋 Job ID: $($job.JobId)" -ForegroundColor Yellow
                Write-Host "  📅 Started: $($job.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
                Write-Host "  📊 Status: $($job.Status)" -ForegroundColor White
                
                # If job is completed, get output
                if ($job.Status -eq "Completed" -or $job.Status -eq "Failed" -or $job.Status -eq "Stopped") {
                    try {
                        $output = Get-AzAutomationJobOutput -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -JobId $job.JobId -Stream Output
                        if ($output) {
                            Write-Host "  📝 Job Output:" -ForegroundColor Cyan
                            $output | ForEach-Object { Write-Host "     $($_.Summary)" -ForegroundColor Gray }
                        }
                    } catch {
                        Write-Host "  ⚠️ Could not retrieve job output" -ForegroundColor Yellow
                    }
                }
            }
            
            # Update baseline
            $baselineCount = $newJobCount
        } else {
            Write-Host "  📊 Job count: $newJobCount (no new jobs)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ❌ Error checking jobs: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep -Seconds 30
}