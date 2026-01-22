#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test automation job execution on the Hybrid Worker
.DESCRIPTION
    Starts the CertLifeCycleMgmt runbook specifically on the EnterpriseRootCA Hybrid Worker Group
    to test if the automation works when properly routed to the on-premises worker.
#>

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Load .env file manually
$envPath = "$projectRoot/.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $value = $matches[2].Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($matches[1], $value, "Process")
        }
    }
}

Write-Host "🎯 TESTING HYBRID WORKER JOB EXECUTION" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "🏢 Automation Account: $($env:AUTOMATION_ACCOUNT_NAME)" -ForegroundColor White
Write-Host "🖥️ Target Hybrid Worker: EnterpriseRootCA" -ForegroundColor Yellow
Write-Host "📋 Runbook: CertLifeCycleMgmt" -ForegroundColor White
Write-Host ""

try {
    Write-Host "🚀 Starting runbook job on Hybrid Worker..." -ForegroundColor Cyan
    
    $job = Start-AzAutomationRunbook `
        -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME `
        -ResourceGroupName $env:RESOURCE_GROUP `
        -Name "CertLifeCycleMgmt" `
        -RunOn "EnterpriseRootCA"
    
    Write-Host "✅ Job started successfully!" -ForegroundColor Green
    Write-Host "🆔 Job ID: $($job.JobId)" -ForegroundColor Yellow
    Write-Host "📊 Initial Status: $($job.Status)" -ForegroundColor White
    Write-Host "🖥️ Running On: EnterpriseRootCA (Hybrid Worker)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "⏳ Monitoring job progress..." -ForegroundColor Cyan
    $timeout = 60  # 60 seconds timeout
    $elapsed = 0
    
    do {
        Start-Sleep -Seconds 5
        $elapsed += 5
        
        $currentJob = Get-AzAutomationJob -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -JobId $job.JobId
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        Write-Host "[$timestamp] Status: $($currentJob.Status)" -ForegroundColor White
        
        if ($currentJob.Status -eq "Completed") {
            Write-Host ""
            Write-Host "🎉 JOB COMPLETED SUCCESSFULLY!" -ForegroundColor Green
            Write-Host "This proves the Hybrid Worker automation is working!" -ForegroundColor Green
            break
        }
        elseif ($currentJob.Status -eq "Failed") {
            Write-Host ""
            Write-Host "❌ Job failed. Getting error details..." -ForegroundColor Red
            try {
                $output = Get-AzAutomationJobOutput -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -JobId $job.JobId -Stream Error
                if ($output) {
                    Write-Host "Error Output:" -ForegroundColor Red
                    $output | ForEach-Object { Write-Host "  $($_.Summary)" -ForegroundColor Gray }
                }
            } catch {
                Write-Host "Could not retrieve error details" -ForegroundColor Yellow
            }
            break
        }
        elseif ($currentJob.Status -eq "Stopped" -or $currentJob.Status -eq "Suspended") {
            Write-Host ""
            Write-Host "⚠️ Job was stopped or suspended" -ForegroundColor Yellow
            break
        }
        
    } while ($elapsed -lt $timeout -and $currentJob.Status -eq "Running")
    
    if ($elapsed -ge $timeout) {
        Write-Host ""
        Write-Host "⏰ Monitoring timeout reached. Job may still be running." -ForegroundColor Yellow
        Write-Host "Check Azure Portal for continued monitoring." -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🔍 FINAL ANALYSIS:" -ForegroundColor Magenta
    if ($currentJob.Status -eq "Completed") {
        Write-Host "✅ SUCCESS: Hybrid Worker automation is fully functional!" -ForegroundColor Green
        Write-Host "✅ The issue was job routing - webhooks need to target the Hybrid Worker" -ForegroundColor Green
    } elseif ($currentJob.Status -eq "Running") {
        Write-Host "🔄 PROGRESS: Job is running on Hybrid Worker (no immediate failure)" -ForegroundColor Yellow
        Write-Host "🔄 This is much better than the previous 'must run from Hybrid Worker' error" -ForegroundColor Yellow
    } else {
        Write-Host "❌ ISSUE: Job failed even when routed to Hybrid Worker" -ForegroundColor Red
        Write-Host "❌ This indicates a deeper configuration or permissions issue" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error starting job on Hybrid Worker:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}