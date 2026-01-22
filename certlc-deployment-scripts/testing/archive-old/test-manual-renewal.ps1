# Quick Manual Renewal Test
# Tests if the renewal system works when triggered manually

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

$KeyVaultName = $config['KEY_VAULT_NAME']
$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']
$CertificateName = "democert-shortlived"

Write-Host "🔧 Manual Renewal Test" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Gray

# Step 1: Check if runbook exists
Write-Host "1. Checking if CertLifeCycleMgmt runbook exists..." -ForegroundColor Yellow
try {
    $runbook = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "CertLifeCycleMgmt" -ErrorAction Stop
    Write-Host "   ✅ Runbook found and status: $($runbook.State)" -ForegroundColor Green
    
    if ($runbook.State -eq "Published") {
        # Step 2: Try manual trigger
        Write-Host "`n2. Attempting manual runbook trigger..." -ForegroundColor Yellow
        try {
            $job = Start-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "CertLifeCycleMgmt" -ErrorAction Stop
            Write-Host "   ✅ Runbook started successfully!" -ForegroundColor Green
            Write-Host "   📋 Job ID: $($job.JobId)" -ForegroundColor Gray
            
            Write-Host "`n⏳ Waiting for job to complete (this may take 2-5 minutes)..." -ForegroundColor Yellow
            
            # Monitor job progress
            do {
                Start-Sleep -Seconds 15
                $jobStatus = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -JobId $job.JobId
                Write-Host "   📊 Job Status: $($jobStatus.Status)" -ForegroundColor Gray
            } while ($jobStatus.Status -eq "Running" -or $jobStatus.Status -eq "Queued")
            
            Write-Host "`n📋 Final Job Status: $($jobStatus.Status)" -ForegroundColor $(if ($jobStatus.Status -eq "Completed") { "Green" } else { "Red" })
            
            if ($jobStatus.Status -eq "Completed") {
                Write-Host "   ✅ Manual renewal completed successfully!" -ForegroundColor Green
                
                # Check if certificate was renewed
                Write-Host "`n3. Checking if certificate was renewed..." -ForegroundColor Yellow
                try {
                    $renewedCert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction Stop
                    Write-Host "   🔑 Current Thumbprint: $($renewedCert.Thumbprint)" -ForegroundColor Gray
                    Write-Host "   ⏰ Current Expiry: $($renewedCert.Expires)" -ForegroundColor Gray
                    
                    if ($renewedCert.Expires -gt (Get-Date).AddDays(1)) {
                        Write-Host "   ✅ Certificate has been renewed with new expiry date!" -ForegroundColor Green
                    } else {
                        Write-Host "   ⚠️  Certificate expiry date hasn't changed significantly" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "   ❌ Could not verify certificate renewal: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "   ❌ Manual renewal failed!" -ForegroundColor Red
                
                # Get job output for debugging
                try {
                    $jobOutput = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -JobId $job.JobId -Stream "Error"
                    if ($jobOutput) {
                        Write-Host "`n📋 Error Details:" -ForegroundColor Red
                        foreach ($output in $jobOutput) {
                            Write-Host "   $($output.Summary)" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Host "   ⚠️  Could not retrieve job error details" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host "   ❌ Failed to start runbook: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Runbook is not published (Status: $($runbook.State))" -ForegroundColor Red
        Write-Host "   💡 Runbook needs to be published for automation to work" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ CertLifeCycleMgmt runbook not found!" -ForegroundColor Red
    Write-Host "   💡 This explains why automatic renewal didn't work" -ForegroundColor Yellow
    Write-Host "   🔧 The runbook needs to be created and configured" -ForegroundColor Gray
}

Write-Host "`n💡 What this tells us:" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Gray

if ($runbook -and $runbook.State -eq "Published") {
    Write-Host "✅ Runbook exists and is properly configured" -ForegroundColor Green
    Write-Host "❓ Issue is likely with Event Grid triggering or certificate tags" -ForegroundColor Yellow
} else {
    Write-Host "❌ Runbook is missing or not published" -ForegroundColor Red
    Write-Host "💡 This is why automatic renewal didn't happen" -ForegroundColor Yellow
    Write-Host "🔧 Need to deploy the full automation infrastructure" -ForegroundColor Gray
}

Write-Host "`n🚀 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run the full diagnosis: .\diagnose-renewal-failure.ps1" -ForegroundColor White
Write-Host "2. Check if all automation components are deployed" -ForegroundColor White
Write-Host "3. Verify Event Grid → Automation Account integration" -ForegroundColor White