# Simple Real-time Automation Monitor
# Monitors Azure Automation Account for certificate renewal activity

# Embedded configuration (same as threshold script)
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"
$KEY_VAULT_NAME = "DEMO-KV-20251103"

Write-Host "Real-time Certificate Automation Monitor" -ForegroundColor Cyan
Write-Host "Automation Account: $AUTOMATION_ACCOUNT_NAME" -ForegroundColor Yellow
Write-Host "Key Vault: $KEY_VAULT_NAME" -ForegroundColor Yellow
Write-Host "Resource Group: $RESOURCE_GROUP" -ForegroundColor Yellow
Write-Host "Monitoring for certificate renewal activity..." -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try 
{
    # Check authentication
    $context = Get-AzContext
    if (-not $context) 
    {
        Write-Host "Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "Loading Azure PowerShell modules..." -ForegroundColor Yellow
    try {
        Import-Module Az.Automation -Force -ErrorAction SilentlyContinue
        Import-Module Az.KeyVault -Force -ErrorAction SilentlyContinue
        Write-Host "   Azure modules loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "   Some modules may need to be installed" -ForegroundColor Yellow
    }

    Write-Host "MONITORING STARTS - Press Ctrl+C to stop" -ForegroundColor Green
    Write-Host ""

    $iteration = 1
    $lastJobCount = 0
    $lastCertCount = 0

    while ($true) 
    {
        $currentTime = Get-Date
        Write-Host "[$($currentTime.ToString('HH:mm:ss'))] Check #$iteration" -ForegroundColor Cyan

        # 1. Check for recent automation jobs
        try {
            $recentJobs = Get-AzAutomationJob -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP | 
                Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-30) } |
                Sort-Object StartTime -Descending

            if ($recentJobs.Count -ne $lastJobCount) {
                Write-Host "   NEW AUTOMATION ACTIVITY DETECTED!" -ForegroundColor Red
                foreach ($job in $recentJobs | Select-Object -First 3) {
                    $status = switch ($job.Status) {
                        "Running" { "Running" }
                        "Completed" { "Completed" }
                        "Failed" { "Failed" }
                        default { $job.Status }
                    }
                    Write-Host "   - Job: $($job.RunbookName) | Status: $status | Started: $($job.StartTime.ToString('HH:mm:ss'))" -ForegroundColor White
                }
                $lastJobCount = $recentJobs.Count
            } else {
                Write-Host "   Jobs: $($recentJobs.Count) recent jobs (no change)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Could not check automation jobs: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # 2. Check certificate count in Key Vault
        try {
            $certificates = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME
            $certCount = $certificates.Count

            if ($certCount -ne $lastCertCount) {
                Write-Host "   CERTIFICATE CHANGE DETECTED!" -ForegroundColor Red
                Write-Host "   Total certificates: $certCount (was $lastCertCount)" -ForegroundColor White
                
                # Show recent certificates
                $recentCerts = $certificates | Where-Object { $_.Name -like "democert*" } | Sort-Object Created -Descending
                if ($recentCerts) {
                    Write-Host "   Recent test certificates:" -ForegroundColor White
                    foreach ($cert in $recentCerts | Select-Object -First 3) {
                        if ($cert.Certificate) {
                            $timeToExpiry = $cert.Certificate.NotAfter - (Get-Date)
                            Write-Host "   - $($cert.Name) | Expires: $($cert.Certificate.NotAfter.ToString('MM/dd HH:mm')) | Days left: $([math]::Round($timeToExpiry.TotalDays, 1))" -ForegroundColor Gray
                        } else {
                            Write-Host "   - $($cert.Name) | Created: $($cert.Created.ToString('MM/dd HH:mm'))" -ForegroundColor Gray
                        }
                    }
                }
                $lastCertCount = $certCount
            } else {
                Write-Host "   Certificates: $certCount total (no change)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Could not check certificates: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # 3. Check current renewal threshold
        try {
            $threshold = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name "CertRenewalThresholdDays" -ErrorAction SilentlyContinue
            if ($threshold) {
                Write-Host "   Renewal threshold: $($threshold.Value) days" -ForegroundColor Gray
            }
        } catch {
            # Ignore threshold check errors
        }

        Write-Host ""
        
        # Wait 30 seconds before next check
        Start-Sleep -Seconds 30
        $iteration++
    }
} 
catch 
{
    Write-Host ""
    Write-Host "MONITORING FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Monitoring stopped." -ForegroundColor Yellow