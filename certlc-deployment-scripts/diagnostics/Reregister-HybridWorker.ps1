# Hybrid Runbook Worker Re-registration Script
# Use this script when service restart doesn't resolve connectivity issues

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = "ca01",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-certlc-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "certlc-automation-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$HybridWorkerGroupName = "EnterpriseRootCA",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Remove", "Register", "Full")]
    [string]$Action = "Full",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hybrid Runbook Worker Re-registration" -ForegroundColor Cyan
Write-Host "Target: $ComputerName" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

function Connect-ToAzure {
    Write-Host "`n🔐 Connecting to Azure..." -ForegroundColor Yellow
    
    try {
        # Try to get current context
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
            Write-Host "Connecting to Azure subscription: $SubscriptionId" -ForegroundColor Cyan
            Connect-AzAccount -SubscriptionId $SubscriptionId
        } else {
            Write-Host "✅ Already connected to Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to connect to Azure: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-ExistingRegistration {
    Write-Host "`n🗑️ Removing existing Hybrid Worker registration..." -ForegroundColor Yellow
    
    try {
        # Remove from Azure
        Write-Host "Removing worker from Azure Automation..." -ForegroundColor Cyan
        $workers = Get-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName -ErrorAction SilentlyContinue
        
        foreach ($worker in $workers) {
            if ($worker.Name -like "*$ComputerName*" -or $Force) {
                Write-Host "Removing worker: $($worker.Name)" -ForegroundColor Yellow
                Remove-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName -Name $worker.Name -Force
                Write-Host "✅ Removed worker: $($worker.Name)" -ForegroundColor Green
            }
        }
        
        # Clean up local files on the server
        Write-Host "`nCleaning up local Hybrid Worker files..." -ForegroundColor Cyan
        $cleanupResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                # Stop services first
                Stop-Service -Name "Microsoft Monitoring Agent" -Force -ErrorAction SilentlyContinue
                Stop-Service -Name "HealthService" -Force -ErrorAction SilentlyContinue
                
                # Clean up local files
                $cleanupPaths = @(
                    "C:\Program Files\Microsoft Monitoring Agent\Agent\WorkerCache",
                    "C:\ProgramData\Microsoft\System Center\Orchestrator",
                    "C:\Windows\Temp\HybridWorker*"
                )
                
                foreach ($path in $cleanupPaths) {
                    if (Test-Path $path) {
                        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Output "Cleaned: $path"
                    }
                }
                
                # Clean registry entries
                $regPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker",
                    "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager"
                )
                
                foreach ($regPath in $regPaths) {
                    if (Test-Path $regPath) {
                        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Output "Cleaned registry: $regPath"
                    }
                }
                
                return "SUCCESS"
            }
            catch {
                return "ERROR: $($_.Exception.Message)"
            }
        }
        
        Write-Host "Cleanup result: $cleanupResult" -ForegroundColor $(if ($cleanupResult -eq "SUCCESS") { "Green" } else { "Red" })
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to remove existing registration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Register-HybridWorker {
    Write-Host "`n🔧 Registering new Hybrid Worker..." -ForegroundColor Yellow
    
    try {
        # Get Automation Account details
        Write-Host "Getting Automation Account details..." -ForegroundColor Cyan
        $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
        
        if (-not $automationAccount) {
            Write-Host "❌ Automation Account not found!" -ForegroundColor Red
            return $false
        }
        
        # Get registration info
        $regInfo = Get-AzAutomationRegistrationInfo -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
        $primaryKey = $regInfo.PrimaryKey
        $endpoint = $regInfo.Endpoint
        
        Write-Host "✅ Retrieved registration information" -ForegroundColor Green
        Write-Host "Endpoint: $endpoint" -ForegroundColor Gray
        
        # Install/Configure Hybrid Worker on the server
        Write-Host "`nConfiguring Hybrid Worker on $ComputerName..." -ForegroundColor Cyan
        $registrationResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($EndpointUri, $PrimaryKey, $WorkerGroupName)
            
            try {
                # Import the Hybrid Worker module
                Import-Module HybridRunbookWorker -Force -ErrorAction SilentlyContinue
                
                # Register the worker
                Add-HybridRunbookWorker -GroupName $WorkerGroupName -EndPoint $EndpointUri -Token $PrimaryKey -Verbose
                
                # Start the services
                Start-Service -Name "HealthService" -ErrorAction SilentlyContinue
                Start-Service -Name "Microsoft Monitoring Agent" -ErrorAction SilentlyContinue
                
                return "SUCCESS"
            }
            catch {
                return "ERROR: $($_.Exception.Message)"
            }
        } -ArgumentList $endpoint, $primaryKey, $HybridWorkerGroupName
        
        Write-Host "Registration result: $registrationResult" -ForegroundColor $(if ($registrationResult -eq "SUCCESS") { "Green" } else { "Red" })
        
        if ($registrationResult -eq "SUCCESS") {
            Write-Host "`n⏳ Waiting for worker to appear online..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            
            # Verify registration
            $workers = Get-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName
            $newWorker = $workers | Where-Object { $_.Name -like "*$ComputerName*" }
            
            if ($newWorker) {
                Write-Host "✅ Worker successfully registered!" -ForegroundColor Green
                Write-Host "Worker Name: $($newWorker.Name)" -ForegroundColor White
                Write-Host "Worker IP: $($newWorker.IpAddress)" -ForegroundColor White
                Write-Host "Last Seen: $($newWorker.LastSeenDateTime)" -ForegroundColor White
                return $true
            } else {
                Write-Host "⚠️ Worker registered but not visible yet. Check in a few minutes." -ForegroundColor Yellow
                return $true
            }
        } else {
            return $false
        }
    }
    catch {
        Write-Host "❌ Failed to register Hybrid Worker: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-HybridWorkerConnectivity {
    Write-Host "`n🧪 Testing Hybrid Worker connectivity..." -ForegroundColor Yellow
    
    try {
        # Test from the server
        $testResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                # Test Azure Automation endpoints
                $endpoints = @(
                    "https://management.azure.com",
                    "https://eus2-agentservice-prod-1.azure-automation.net",
                    "https://eus2-jrds-prod-1.azure-automation.net"
                )
                
                $results = @()
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
            }
            catch {
                return @("ERROR: $($_.Exception.Message)")
            }
        }
        
        Write-Host "`n🌐 Connectivity Test Results:" -ForegroundColor White
        foreach ($result in $testResult) {
            $color = if ($result.StartsWith("✅")) { "Green" } elseif ($result.StartsWith("❌")) { "Red" } else { "Yellow" }
            Write-Host $result -ForegroundColor $color
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
try {
    # Connect to Azure
    if (-not (Connect-ToAzure)) {
        exit 1
    }
    
    switch ($Action) {
        "Remove" {
            Remove-ExistingRegistration
        }
        "Register" {
            Register-HybridWorker
            Test-HybridWorkerConnectivity
        }
        "Full" {
            Write-Host "`n🔄 Performing full re-registration..." -ForegroundColor Cyan
            
            if (Remove-ExistingRegistration) {
                Write-Host "`n⏳ Waiting before re-registration..." -ForegroundColor Yellow
                Start-Sleep -Seconds 15
                
                if (Register-HybridWorker) {
                    Test-HybridWorkerConnectivity
                    Write-Host "`n✅ Full re-registration completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "`n❌ Re-registration failed!" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "`n❌ Failed to remove existing registration!" -ForegroundColor Red
                exit 1
            }
        }
    }
    
    Write-Host "`n🎉 Operation completed successfully!" -ForegroundColor Green
    
    # Show final status
    Write-Host "`n📊 Final Status Check:" -ForegroundColor Cyan
    $workers = Get-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName
    
    if ($workers) {
        foreach ($worker in $workers) {
            Write-Host "Worker: $($worker.Name)" -ForegroundColor White
            Write-Host "  IP: $($worker.IpAddress)" -ForegroundColor Gray
            Write-Host "  Last Seen: $($worker.LastSeenDateTime)" -ForegroundColor Gray
        }
    } else {
        Write-Host "No workers found in group: $HybridWorkerGroupName" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Full re-registration: .\Reregister-HybridWorker.ps1 -Action Full" -ForegroundColor White
Write-Host "Remove only:          .\Reregister-HybridWorker.ps1 -Action Remove" -ForegroundColor White
Write-Host "Register only:        .\Reregister-HybridWorker.ps1 -Action Register" -ForegroundColor White
Write-Host "Force removal:        .\Reregister-HybridWorker.ps1 -Action Remove -Force" -ForegroundColor White