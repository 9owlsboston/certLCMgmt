#!/usr/bin/env pwsh

# SSH-based Hybrid Worker Service Manager for Certificate Lifecycle Management
# Manages hybrid worker services via SSH PowerShell remoting

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Status", "Start", "Stop", "Restart", "Logs")]
    [string]$Action = "Status",
    
    [Parameter(Mandatory=$false)]
    [string]$JumpHost = "dc01",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetHost = "ca01",
    
    [Parameter(Mandatory=$false)]
    [string]$UserName = "administrator",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyFilePath = "~/.ssh/id_ed25519"
)

# Import configuration loader
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configLoaderPath = Join-Path $scriptDir "Config-Loader.psm1"

if (Test-Path $configLoaderPath) {
    Import-Module $configLoaderPath -Force
    $config = Get-CertLCConfig
    if ($config) {
        Write-Host "✅ Configuration loaded from .env file" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  Config loader not found, using default values" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SSH Hybrid Worker Service Manager" -ForegroundColor Cyan
Write-Host "Jump Host: $JumpHost" -ForegroundColor Cyan
Write-Host "Target: $TargetHost" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
if ($config) {
    Write-Host "Resource Group: $($config['RESOURCE_GROUP'])" -ForegroundColor Cyan
    Write-Host "Automation Account: $($config['AUTOMATION_ACCOUNT_NAME'])" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan

# Function to manage hybrid worker service via SSH
function Invoke-HybridWorkerAction {
    param($Action, $JumpHost, $TargetHost, $UserName, $KeyFilePath)
    
    try {
        $result = Invoke-Command -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
            param($TargetHost, $Action, $UserName, $KeyFilePath)
            
            # Execute on target host via SSH
            $targetResult = Invoke-Command -HostName $TargetHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
                param($Action)
                
                # Define hybrid worker service names
                $hybridWorkerServices = @(
                    "HybridWorkerService",
                    "Microsoft Monitoring Agent",
                    "HealthService",
                    "Azure Automation Hybrid Worker"
                )
                
                $results = @()
                
                switch ($Action) {
                    "Status" {
                        Write-Host "🔍 Checking hybrid worker service status..." -ForegroundColor Yellow
                        
                        foreach ($serviceName in $hybridWorkerServices) {
                            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                            if ($service) {
                                $results += @{
                                    ServiceName = $service.Name
                                    DisplayName = $service.DisplayName
                                    Status = $service.Status.ToString()
                                    StartType = $service.StartType.ToString()
                                }
                                Write-Host "   $($service.Name): $($service.Status)" -ForegroundColor $(if($service.Status -eq 'Running') { 'Green' } else { 'Red' })
                            }
                        }
                        
                        # Check for any service with "hybrid" in the name
                        $hybridServices = Get-Service | Where-Object { $_.Name -like "*hybrid*" -or $_.DisplayName -like "*hybrid*" }
                        foreach ($service in $hybridServices) {
                            if ($service.Name -notin $hybridWorkerServices) {
                                $results += @{
                                    ServiceName = $service.Name
                                    DisplayName = $service.DisplayName
                                    Status = $service.Status.ToString()
                                    StartType = $service.StartType.ToString()
                                }
                                Write-Host "   $($service.Name): $($service.Status)" -ForegroundColor $(if($service.Status -eq 'Running') { 'Green' } else { 'Red' })
                            }
                        }
                        
                        # Check Azure automation related services
                        $azureServices = Get-Service | Where-Object { $_.Name -like "*azure*" -or $_.DisplayName -like "*automation*" }
                        foreach ($service in $azureServices) {
                            $results += @{
                                ServiceName = $service.Name
                                DisplayName = $service.DisplayName
                                Status = $service.Status.ToString()
                                StartType = $service.StartType.ToString()
                            }
                            Write-Host "   $($service.Name): $($service.Status)" -ForegroundColor $(if($service.Status -eq 'Running') { 'Green' } else { 'Red' })
                        }
                    }
                    
                    "Start" {
                        Write-Host "🔄 Starting hybrid worker services..." -ForegroundColor Yellow
                        foreach ($serviceName in $hybridWorkerServices) {
                            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                            if ($service -and $service.Status -ne 'Running') {
                                try {
                                    Start-Service -Name $serviceName -ErrorAction Stop
                                    Write-Host "✅ Started: $serviceName" -ForegroundColor Green
                                    $results += "Started: $serviceName"
                                } catch {
                                    Write-Host "❌ Failed to start $serviceName: $($_.Exception.Message)" -ForegroundColor Red
                                    $results += "Failed to start: $serviceName - $($_.Exception.Message)"
                                }
                            } elseif ($service) {
                                Write-Host "ℹ️  Already running: $serviceName" -ForegroundColor Cyan
                                $results += "Already running: $serviceName"
                            }
                        }
                    }
                    
                    "Stop" {
                        Write-Host "🛑 Stopping hybrid worker services..." -ForegroundColor Yellow
                        foreach ($serviceName in $hybridWorkerServices) {
                            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                            if ($service -and $service.Status -eq 'Running') {
                                try {
                                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                                    Write-Host "✅ Stopped: $serviceName" -ForegroundColor Green
                                    $results += "Stopped: $serviceName"
                                } catch {
                                    Write-Host "❌ Failed to stop $serviceName: $($_.Exception.Message)" -ForegroundColor Red
                                    $results += "Failed to stop: $serviceName - $($_.Exception.Message)"
                                }
                            } elseif ($service) {
                                Write-Host "ℹ️  Already stopped: $serviceName" -ForegroundColor Cyan
                                $results += "Already stopped: $serviceName"
                            }
                        }
                    }
                    
                    "Restart" {
                        Write-Host "🔄 Restarting hybrid worker services..." -ForegroundColor Yellow
                        foreach ($serviceName in $hybridWorkerServices) {
                            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                            if ($service) {
                                try {
                                    Restart-Service -Name $serviceName -Force -ErrorAction Stop
                                    Write-Host "✅ Restarted: $serviceName" -ForegroundColor Green
                                    $results += "Restarted: $serviceName"
                                } catch {
                                    Write-Host "❌ Failed to restart $serviceName: $($_.Exception.Message)" -ForegroundColor Red
                                    $results += "Failed to restart: $serviceName - $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                    
                    "Logs" {
                        Write-Host "📋 Checking hybrid worker logs..." -ForegroundColor Yellow
                        
                        # Check Windows Event Logs
                        $events = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Azure-Automation*'} -MaxEvents 10 -ErrorAction SilentlyContinue
                        if ($events) {
                            Write-Host "Recent Azure Automation events:" -ForegroundColor Cyan
                            foreach ($event in $events) {
                                Write-Host "   $($event.TimeCreated): $($event.LevelDisplayName) - $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))" -ForegroundColor Gray
                                $results += "$($event.TimeCreated): $($event.LevelDisplayName) - $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))"
                            }
                        }
                        
                        # Check for hybrid worker log files
                        $logPaths = @(
                            "C:\Program Files\Microsoft Monitoring Agent\Agent\Logs",
                            "C:\ProgramData\Microsoft\Azure\Automation",
                            "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Azure Automation"
                        )
                        
                        foreach ($logPath in $logPaths) {
                            if (Test-Path $logPath) {
                                $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
                                foreach ($logFile in $logFiles) {
                                    Write-Host "Log file: $($logFile.FullName) (Modified: $($logFile.LastWriteTime))" -ForegroundColor Cyan
                                    $results += "Log file: $($logFile.FullName) (Modified: $($logFile.LastWriteTime))"
                                }
                            }
                        }
                    }
                }
                
                return $results
                
            } -ArgumentList $Action -ErrorAction Stop
            
            return @{
                Success = $true
                Results = $targetResult
                Error = $null
            }
            
        } -ArgumentList $TargetHost, $Action, $UserName, $KeyFilePath -ErrorAction Stop
        
        if ($result.Success) {
            Write-Host "✅ Hybrid worker service action completed!" -ForegroundColor Green
            if ($result.Results) {
                Write-Host "📋 Results:" -ForegroundColor Cyan
                foreach ($item in $result.Results) {
                    if ($item -is [hashtable]) {
                        Write-Host "   Service: $($item.ServiceName) | Status: $($item.Status) | Start Type: $($item.StartType)" -ForegroundColor White
                    } else {
                        Write-Host "   $item" -ForegroundColor White
                    }
                }
            }
        } else {
            Write-Host "❌ Action failed: $($result.Error)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ SSH connection or command execution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Execute the requested action
Write-Host "🔄 Executing action: $Action" -ForegroundColor Yellow
Invoke-HybridWorkerAction -Action $Action -JumpHost $JumpHost -TargetHost $TargetHost -UserName $UserName -KeyFilePath $KeyFilePath

Write-Host "`n✅ Operation completed!" -ForegroundColor Green

Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Check status:         ./Manage-HybridWorker-SSH.ps1 -Action Status" -ForegroundColor White
Write-Host "Start services:       ./Manage-HybridWorker-SSH.ps1 -Action Start" -ForegroundColor White
Write-Host "Stop services:        ./Manage-HybridWorker-SSH.ps1 -Action Stop" -ForegroundColor White
Write-Host "Restart services:     ./Manage-HybridWorker-SSH.ps1 -Action Restart" -ForegroundColor White
Write-Host "View logs:            ./Manage-HybridWorker-SSH.ps1 -Action Logs" -ForegroundColor White