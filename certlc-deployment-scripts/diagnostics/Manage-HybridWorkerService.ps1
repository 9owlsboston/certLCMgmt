# Hybrid Runbook Worker Service Management Scripts
# Use these scripts to check, restart, and manage the Hybrid Worker service on ca01

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = "ca01",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Check", "Restart", "Start", "Stop", "Status")]
    [string]$Action = "Check",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Hybrid Worker service names
$HybridWorkerServices = @(
    "Hybrid Worker Service",
    "Microsoft Monitoring Agent",
    "HealthService",
    "Azure Connected Machine Agent"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Hybrid Runbook Worker Service Manager" -ForegroundColor Cyan
Write-Host "Target: $ComputerName" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Test-ServerConnectivity {
    param([string]$Computer)
    
    Write-Host "`n🔍 Testing connectivity to $Computer..." -ForegroundColor Yellow
    
    try {
        if (Test-Connection -ComputerName $Computer -Count 2 -Quiet) {
            Write-Host "✅ Network connectivity: OK" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Network connectivity: FAILED" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Network connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-HybridWorkerServiceStatus {
    param([string]$Computer)
    
    Write-Host "`n🔍 Checking Hybrid Worker services on $Computer..." -ForegroundColor Yellow
    
    try {
        # Get all relevant services
        $services = Get-WmiObject -Class Win32_Service -ComputerName $Computer | Where-Object {
            $_.Name -like "*Hybrid*" -or 
            $_.Name -like "*Monitoring*" -or 
            $_.Name -like "*Health*" -or
            $_.Name -like "*Connected*"
        }
        
        if ($services) {
            Write-Host "`n📋 Service Status Report:" -ForegroundColor White
            foreach ($service in $services) {
                $status = if ($service.State -eq "Running") { "✅" } else { "❌" }
                $startup = $service.StartMode
                Write-Host "$status $($service.Name): $($service.State) (Startup: $startup)" -ForegroundColor $(if ($service.State -eq "Running") { "Green" } else { "Red" })
                
                if ($Detailed) {
                    Write-Host "   Path: $($service.PathName)" -ForegroundColor Gray
                    Write-Host "   PID: $($service.ProcessId)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "❌ No Hybrid Worker services found!" -ForegroundColor Red
        }
        
        return $services
    }
    catch {
        Write-Host "❌ Failed to get service status: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Restart-HybridWorkerServices {
    param([string]$Computer)
    
    Write-Host "`n🔄 Restarting Hybrid Worker services on $Computer..." -ForegroundColor Yellow
    
    # Services to restart in order
    $ServicesToRestart = @(
        "HealthService",
        "Microsoft Monitoring Agent"
    )
    
    foreach ($serviceName in $ServicesToRestart) {
        try {
            Write-Host "`n🔄 Processing service: $serviceName" -ForegroundColor Cyan
            
            # Stop service
            Write-Host "   Stopping service..." -ForegroundColor Yellow
            $result = Invoke-Command -ComputerName $Computer -ScriptBlock {
                param($sName)
                try {
                    Stop-Service -Name $sName -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 5
                    return "OK"
                } catch {
                    return $_.Exception.Message
                }
            } -ArgumentList $serviceName
            
            if ($result -eq "OK") {
                Write-Host "   ✅ Service stopped" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️ Stop result: $result" -ForegroundColor Yellow
            }
            
            # Start service
            Write-Host "   Starting service..." -ForegroundColor Yellow
            $result = Invoke-Command -ComputerName $Computer -ScriptBlock {
                param($sName)
                try {
                    Start-Service -Name $sName -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    $service = Get-Service -Name $sName -ErrorAction SilentlyContinue
                    return $service.Status
                } catch {
                    return $_.Exception.Message
                }
            } -ArgumentList $serviceName
            
            if ($result -eq "Running") {
                Write-Host "   ✅ Service started successfully" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Start failed: $result" -ForegroundColor Red
            }
            
        }
        catch {
            Write-Host "   ❌ Error with $serviceName`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Get-HybridWorkerLogs {
    param([string]$Computer)
    
    Write-Host "`n📋 Checking recent Hybrid Worker logs..." -ForegroundColor Yellow
    
    try {
        $logs = Invoke-Command -ComputerName $Computer -ScriptBlock {
            # Get recent Application and System events related to Hybrid Worker
            $events = @()
            
            # Application log events
            $appEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                StartTime = (Get-Date).AddHours(-24)
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.ProviderName -like "*Hybrid*" -or 
                $_.ProviderName -like "*Monitoring*" -or
                $_.Message -like "*Hybrid*"
            } | Select-Object -First 10
            
            $events += $appEvents
            
            # System log events
            $sysEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                StartTime = (Get-Date).AddHours(-24)
            } -ErrorAction SilentlyContinue | Where-Object {
                $_.ProviderName -like "*Hybrid*" -or 
                $_.Message -like "*Hybrid*"
            } | Select-Object -First 10
            
            $events += $sysEvents
            
            return $events | Sort-Object TimeCreated -Descending | Select-Object -First 15
        }
        
        if ($logs) {
            Write-Host "`n📋 Recent Hybrid Worker Events (last 24h):" -ForegroundColor White
            foreach ($log in $logs) {
                $level = switch ($log.LevelDisplayName) {
                    "Error" { "❌" }
                    "Warning" { "⚠️" }
                    "Information" { "ℹ️" }
                    default { "📝" }
                }
                Write-Host "$level [$($log.TimeCreated)] $($log.ProviderName): $($log.LevelDisplayName)" -ForegroundColor $(
                    switch ($log.LevelDisplayName) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        default { "White" }
                    }
                )
                if ($Detailed) {
                    Write-Host "   Message: $($log.Message -replace "`n", " " -replace "`r", "")" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "ℹ️ No recent Hybrid Worker events found" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "❌ Failed to retrieve logs: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution logic
try {
    # Test connectivity first
    if (-not (Test-ServerConnectivity -Computer $ComputerName)) {
        Write-Host "`n❌ Cannot connect to $ComputerName. Check network connectivity." -ForegroundColor Red
        exit 1
    }
    
    switch ($Action) {
        "Check" {
            Get-HybridWorkerServiceStatus -Computer $ComputerName
            Get-HybridWorkerLogs -Computer $ComputerName
        }
        "Status" {
            Get-HybridWorkerServiceStatus -Computer $ComputerName
        }
        "Restart" {
            Get-HybridWorkerServiceStatus -Computer $ComputerName
            Restart-HybridWorkerServices -Computer $ComputerName
            Start-Sleep -Seconds 10
            Write-Host "`n🔍 Post-restart status:" -ForegroundColor Cyan
            Get-HybridWorkerServiceStatus -Computer $ComputerName
        }
        "Start" {
            Write-Host "`n🔄 Starting Hybrid Worker services..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                Start-Service -Name "HealthService" -ErrorAction SilentlyContinue
                Start-Service -Name "Microsoft Monitoring Agent" -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 5
            Get-HybridWorkerServiceStatus -Computer $ComputerName
        }
        "Stop" {
            Write-Host "`n🛑 Stopping Hybrid Worker services..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                Stop-Service -Name "Microsoft Monitoring Agent" -Force -ErrorAction SilentlyContinue
                Stop-Service -Name "HealthService" -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 5
            Get-HybridWorkerServiceStatus -Computer $ComputerName
        }
    }
    
    Write-Host "`n✅ Operation completed!" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Check status:     .\Manage-HybridWorkerService.ps1 -Action Check" -ForegroundColor White
Write-Host "Restart services: .\Manage-HybridWorkerService.ps1 -Action Restart" -ForegroundColor White
Write-Host "Detailed check:   .\Manage-HybridWorkerService.ps1 -Action Check -Detailed" -ForegroundColor White
Write-Host "Remote server:    .\Manage-HybridWorkerService.ps1 -ComputerName ca01 -Action Check" -ForegroundColor White