#!/usr/bin/env pwsh

# SSH-based Jump Host Connection Manager for Certificate Lifecycle Management
# Uses SSH PowerShell remoting instead of WSMan for cross-platform compatibility

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Test", "Connect", "Execute", "Info")]
    [string]$Action = "Test",
    
    [Parameter(Mandatory=$false)]
    [string]$JumpHost = "dc01",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetHost = "ca01",
    
    [Parameter(Mandatory=$false)]
    [string]$Command = "",
    
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
        Write-Host "Resource Group: $($config['RESOURCE_GROUP'])" -ForegroundColor Cyan
        Write-Host "Subscription: $($config['SUBSCRIPTION_ID'])" -ForegroundColor Cyan  
        Write-Host "Automation Account: $($config['AUTOMATION_ACCOUNT_NAME'])" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  Config loader not found, using default values" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SSH Jump Host Connection Manager" -ForegroundColor Cyan
Write-Host "Jump Host: $JumpHost" -ForegroundColor Cyan
Write-Host "Target: $TargetHost" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
Write-Host "User: $UserName" -ForegroundColor Cyan
if ($config) {
    Write-Host "Resource Group: $($config['RESOURCE_GROUP'])" -ForegroundColor Cyan
    Write-Host "Automation Account: $($config['AUTOMATION_ACCOUNT_NAME'])" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan

# Function to test SSH connectivity
function Test-SSHConnectivity {
    param($HostName, $UserName, $KeyFilePath)
    
    Write-Host "🔍 Testing SSH connectivity to $HostName..." -ForegroundColor Yellow
    
    try {
        # Test basic SSH connection
        $testResult = Invoke-Command -HostName $HostName -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock { 
            return @{
                ComputerName = $env:COMPUTERNAME
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
                LastBootTime = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
                CurrentTime = Get-Date
            }
        } -ErrorAction Stop
        
        Write-Host "✅ SSH connection to $HostName successful!" -ForegroundColor Green
        Write-Host "   Computer: $($testResult.ComputerName)" -ForegroundColor White
        Write-Host "   PowerShell: $($testResult.PowerShellVersion)" -ForegroundColor White
        Write-Host "   OS Version: $($testResult.OSVersion)" -ForegroundColor White
        Write-Host "   Last Boot: $($testResult.LastBootTime)" -ForegroundColor White
        Write-Host "   Current Time: $($testResult.CurrentTime)" -ForegroundColor White
        
        return $true
    } catch {
        Write-Host "❌ SSH connection to $HostName failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to execute commands via SSH jump host
function Invoke-SSHJumpHostCommand {
    param($JumpHost, $TargetHost, $Command, $UserName, $KeyFilePath)
    
    Write-Host "🔄 Executing command via SSH jump host..." -ForegroundColor Yellow
    Write-Host "   Jump: $JumpHost -> Target: $TargetHost" -ForegroundColor Cyan
    Write-Host "   Command: $Command" -ForegroundColor Cyan
    
    try {
        # First hop: Connect to jump host and execute command on target
        $result = Invoke-Command -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
            param($TargetHost, $Command, $UserName, $KeyFilePath)
            
            # Second hop: From jump host to target host
            try {
                $targetResult = Invoke-Command -HostName $TargetHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
                    param($Command)
                    Invoke-Expression $Command
                } -ArgumentList $Command -ErrorAction Stop
                
                return @{
                    Success = $true
                    Result = $targetResult
                    Error = $null
                }
            } catch {
                return @{
                    Success = $false
                    Result = $null
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $TargetHost, $Command, $UserName, $KeyFilePath -ErrorAction Stop
        
        if ($result.Success) {
            Write-Host "✅ Command executed successfully!" -ForegroundColor Green
            Write-Host "📋 Result:" -ForegroundColor Cyan
            Write-Output $result.Result
        } else {
            Write-Host "❌ Command failed on target host: $($result.Error)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ SSH jump host command failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to get system information
function Get-SystemInfo {
    param($HostName, $UserName, $KeyFilePath)
    
    Write-Host "🔍 Gathering system information from $HostName..." -ForegroundColor Yellow
    
    try {
        $info = Invoke-Command -HostName $HostName -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
            $os = Get-WmiObject Win32_OperatingSystem
            $cs = Get-WmiObject Win32_ComputerSystem
            $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
            $memory = [Math]::Round(($os.TotalVisibleMemorySize / 1MB), 2)
            $freeMemory = [Math]::Round(($os.FreePhysicalMemory / 1MB), 2)
            
            return @{
                ComputerName = $env:COMPUTERNAME
                Domain = $cs.Domain
                OSName = $os.Caption
                OSVersion = $os.Version
                OSArchitecture = $os.OSArchitecture
                LastBootTime = $os.ConvertToDateTime($os.LastBootUpTime)
                TotalMemoryGB = $memory
                FreeMemoryGB = $freeMemory
                CPUName = $cpu.Name
                CPUCores = $cpu.NumberOfCores
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                Services = @(Get-Service | Where-Object { $_.Name -like "*hybrid*" -or $_.Name -like "*ssh*" } | ForEach-Object { "$($_.Name): $($_.Status)" })
            }
        } -ErrorAction Stop
        
        Write-Host "✅ System information retrieved!" -ForegroundColor Green
        Write-Host "📋 System Details:" -ForegroundColor Cyan
        Write-Host "   Computer: $($info.ComputerName)" -ForegroundColor White
        Write-Host "   Domain: $($info.Domain)" -ForegroundColor White
        Write-Host "   OS: $($info.OSName)" -ForegroundColor White
        Write-Host "   Version: $($info.OSVersion)" -ForegroundColor White
        Write-Host "   Architecture: $($info.OSArchitecture)" -ForegroundColor White
        Write-Host "   Last Boot: $($info.LastBootTime)" -ForegroundColor White
        Write-Host "   Memory: $($info.FreeMemoryGB)GB free / $($info.TotalMemoryGB)GB total" -ForegroundColor White
        Write-Host "   CPU: $($info.CPUName) ($($info.CPUCores) cores)" -ForegroundColor White
        Write-Host "   PowerShell: $($info.PowerShellVersion)" -ForegroundColor White
        Write-Host "   Relevant Services:" -ForegroundColor White
        foreach ($service in $info.Services) {
            Write-Host "     $service" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "❌ Failed to get system info: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main action execution
switch ($Action) {
    "Test" {
        Write-Host "🔍 Testing SSH connectivity..." -ForegroundColor Yellow
        
        # Test jump host
        Write-Host "`nTesting jump host ($JumpHost)..." -ForegroundColor Cyan
        $jumpHostResult = Test-SSHConnectivity -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath
        
        # Test target host via jump host
        if ($jumpHostResult) {
            Write-Host "`nTesting target host ($TargetHost) via jump host..." -ForegroundColor Cyan
            try {
                $targetResult = Invoke-Command -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
                    param($TargetHost, $UserName, $KeyFilePath)
                    try {
                        $result = Invoke-Command -HostName $TargetHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock { 
                            return $env:COMPUTERNAME 
                        } -ErrorAction Stop
                        return @{ Success = $true; ComputerName = $result }
                    } catch {
                        return @{ Success = $false; Error = $_.Exception.Message }
                    }
                } -ArgumentList $TargetHost, $UserName, $KeyFilePath
                
                if ($targetResult.Success) {
                    Write-Host "✅ Target host connection successful: $($targetResult.ComputerName)" -ForegroundColor Green
                } else {
                    Write-Host "❌ Target host connection failed: $($targetResult.Error)" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ Failed to test target host: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    "Connect" {
        Write-Host "🔗 Starting interactive SSH session to $JumpHost..." -ForegroundColor Yellow
        Write-Host "💡 Use 'exit' to close the session" -ForegroundColor Cyan
        Enter-PSSession -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath
    }
    
    "Execute" {
        if ([string]::IsNullOrEmpty($Command)) {
            Write-Host "❌ No command specified. Use -Command parameter." -ForegroundColor Red
            return
        }
        Invoke-SSHJumpHostCommand -JumpHost $JumpHost -TargetHost $TargetHost -Command $Command -UserName $UserName -KeyFilePath $KeyFilePath
    }
    
    "Info" {
        Write-Host "📊 Gathering information..." -ForegroundColor Yellow
        Write-Host "`n🖥️  Jump Host Information:" -ForegroundColor Cyan
        Get-SystemInfo -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath
        
        Write-Host "`n🖥️  Target Host Information:" -ForegroundColor Cyan
        # Get target info via jump host
        try {
            Invoke-Command -HostName $JumpHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
                param($TargetHost, $UserName, $KeyFilePath)
                
                $info = Invoke-Command -HostName $TargetHost -UserName $UserName -KeyFilePath $KeyFilePath -ScriptBlock {
                    $os = Get-WmiObject Win32_OperatingSystem
                    $cs = Get-WmiObject Win32_ComputerSystem
                    
                    return @{
                        ComputerName = $env:COMPUTERNAME
                        Domain = $cs.Domain
                        OSName = $os.Caption
                        LastBootTime = $os.ConvertToDateTime($os.LastBootUpTime)
                        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                        HybridWorkerServices = @(Get-Service | Where-Object { $_.Name -like "*hybrid*" } | ForEach-Object { "$($_.Name): $($_.Status)" })
                    }
                }
                
                Write-Host "✅ Target host information:" -ForegroundColor Green
                Write-Host "   Computer: $($info.ComputerName)" -ForegroundColor White
                Write-Host "   Domain: $($info.Domain)" -ForegroundColor White
                Write-Host "   OS: $($info.OSName)" -ForegroundColor White
                Write-Host "   Last Boot: $($info.LastBootTime)" -ForegroundColor White
                Write-Host "   PowerShell: $($info.PowerShellVersion)" -ForegroundColor White
                Write-Host "   Hybrid Worker Services:" -ForegroundColor White
                foreach ($service in $info.HybridWorkerServices) {
                    Write-Host "     $service" -ForegroundColor Gray
                }
                
            } -ArgumentList $TargetHost, $UserName, $KeyFilePath
        } catch {
            Write-Host "❌ Failed to get target host info: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n✅ Operation completed!" -ForegroundColor Green

Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Test connectivity:    ./Connect-ViaSSH.ps1 -Action Test" -ForegroundColor White
Write-Host "Connect interactively: ./Connect-ViaSSH.ps1 -Action Connect" -ForegroundColor White
Write-Host "Execute command:      ./Connect-ViaSSH.ps1 -Action Execute -Command 'Get-Service'" -ForegroundColor White
Write-Host "Get server info:      ./Connect-ViaSSH.ps1 -Action Info" -ForegroundColor White
Write-Host "Custom servers:       ./Connect-ViaSSH.ps1 -JumpHost dc01 -TargetHost ca01 -Action Test" -ForegroundColor White