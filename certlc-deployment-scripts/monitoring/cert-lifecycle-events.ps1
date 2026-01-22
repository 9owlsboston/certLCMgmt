# Certificate Lifecycle Event Tracker
# This PowerShell script provides detailed event tracking and correlation
# for certificate lifecycle events including Event Grid, Key Vault, and Automation

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateName = "",
    
    [Parameter(Mandatory=$false)]
    [int]$DaysBack = 7,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-ColorOutput $Title -Color Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Get-TimeStatus {
    param([DateTime]$EventTime)
    
    $timeDiff = (Get-Date) - $EventTime
    
    if ($timeDiff.TotalMinutes -lt 5) { return "🔴 Very Recent" }
    elseif ($timeDiff.TotalHours -lt 1) { return "🟡 Recent" }
    elseif ($timeDiff.TotalDays -lt 1) { return "🟢 Today" }
    else { return "⚪ $([math]::Round($timeDiff.TotalDays, 1)) days ago" }
}

# Check Azure login
Write-Header "🔐 Azure Authentication Check"
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-ColorOutput "❌ Not logged into Azure. Please run Connect-AzAccount first." -Color Red
        exit 1
    }
    Write-ColorOutput "✅ Azure Authentication: OK" -Color Green
    Write-ColorOutput "ℹ️ Subscription: $($context.Subscription.Name)" -Color Gray
    Write-ColorOutput "ℹ️ Account: $($context.Account.Id)" -Color Gray
} catch {
    Write-ColorOutput "❌ Error checking Azure context: $($_.Exception.Message)" -Color Red
    exit 1
}

# Auto-discover resources if not provided
Write-Header "🔍 Resource Discovery"

if (-not $ResourceGroupName) {
    Write-ColorOutput "🔍 Discovering resource groups with certificate lifecycle components..." -Color Yellow
    $potentialRGs = Get-AzResourceGroup | Where-Object { 
        $_.ResourceGroupName -like "*certlc*" -or 
        $_.ResourceGroupName -like "*cert*" -or 
        $_.ResourceGroupName -like "*demo*" 
    }
    
    if ($potentialRGs) {
        Write-ColorOutput "📋 Found potential resource groups:" -Color Green
        $potentialRGs | ForEach-Object { Write-Host "  - $($_.ResourceGroupName)" }
        $ResourceGroupName = $potentialRGs[0].ResourceGroupName
        Write-ColorOutput "ℹ️ Using: $ResourceGroupName" -Color Blue
    } else {
        Write-ColorOutput "⚠️ No obvious certificate resource groups found. Please specify -ResourceGroupName" -Color Yellow
        $allRGs = Get-AzResourceGroup | Select-Object -First 10
        Write-ColorOutput "Available resource groups (first 10):" -Color Gray
        $allRGs | ForEach-Object { Write-Host "  - $($_.ResourceGroupName)" }
        return
    }
}

if (-not $AutomationAccountName) {
    Write-ColorOutput "🔍 Discovering Automation Accounts..." -Color Yellow
    $automationAccounts = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($automationAccounts) {
        $AutomationAccountName = $automationAccounts[0].AutomationAccountName
        Write-ColorOutput "ℹ️ Found Automation Account: $AutomationAccountName" -Color Blue
    }
}

if (-not $KeyVaultName) {
    Write-ColorOutput "🔍 Discovering Key Vaults..." -Color Yellow
    $keyVaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($keyVaults) {
        $KeyVaultName = $keyVaults[0].VaultName
        Write-ColorOutput "ℹ️ Found Key Vault: $KeyVaultName" -Color Blue
    }
}

if (-not $CertificateName -and $KeyVaultName) {
    Write-ColorOutput "🔍 Discovering certificates..." -Color Yellow
    try {
        $certificates = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -ErrorAction SilentlyContinue
        if ($certificates) {
            # Prefer demo/test/shortlived certificates
            $demoCert = $certificates | Where-Object { $_.Name -match "(demo|test|shortlived)" } | Select-Object -First 1
            if ($demoCert) {
                $CertificateName = $demoCert.Name
                Write-ColorOutput "ℹ️ Found demo certificate: $CertificateName" -Color Blue
            } else {
                $CertificateName = $certificates[0].Name
                Write-ColorOutput "ℹ️ Using first certificate: $CertificateName" -Color Blue
            }
        }
    } catch {
        Write-ColorOutput "⚠️ Could not list certificates: $($_.Exception.Message)" -Color Yellow
    }
}

# Summary of discovered resources
Write-ColorOutput "`n📊 Configuration Summary:" -Color Cyan
Write-ColorOutput "   Resource Group: $ResourceGroupName" -Color White
Write-ColorOutput "   Automation Account: $AutomationAccountName" -Color White
Write-ColorOutput "   Key Vault: $KeyVaultName" -Color White
Write-ColorOutput "   Certificate: $CertificateName" -Color White
Write-ColorOutput "   Days Back: $DaysBack" -Color White

# Calculate time range
$startTime = (Get-Date).AddDays(-$DaysBack)
$endTime = Get-Date

