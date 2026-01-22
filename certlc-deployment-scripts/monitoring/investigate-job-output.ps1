# Investigation Script: Analyze Automation Job Output for Certificate Renewal
# This script helps identify which job processed your democert-shortlived certificate

param(
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "DEMO-AA-1030164500",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-demo-certlc",
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateName = "democert-shortlived"
)

Write-Host "🔍 Investigating Certificate Renewal Jobs" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Gray

# Job IDs from the time period
$JobIds = @(
    "726d9fd6-4405-4ed1-a613-8d2f53e4ee09",  # 00:56:32 - Completed
    "be4a8c0b-a020-4c7b-a0f9-154ccc1c8e7c",  # 01:00:38 - Completed (most likely)
    "68d1cf4a-08a8-4050-bb3e-28ea4d08dd4e"   # 01:01:01 - Failed
)

$JobTimes = @(
    "00:56:32 (Pre-expiry)",
    "01:00:38 (Post-expiry) ⭐",
    "01:01:01 (Failed)"
)

Write-Host "`n📅 Certificate Timeline:" -ForegroundColor Yellow
Write-Host "  Created:  2025-10-31T00:57:18" -ForegroundColor Gray
Write-Host "  Expired:  2025-10-31T00:59:12" -ForegroundColor Red
Write-Host "  Current:  $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')" -ForegroundColor Gray

Write-Host "`n🔄 Jobs to Investigate:" -ForegroundColor Yellow
for ($i = 0; $i -lt $JobIds.Length; $i++) {
    Write-Host "  $($i+1). $($JobTimes[$i]) - $($JobIds[$i])" -ForegroundColor White
}

Write-Host "`n🔍 Analyzing Jobs..." -ForegroundColor Yellow

for ($i = 0; $i -lt $JobIds.Length; $i++) {
    $jobId = $JobIds[$i]
    $jobTime = $JobTimes[$i]
    
    Write-Host "`n--- Job $($i+1): $jobTime ---" -ForegroundColor Cyan
    Write-Host "Job ID: $jobId" -ForegroundColor Gray
    
    try {
        # Get job details
        $job = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $jobId
        
        Write-Host "Status: $($job.Status)" -ForegroundColor $(if($job.Status -eq "Completed") { "Green" } else { "Red" })
        Write-Host "Start Time: $($job.StartTime)" -ForegroundColor Gray
        Write-Host "End Time: $($job.EndTime)" -ForegroundColor Gray
        
        if ($job.EndTime -and $job.StartTime) {
            $duration = $job.EndTime - $job.StartTime
            Write-Host "Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
        }
        
        # Try to get job output
        Write-Host "`n📄 Job Output:" -ForegroundColor Yellow
        try {
            $output = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $jobId
            
            if ($output) {
                Write-Host "Found $($output.Count) output records" -ForegroundColor Green
                
                # Look for certificate-related output
                $certOutput = $output | Where-Object { $_.Summary -like "*$CertificateName*" -or $_.Summary -like "*cert*" -or $_.Summary -like "*renew*" }
                
                if ($certOutput) {
                    Write-Host "🎯 Certificate-related output found!" -ForegroundColor Green
                    $certOutput | ForEach-Object {
                        Write-Host "  - $($_.Summary)" -ForegroundColor White
                    }
                } else {
                    Write-Host "No specific certificate output found in summaries" -ForegroundColor Yellow
                    
                    # Show first few outputs
                    Write-Host "First few output summaries:" -ForegroundColor Gray
                    $output | Select-Object -First 5 | ForEach-Object {
                        Write-Host "  - $($_.Summary)" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "No output records found" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "❌ Could not retrieve job output: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Try to get job streams (more detailed)
        Write-Host "`n📊 Job Streams:" -ForegroundColor Yellow
        try {
            $streams = @("Output", "Warning", "Error", "Verbose")
            
            foreach ($streamType in $streams) {
                $streamRecords = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $jobId -Stream $streamType
                
                if ($streamRecords) {
                    Write-Host "$streamType Stream: $($streamRecords.Count) records" -ForegroundColor White
                    
                    # Look for certificate mentions
                    $certRecords = $streamRecords | Where-Object { $_.Summary -like "*$CertificateName*" -or $_.Summary -like "*cert*" }
                    if ($certRecords) {
                        Write-Host "  🎯 Certificate mentions:" -ForegroundColor Green
                        $certRecords | Select-Object -First 3 | ForEach-Object {
                            Write-Host "    - $($_.Summary)" -ForegroundColor White
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "Could not retrieve job streams: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Host "❌ Error getting job details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎯 Analysis Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
Write-Host "1. Job at 00:56:32 - Likely routine monitoring (before cert expired)" -ForegroundColor White
Write-Host "2. Job at 01:00:38 - ⭐ MOST LIKELY processed your expired certificate" -ForegroundColor Yellow
Write-Host "3. Job at 01:01:01 - Failed immediately (possible retry or different trigger)" -ForegroundColor White

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Check Azure Portal → Automation Account → Jobs for detailed logs" -ForegroundColor White
Write-Host "2. Look at Log Analytics for certificate events" -ForegroundColor White
Write-Host "3. Check Key Vault for new certificate versions" -ForegroundColor White

Write-Host "`n💡 Portal Investigation:" -ForegroundColor Yellow
Write-Host "Go to: Azure Portal → Resource Groups → $ResourceGroupName → $AutomationAccountName → Jobs" -ForegroundColor Gray
Write-Host "Click on job: be4a8c0b-a020-4c7b-a0f9-154ccc1c8e7c (01:00:38)" -ForegroundColor Gray
Write-Host "Look for: Output, All Logs, and Exception details" -ForegroundColor Gray