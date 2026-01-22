# Test Hybrid Worker via Jump Host Script
# Use this to verify HRW is working through dc01 jump host

param(
    [Parameter(Mandatory=$false)]
    [string]$JumpHost = "dc01",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetHost = "ca01",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AutomationAccountName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$HybridWorkerGroupName = "EnterpriseRootCA",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Quick", "ConnectivityOnly", "ServiceCheck")]
    [string]$TestType = "Quick",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "../.env"
)

# Load configuration from .env file
Import-Module "$PSScriptRoot/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath $ConfigFile

if ($config) {
    # Use values from .env file if not provided as parameters
    if ([string]::IsNullOrEmpty($SubscriptionId)) { $SubscriptionId = $config['SUBSCRIPTION_ID'] }
    if ([string]::IsNullOrEmpty($ResourceGroupName)) { $ResourceGroupName = $config['RESOURCE_GROUP'] }
    if ([string]::IsNullOrEmpty($AutomationAccountName)) { $AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME'] }
} else {
    Write-Host "❌ Failed to load configuration. Using default/provided values." -ForegroundColor Red
    # Set defaults if config failed and no parameters provided
    if ([string]::IsNullOrEmpty($SubscriptionId)) { $SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0" }
    if ([string]::IsNullOrEmpty($ResourceGroupName)) { $ResourceGroupName = "rg-demo-certlc" }
    if ([string]::IsNullOrEmpty($AutomationAccountName)) { $AutomationAccountName = "DEMO-AA-1030164500" }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hybrid Worker Verification (Jump Host)" -ForegroundColor Cyan
Write-Host "Jump Host: $JumpHost" -ForegroundColor Cyan
Write-Host "Target: $TargetHost" -ForegroundColor Cyan
Write-Host "Test Type: $TestType" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Automation Account: $AutomationAccountName" -ForegroundColor Cyan
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

function Test-JumpHostConnectivity {
    param([string]$JumpServer, [string]$TargetServer)
    
    Write-Host "`n🔍 Testing jump host connectivity..." -ForegroundColor Yellow
    
    try {
        # Test jump host
        if (Test-Connection -ComputerName $JumpServer -Count 2 -Quiet) {
            Write-Host "✅ Jump host ($JumpServer) reachable" -ForegroundColor Green
        } else {
            Write-Host "❌ Jump host ($JumpServer) not reachable" -ForegroundColor Red
            return $false
        }
        
        # Test PowerShell remoting to jump host
        $jumpSession = New-PSSession -ComputerName $JumpServer -ErrorAction SilentlyContinue
        if (-not $jumpSession) {
            Write-Host "❌ PowerShell remoting to jump host failed" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ PowerShell remoting to jump host works" -ForegroundColor Green
        
        # Test target from jump host
        $targetReachable = Invoke-Command -Session $jumpSession -ScriptBlock {
            param($target)
            Test-Connection -ComputerName $target -Count 2 -Quiet
        } -ArgumentList $TargetServer
        
        if ($targetReachable) {
            Write-Host "✅ Target ($TargetServer) reachable from jump host" -ForegroundColor Green
        } else {
            Write-Host "❌ Target ($TargetServer) not reachable from jump host" -ForegroundColor Red
        }
        
        # Test PowerShell remoting from jump host to target
        $targetPSRemoting = Invoke-Command -Session $jumpSession -ScriptBlock {
            param($target)
            try {
                $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                if ($targetSession) {
                    Remove-PSSession $targetSession
                    return $true
                }
                return $false
            }
            catch {
                return $false
            }
        } -ArgumentList $TargetServer
        
        if ($targetPSRemoting) {
            Write-Host "✅ PowerShell remoting from jump host to target works" -ForegroundColor Green
        } else {
            Write-Host "❌ PowerShell remoting from jump host to target failed" -ForegroundColor Red
        }
        
        Remove-PSSession $jumpSession
        return $targetReachable -and $targetPSRemoting
    }
    catch {
        Write-Host "❌ Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-HybridWorkerStatusViaJump {
    param([string]$JumpServer, [string]$TargetServer)
    
    Write-Host "`n🔍 Checking Hybrid Worker status via jump host..." -ForegroundColor Yellow
    
    try {
        # First check Azure side
        Write-Host "Checking Azure Automation status..." -ForegroundColor Cyan
        $workers = Get-AzAutomationHybridRunbookWorker -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -HybridRunbookWorkerGroupName $HybridWorkerGroupName -ErrorAction SilentlyContinue
        
        if (-not $workers) {
            Write-Host "❌ No workers found in Azure!" -ForegroundColor Red
            return $false
        }
        
        Write-Host "`n👥 Workers in Azure:" -ForegroundColor White
        $onlineWorkers = 0
        foreach ($worker in $workers) {
            $lastSeen = $worker.LastSeenDateTime
            $isRecent = $lastSeen -gt (Get-Date).AddMinutes(-10)
            $status = if ($isRecent) { "✅ ONLINE" } else { "❌ OFFLINE" }
            $color = if ($isRecent) { "Green" } else { "Red" }
            
            Write-Host "$status Worker: $($worker.Name)" -ForegroundColor $color
            Write-Host "      IP: $($worker.IpAddress)" -ForegroundColor Gray
            Write-Host "      Last Seen: $lastSeen" -ForegroundColor Gray
            
            if ($isRecent) { $onlineWorkers++ }
        }
        
        # Now check services on target server via jump host
        Write-Host "`nChecking services on target server via jump host..." -ForegroundColor Cyan
        $jumpSession = New-PSSession -ComputerName $JumpServer
        
        $serviceStatus = Invoke-Command -Session $jumpSession -ScriptBlock {
            param($target)
            try {
                $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                if ($targetSession) {
                    $services = Invoke-Command -Session $targetSession -ScriptBlock {
                        $hybridServices = Get-Service | Where-Object {
                            $_.Name -like "*Hybrid*" -or 
                            $_.Name -like "*Monitoring*" -or 
                            $_.Name -like "*Health*"
                        }
                        
                        $result = @()
                        foreach ($service in $hybridServices) {
                            $result += @{
                                Name = $service.Name
                                Status = $service.Status
                                StartType = $service.StartType
                            }
                        }
                        return $result
                    }
                    
                    Remove-PSSession $targetSession
                    return @{
                        Success = $true
                        Services = $services
                    }
                } else {
                    return @{
                        Success = $false
                        Error = "Cannot connect to target"
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $TargetServer
        
        Remove-PSSession $jumpSession
        
        if ($serviceStatus.Success) {
            Write-Host "`n🔧 Services on $TargetServer`:" -ForegroundColor White
            $runningServices = 0
            foreach ($service in $serviceStatus.Services) {
                $status = if ($service.Status -eq "Running") { "✅" } else { "❌" }
                $color = if ($service.Status -eq "Running") { "Green" } else { "Red" }
                Write-Host "$status $($service.Name): $($service.Status)" -ForegroundColor $color
                
                if ($service.Status -eq "Running") { $runningServices++ }
            }
            
            # Summary
            Write-Host "`n📊 Summary:" -ForegroundColor White
            Write-Host "Azure Workers Online: $onlineWorkers/$($workers.Count)" -ForegroundColor $(if ($onlineWorkers -gt 0) { "Green" } else { "Red" })
            Write-Host "Target Services Running: $runningServices/$($serviceStatus.Services.Count)" -ForegroundColor $(if ($runningServices -gt 0) { "Green" } else { "Red" })
            
            return ($onlineWorkers -gt 0) -and ($runningServices -gt 0)
        } else {
            Write-Host "❌ Failed to check services: $($serviceStatus.Error)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Status check failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-NetworkConnectivityViaJump {
    param([string]$JumpServer, [string]$TargetServer)
    
    Write-Host "`n🌐 Testing network connectivity from target via jump host..." -ForegroundColor Yellow
    
    try {
        $jumpSession = New-PSSession -ComputerName $JumpServer
        
        $connectivityResults = Invoke-Command -Session $jumpSession -ScriptBlock {
            param($target)
            try {
                $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                if ($targetSession) {
                    $results = Invoke-Command -Session $targetSession -ScriptBlock {
                        $endpoints = @(
                            "https://management.azure.com",
                            "https://eus2-agentservice-prod-1.azure-automation.net",
                            "https://eus2-jrds-prod-1.azure-automation.net"
                        )
                        
                        $testResults = @()
                        foreach ($endpoint in $endpoints) {
                            try {
                                $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10
                                $testResults += "✅ $endpoint - OK ($($response.StatusCode))"
                            }
                            catch {
                                $testResults += "❌ $endpoint - FAILED ($($_.Exception.Message))"
                            }
                        }
                        
                        return $testResults
                    }
                    
                    Remove-PSSession $targetSession
                    return @{
                        Success = $true
                        Results = $results
                    }
                } else {
                    return @{
                        Success = $false
                        Error = "Cannot connect to target"
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $TargetServer
        
        Remove-PSSession $jumpSession
        
        if ($connectivityResults.Success) {
            Write-Host "`n🔍 Connectivity Results from $TargetServer`:" -ForegroundColor White
            $successCount = 0
            foreach ($result in $connectivityResults.Results) {
                $color = if ($result.StartsWith("✅")) { "Green" } else { "Red" }
                Write-Host $result -ForegroundColor $color
                if ($result.StartsWith("✅")) { $successCount++ }
            }
            
            Write-Host "`nConnectivity Summary: $successCount/$($connectivityResults.Results.Count) endpoints accessible" -ForegroundColor $(if ($successCount -gt 0) { "Green" } else { "Red" })
            return $successCount -gt 0
        } else {
            Write-Host "❌ Connectivity test failed: $($connectivityResults.Error)" -ForegroundColor Red
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
            $jumpConnectivity = Test-JumpHostConnectivity -JumpServer $JumpHost -TargetServer $TargetHost
            $networkConnectivity = if ($jumpConnectivity) { Test-NetworkConnectivityViaJump -JumpServer $JumpHost -TargetServer $TargetHost } else { $false }
            $overallSuccess = $jumpConnectivity -and $networkConnectivity
        }
        "ServiceCheck" {
            $jumpConnectivity = Test-JumpHostConnectivity -JumpServer $JumpHost -TargetServer $TargetHost
            $serviceStatus = if ($jumpConnectivity) { Test-HybridWorkerStatusViaJump -JumpServer $JumpHost -TargetServer $TargetHost } else { $false }
            $overallSuccess = $jumpConnectivity -and $serviceStatus
        }
        "Quick" {
            $jumpConnectivity = Test-JumpHostConnectivity -JumpServer $JumpHost -TargetServer $TargetHost
            $serviceStatus = if ($jumpConnectivity) { Test-HybridWorkerStatusViaJump -JumpServer $JumpHost -TargetServer $TargetHost } else { $false }
            $networkConnectivity = if ($jumpConnectivity) { Test-NetworkConnectivityViaJump -JumpServer $JumpHost -TargetServer $TargetHost } else { $false }
            
            $overallSuccess = $jumpConnectivity -and $serviceStatus -and $networkConnectivity
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    if ($overallSuccess) {
        Write-Host "🎉 TESTS PASSED! Connectivity through jump host works!" -ForegroundColor Green
        Write-Host "✅ You can proceed with service restart via jump host" -ForegroundColor Green
    } else {
        Write-Host "❌ TESTS FAILED! Issues found with jump host connectivity" -ForegroundColor Red
        Write-Host "📋 Troubleshooting steps:" -ForegroundColor Yellow
        Write-Host "  1. Verify jump host ($JumpHost) is accessible" -ForegroundColor Yellow
        Write-Host "  2. Ensure PowerShell remoting is enabled on both servers" -ForegroundColor Yellow
        Write-Host "  3. Check firewall and network connectivity" -ForegroundColor Yellow
        Write-Host "  4. Verify credentials and permissions" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Verification failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Quick test:           .\Test-HybridWorker-JumpHost.ps1 -TestType Quick" -ForegroundColor White
Write-Host "Connectivity only:    .\Test-HybridWorker-JumpHost.ps1 -TestType ConnectivityOnly" -ForegroundColor White
Write-Host "Service check only:   .\Test-HybridWorker-JumpHost.ps1 -TestType ServiceCheck" -ForegroundColor White
Write-Host "Custom jump host:     .\Test-HybridWorker-JumpHost.ps1 -JumpHost dc01 -TargetHost ca01" -ForegroundColor White