Write-Header "🔐 Certificate Status and History"

if ($KeyVaultName -and $CertificateName) {
    try {
        $certificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction SilentlyContinue
        
        if ($certificate) {
            Write-ColorOutput "✅ Certificate found: $CertificateName" -Color Green
            Write-ColorOutput "   Created: $($certificate.Created)" -Color Gray
            Write-ColorOutput "   Updated: $($certificate.Updated)" -Color Gray
            Write-ColorOutput "   Expires: $($certificate.Expires)" -Color Gray
            
            # Check expiration status
            if ($certificate.Expires -lt (Get-Date)) {
                Write-ColorOutput "   Status: 🔴 EXPIRED" -Color Red
            } elseif ($certificate.Expires -lt (Get-Date).AddDays(7)) {
                Write-ColorOutput "   Status: 🟡 Expires within 7 days" -Color Yellow
            } else {
                Write-ColorOutput "   Status: 🟢 Valid" -Color Green
            }
            
            # Get certificate versions (renewal history)
            Write-ColorOutput "`n📜 Certificate Version History:" -Color Yellow
            try {
                $versions = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -IncludeVersions
                Write-ColorOutput "   Total versions: $($versions.Count)" -Color Gray
                
                if ($versions.Count -gt 1) {
                    Write-ColorOutput "   Recent versions:" -Color Gray
                    $versions | Sort-Object Created -Descending | Select-Object -First 5 | ForEach-Object {
                        $status = Get-TimeStatus -EventTime $_.Created
                        Write-ColorOutput "   - Version: $($_.Version.Substring(0,8))... Created: $($_.Created) $status" -Color White
                    }
                }
            } catch {
                Write-ColorOutput "   ⚠️ Could not retrieve version history: $($_.Exception.Message)" -Color Yellow
            }
        } else {
            Write-ColorOutput "❌ Certificate '$CertificateName' not found in Key Vault '$KeyVaultName'" -Color Red
        }
    } catch {
        Write-ColorOutput "❌ Error accessing certificate: $($_.Exception.Message)" -Color Red
    }
} else {
    Write-ColorOutput "⚠️ Key Vault or Certificate name not available" -Color Yellow
}

Write-Header "🤖 Automation Account Job Analysis"

if ($AutomationAccountName -and $ResourceGroupName) {
    try {
        Write-ColorOutput "🔍 Analyzing jobs in the last $DaysBack days..." -Color Yellow
        
        # Get jobs with extended filters
        $jobs = Get-AzAutomationJob -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -StartTime $startTime -EndTime $endTime
        
        if ($jobs) {
            Write-ColorOutput "📋 Found $($jobs.Count) jobs in the specified time range" -Color Green
            
            # Group jobs by status
            $jobStats = $jobs | Group-Object Status
            Write-ColorOutput "`n📊 Job Status Summary:" -Color Cyan
            $jobStats | ForEach-Object {
                $color = switch ($_.Name) {
                    "Completed" { "Green" }
                    "Failed" { "Red" }
                    "Running" { "Yellow" }
                    default { "Gray" }
                }
                Write-ColorOutput "   $($_.Name): $($_.Count) jobs" -Color $color
            }
            
            # Show recent jobs
            Write-ColorOutput "`n🕐 Recent Jobs (last 10):" -Color Yellow
            $recentJobs = $jobs | Sort-Object StartTime -Descending | Select-Object -First 10
            
            foreach ($job in $recentJobs) {
                $timeStatus = Get-TimeStatus -EventTime $job.StartTime
                $statusIcon = switch ($job.Status) {
                    "Completed" { "✅" }
                    "Failed" { "❌" }
                    "Running" { "🔄" }
                    default { "⚪" }
                }
                
                Write-ColorOutput "   $statusIcon $($job.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) | $($job.Status) | $($job.RunbookName) | $timeStatus" -Color White
                
                if ($Detailed -and $job.Status -eq "Failed") {
                    Write-ColorOutput "      Job ID: $($job.JobId)" -Color Gray
                    try {
                        $jobOutput = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId -Stream Error
                        if ($jobOutput) {
                            Write-ColorOutput "      Error: $($jobOutput[0].Summary)" -Color Red
                        }
                    } catch {
                        Write-ColorOutput "      Could not retrieve error details" -Color Gray
                    }
                }
            }
            
            # Certificate-related job analysis
            if ($CertificateName) {
                Write-ColorOutput "`n🔍 Certificate-Related Job Analysis:" -Color Yellow
                
                $certJobs = $jobs | Where-Object { 
                    $_.RunbookName -match "(cert|renewal|lifecycle)" -or
                    $_.JobParameters.ContainsKey($CertificateName)
                }
                
                if ($certJobs) {
                    Write-ColorOutput "   Found $($certJobs.Count) certificate-related jobs:" -Color Green
                    
                    foreach ($job in $certJobs | Sort-Object StartTime -Descending) {
                        $timeStatus = Get-TimeStatus -EventTime $job.StartTime
                        Write-ColorOutput "   - $($job.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) | $($job.Status) | $($job.RunbookName) | $timeStatus" -Color White
                        
                        if ($Detailed) {
                            Write-ColorOutput "     Job ID: $($job.JobId)" -Color Gray
                            
                            # Try to get job output
                            try {
                                $jobOutputs = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $job.JobId
                                $certMentions = $jobOutputs | Where-Object { $_.Summary -like "*$CertificateName*" -or $_.Summary -like "*cert*" }
                                
                                if ($certMentions) {
                                    Write-ColorOutput "     🎯 Certificate mentions in output:" -Color Green
                                    $certMentions | Select-Object -First 3 | ForEach-Object {
                                        Write-ColorOutput "       - $($_.Summary)" -Color Gray
                                    }
                                }
                            } catch {
                                Write-ColorOutput "     ⚠️ Could not retrieve job output" -Color Yellow
                            }
                        }
                    }
                } else {
                    Write-ColorOutput "   No specific certificate-related jobs found" -Color Gray
                }
            }
            
            # Failed job analysis
            $failedJobs = $jobs | Where-Object { $_.Status -eq "Failed" }
            if ($failedJobs) {
                Write-ColorOutput "`n❌ Failed Job Analysis:" -Color Red
                Write-ColorOutput "   Found $($failedJobs.Count) failed jobs in the time range" -Color Red
                
                foreach ($failedJob in $failedJobs | Sort-Object StartTime -Descending | Select-Object -First 5) {
                    Write-ColorOutput "   - $($failedJob.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) | $($failedJob.RunbookName)" -Color Red
                    Write-ColorOutput "     Job ID: $($failedJob.JobId)" -Color Gray
                    
                    if ($Detailed) {
                        try {
                            $errorOutput = Get-AzAutomationJobOutput -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Id $failedJob.JobId -Stream Error
                            if ($errorOutput) {
                                Write-ColorOutput "     Error: $($errorOutput[0].Summary)" -Color Red
                            }
                        } catch {
                            Write-ColorOutput "     Could not retrieve error details" -Color Yellow
                        }
                    }
                }
            }
            
        } else {
            Write-ColorOutput "ℹ️ No jobs found in the specified time range" -Color Gray
        }
        
    } catch {
        Write-ColorOutput "❌ Error accessing Automation Account: $($_.Exception.Message)" -Color Red
    }
} else {
    Write-ColorOutput "⚠️ Automation Account or Resource Group not available" -Color Yellow
}

