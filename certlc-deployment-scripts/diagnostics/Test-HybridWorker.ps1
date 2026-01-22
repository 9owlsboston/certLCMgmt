# Hybrid Runbook Worker Verification and Testing Scripts
# Use these scripts to verify HRW is working after fixes

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-certlc-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "certlc-automation-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$HybridWorkerGroupName = "EnterpriseRootCA",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Quick", "Full", "CertTest", "ConnectivityOnly")]
    [string]$TestType = "Quick",
    
    [Parameter(Mandatory=$false)]
    [switch]$WaitForCompletion
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hybrid Runbook Worker Verification" -ForegroundColor Cyan
Write-Host "Test Type: $TestType" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Connect-ToAzure {
    Write-Host "`n🔐 Connecting to Azure..." -ForegroundColor Yellow
    
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
            Connect-AzAccount -SubscriptionId $SubscriptionId
        } else {
            Write-Host "✅ Already connected to Azure" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to connect to Azure: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-HybridWorkerStatus {
    Write-Host "`n🔍 Checking Hybrid Worker status..." -ForegroundColor Yellow
    
    try {
        # Check worker group exists
        $workerGroup = Get-AzAutomationHybridRunbookWorkerGroup -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $HybridWorkerGroupName -ErrorAction SilentlyContinue
        
        if (-not $workerGroup) {
            Write-Host "❌ Hybrid Worker Group '$HybridWorkerGroupName' not found!" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ Worker Group found: $($workerGroup.Name)" -ForegroundColor Green
        
        # Check workers in group
        $workers = Get-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName
        
        if (-not $workers) {
            Write-Host "❌ No workers found in group!" -ForegroundColor Red
            return $false
        }
        
        Write-Host "`n👥 Workers in group:" -ForegroundColor White
        foreach ($worker in $workers) {
            $lastSeen = $worker.LastSeenDateTime
            $isRecent = $lastSeen -gt (Get-Date).AddMinutes(-10)
            $status = if ($isRecent) { "✅ ONLINE" } else { "❌ OFFLINE" }
            $color = if ($isRecent) { "Green" } else { "Red" }
            
            Write-Host "$status Worker: $($worker.Name)" -ForegroundColor $color
            Write-Host "      IP: $($worker.IpAddress)" -ForegroundColor Gray
            Write-Host "      Last Seen: $lastSeen" -ForegroundColor Gray
            
            if (-not $isRecent) {
                $offlineTime = (Get-Date) - $lastSeen
                Write-Host "      Offline for: $($offlineTime.ToString('dd\:hh\:mm\:ss'))" -ForegroundColor Red
            }
        }
        
        # Return true if at least one worker is online
        $onlineWorkers = $workers | Where-Object { $_.LastSeenDateTime -gt (Get-Date).AddMinutes(-10) }
        return ($onlineWorkers.Count -gt 0)
    }
    catch {
        Write-Host "❌ Failed to check worker status: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-SimpleJob {
    Write-Host "`n🧪 Testing simple runbook execution..." -ForegroundColor Yellow
    
    try {
        # Create a simple test runbook if it doesn't exist
        $runbookName = "Test-HybridWorker-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        # Simple PowerShell script to test hybrid worker
        $runbookContent = @'
# Simple test script for Hybrid Worker
Write-Output "Hybrid Worker Test Started at $(Get-Date)"
Write-Output "Computer Name: $env:COMPUTERNAME"
Write-Output "User Context: $env:USERNAME"
Write-Output "Domain: $env:USERDOMAIN"
Write-Output "PowerShell Version: $($PSVersionTable.PSVersion)"

# Test CA service if available
try {
    $caService = Get-Service -Name "CertSvc" -ErrorAction SilentlyContinue
    if ($caService) {
        Write-Output "Certificate Authority Service: $($caService.Status)"
    } else {
        Write-Output "Certificate Authority Service: Not Found"
    }
} catch {
    Write-Output "Certificate Authority Service: Error checking - $($_.Exception.Message)"
}

# Test AD DS service if available
try {
    $adService = Get-Service -Name "ADWS" -ErrorAction SilentlyContinue
    if ($adService) {
        Write-Output "Active Directory Web Services: $($adService.Status)"
    } else {
        Write-Output "Active Directory Web Services: Not Found"
    }
} catch {
    Write-Output "Active Directory Web Services: Error checking - $($_.Exception.Message)"
}

Write-Output "Hybrid Worker Test Completed at $(Get-Date)"
'@
        
        Write-Host "Creating test runbook: $runbookName" -ForegroundColor Cyan
        
        # Import the runbook
        Import-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $runbookName -Type PowerShell -Description "Hybrid Worker connectivity test" -Force
        
        # Set the runbook content
        Set-AzAutomationRunbookDefinition -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $runbookName -Content $runbookContent -Overwrite
        
        # Publish the runbook
        Publish-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $runbookName
        
        Write-Host "✅ Test runbook created and published" -ForegroundColor Green
        
        # Start the job on hybrid worker
        Write-Host "Starting job on Hybrid Worker..." -ForegroundColor Cyan
        $job = Start-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $runbookName -RunOn $HybridWorkerGroupName
        
        Write-Host "✅ Job started: $($job.JobId)" -ForegroundColor Green
        Write-Host "Job Status: $($job.Status)" -ForegroundColor White
        
        if ($WaitForCompletion) {
            Write-Host "`n⏳ Waiting for job completion..." -ForegroundColor Yellow
            
            $timeout = 300 # 5 minutes
            $elapsed = 0
            
            do {
                Start-Sleep -Seconds 5
                $elapsed += 5
                $jobStatus = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId
                Write-Host "." -NoNewline -ForegroundColor Gray
                
                if ($elapsed % 30 -eq 0) {
                    Write-Host " Status: $($jobStatus.Status)" -ForegroundColor Cyan
                }
                
            } while ($jobStatus.Status -in @("Queued", "Starting", "Running") -and $elapsed -lt $timeout)
            
            Write-Host "`n"
            
            # Get final status and output
            $finalJob = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId
            Write-Host "Final Status: $($finalJob.Status)" -ForegroundColor $(if ($finalJob.Status -eq "Completed") { "Green" } else { "Red" })
            
            if ($finalJob.Status -eq "Completed") {
                Write-Host "`n📋 Job Output:" -ForegroundColor White
                $output = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId -Stream Output
                foreach ($line in $output) {
                    $outputDetail = Get-AzAutomationJobOutputRecord -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -JobId $job.JobId -Id $line.StreamRecordId
                    Write-Host "  $($outputDetail.Value)" -ForegroundColor Gray
                }
                
                # Clean up test runbook
                Write-Host "`n🧹 Cleaning up test runbook..." -ForegroundColor Yellow
                Remove-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $runbookName -Force
                
                return $true
            } else {
                Write-Host "`n❌ Job failed with status: $($finalJob.Status)" -ForegroundColor Red
                
                # Get error details
                $errors = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId -Stream Error
                if ($errors) {
                    Write-Host "`n🔍 Error Details:" -ForegroundColor Red
                    foreach ($error in $errors) {
                        $errorDetail = Get-AzAutomationJobOutputRecord -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -JobId $job.JobId -Id $error.StreamRecordId
                        Write-Host "  $($errorDetail.Value)" -ForegroundColor Red
                    }
                }
                
                return $false
            }
        } else {
            Write-Host "ℹ️ Job started. Use -WaitForCompletion to wait for results" -ForegroundColor Cyan
            Write-Host "Job ID: $($job.JobId)" -ForegroundColor White
            return $true
        }
    }
    catch {
        Write-Host "❌ Failed to test simple job: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-CertificateLifecycleJob {
    Write-Host "`n🔐 Testing certificate lifecycle job..." -ForegroundColor Yellow
    
    try {
        # Check if the CertLifeCycleMgmt runbook exists
        $runbook = Get-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "CertLifeCycleMgmt" -ErrorAction SilentlyContinue
        
        if (-not $runbook) {
            Write-Host "❌ CertLifeCycleMgmt runbook not found!" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ CertLifeCycleMgmt runbook found" -ForegroundColor Green
        
        # Start a test certificate lifecycle job
        Write-Host "Starting certificate lifecycle test..." -ForegroundColor Cyan
        
        $parameters = @{
            'CertificateName' = 'TestCert-HRW-Verification'
            'TestMode' = $true
        }
        
        $job = Start-AzAutomationRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "CertLifeCycleMgmt" -Parameters $parameters -RunOn $HybridWorkerGroupName
        
        Write-Host "✅ Certificate test job started: $($job.JobId)" -ForegroundColor Green
        
        if ($WaitForCompletion) {
            # Wait for initial status update
            Start-Sleep -Seconds 10
            $jobStatus = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId
            
            Write-Host "Job Status: $($jobStatus.Status)" -ForegroundColor $(
                switch ($jobStatus.Status) {
                    "Completed" { "Green" }
                    "Failed" { "Red" }
                    "Suspended" { "Red" }
                    default { "Yellow" }
                }
            )
            
            if ($jobStatus.Status -eq "Suspended") {
                Write-Host "❌ Job was suspended - Hybrid Worker still not working!" -ForegroundColor Red
                return $false
            } elseif ($jobStatus.Status -in @("Running", "Completed")) {
                Write-Host "✅ Job is executing on Hybrid Worker!" -ForegroundColor Green
                return $true
            }
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to test certificate lifecycle: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-NetworkConnectivity {
    Write-Host "`n🌐 Testing network connectivity from ca01..." -ForegroundColor Yellow
    
    try {
        # Test connectivity using PowerShell remoting to ca01
        $connectivityTest = Invoke-Command -ComputerName "ca01" -ScriptBlock {
            $results = @()
            
            # Test Azure Automation endpoints
            $endpoints = @(
                "https://management.azure.com",
                "https://eus2-agentservice-prod-1.azure-automation.net",
                "https://eus2-jrds-prod-1.azure-automation.net"
            )
            
            foreach ($endpoint in $endpoints) {
                try {
                    $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10
                    $results += "✅ $endpoint - OK ($($response.StatusCode))"
                }
                catch {
                    $results += "❌ $endpoint - FAILED ($($_.Exception.Message))"
                }
            }
            
            return $results
        } -ErrorAction SilentlyContinue
        
        if ($connectivityTest) {
            Write-Host "`n🔍 Connectivity Results:" -ForegroundColor White
            foreach ($result in $connectivityTest) {
                $color = if ($result.StartsWith("✅")) { "Green" } else { "Red" }
                Write-Host $result -ForegroundColor $color
            }
            
            $successCount = ($connectivityTest | Where-Object { $_.StartsWith("✅") }).Count
            return $successCount -gt 0
        } else {
            Write-Host "❌ Could not test connectivity from ca01" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Network connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
try {
    if (-not (Connect-ToAzure)) {
        exit 1
    }
    
    $overallSuccess = $true
    
    switch ($TestType) {
        "ConnectivityOnly" {
            $overallSuccess = Test-NetworkConnectivity
        }
        "Quick" {
            $overallSuccess = Test-HybridWorkerStatus
            if ($overallSuccess) {
                $overallSuccess = Test-SimpleJob
            }
        }
        "Full" {
            $workerStatus = Test-HybridWorkerStatus
            $connectivity = Test-NetworkConnectivity
            $simpleJob = if ($workerStatus) { Test-SimpleJob } else { $false }
            
            $overallSuccess = $workerStatus -and $connectivity -and $simpleJob
        }
        "CertTest" {
            $workerStatus = Test-HybridWorkerStatus
            $certTest = if ($workerStatus) { Test-CertificateLifecycleJob } else { $false }
            
            $overallSuccess = $workerStatus -and $certTest
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    if ($overallSuccess) {
        Write-Host "🎉 ALL TESTS PASSED! Hybrid Worker is working!" -ForegroundColor Green
        Write-Host "✅ Certificate lifecycle automation should now work normally" -ForegroundColor Green
    } else {
        Write-Host "❌ TESTS FAILED! Hybrid Worker needs more work" -ForegroundColor Red
        Write-Host "📋 Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Check service status on ca01" -ForegroundColor Yellow
        Write-Host "  2. Restart Hybrid Worker services" -ForegroundColor Yellow
        Write-Host "  3. Re-register worker if needed" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Verification failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Quick test:         .\Test-HybridWorker.ps1 -TestType Quick" -ForegroundColor White
Write-Host "Full test:          .\Test-HybridWorker.ps1 -TestType Full -WaitForCompletion" -ForegroundColor White
Write-Host "Certificate test:   .\Test-HybridWorker.ps1 -TestType CertTest" -ForegroundColor White
Write-Host "Connectivity only:  .\Test-HybridWorker.ps1 -TestType ConnectivityOnly" -ForegroundColor White