Write-Header "📡 Event Grid and Event Analysis"

if ($ResourceGroupName) {
    try {
        # Check for Event Grid topics
        Write-ColorOutput "🔍 Checking Event Grid configuration..." -Color Yellow
        
        $eventGridTopics = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($eventGridTopics) {
            Write-ColorOutput "   Found $($eventGridTopics.Count) Event Grid topics:" -Color Green
            $eventGridTopics | ForEach-Object {
                Write-ColorOutput "   - $($_.Name)" -Color White
            }
        }
        
        # Check for system topics (Key Vault events)
        $systemTopics = Get-AzEventGridSystemTopic -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($systemTopics) {
            Write-ColorOutput "   Found $($systemTopics.Count) system topics:" -Color Green
            $systemTopics | ForEach-Object {
                Write-ColorOutput "   - $($_.Name) (Type: $($_.TopicType))" -Color White
            }
        }
        
        if (-not $eventGridTopics -and -not $systemTopics) {
            Write-ColorOutput "   ⚠️ No Event Grid topics found" -Color Yellow
        }
        
    } catch {
        Write-ColorOutput "❌ Error checking Event Grid: $($_.Exception.Message)" -Color Red
    }
}

Write-Header "📊 Summary and Recommendations"

Write-ColorOutput "🎯 Quick Actions:" -Color Cyan
if ($KeyVaultName -and $CertificateName) {
    Write-ColorOutput "   1. View certificate in Azure Portal:" -Color White
    Write-ColorOutput "      https://portal.azure.com/#@/resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName/certificates" -Color Blue
}

if ($AutomationAccountName) {
    Write-ColorOutput "   2. View automation jobs:" -Color White
    Write-ColorOutput "      https://portal.azure.com/#@/resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/jobs" -Color Blue
}

Write-ColorOutput "   3. Run detailed analysis:" -Color White
Write-ColorOutput "      .\cert-lifecycle-events.ps1 -ResourceGroupName '$ResourceGroupName' -Detailed" -Color Blue

Write-ColorOutput "`n🔧 Related Tools:" -Color Cyan
Write-ColorOutput "   • ./cert-lifecycle-status.sh - Bash version with deployment checks" -Color Gray
Write-ColorOutput "   • ./investigate-job-output.ps1 - Specific job investigation" -Color Gray
Write-ColorOutput "   • ./diagnose-keyvault.sh - Key Vault diagnostics" -Color Gray

Write-ColorOutput "`n✅ Certificate lifecycle event tracking completed!" -Color Green
Write-ColorOutput "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray