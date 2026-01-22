# Jump Host Connection Script for CA01 via DC01
# Use this script when ca01 is not directly accessible

param(
    [Parameter(Mandatory=$false)]
    [string]$JumpHost = "dc01",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetHost = "ca01",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Test", "Connect", "Execute", "Info")]
    [string]$Action = "Test",
    
    [Parameter(Mandatory=$false)]
    [string]$Command = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableJumpHostPSRemoting,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "../.env"
)

# Load configuration from .env file
Import-Module "$PSScriptRoot/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath $ConfigFile

if (-not $config) {
    Write-Host "❌ Failed to load configuration. Using default values." -ForegroundColor Red
    $config = @{
        'RESOURCE_GROUP' = 'rg-demo-certlc'
        'SUBSCRIPTION_ID' = 'f8c6ec45-4437-4670-80b1-cc3cb09c3ce0'
        'AUTOMATION_ACCOUNT_NAME' = 'DEMO-AA-1030164500'
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Jump Host Connection Manager" -ForegroundColor Cyan
Write-Host "Jump Host: $JumpHost" -ForegroundColor Cyan
Write-Host "Target: $TargetHost" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Cyan
Write-Host "Resource Group: $($config['RESOURCE_GROUP'])" -ForegroundColor Cyan
Write-Host "Subscription: $($config['SUBSCRIPTION_ID'])" -ForegroundColor Cyan
Write-Host "========================================"  -ForegroundColor Cyan

function Test-JumpHostConnectivity {
    param([string]$JumpServer, [string]$TargetServer)
    
    Write-Host "`n🔍 Testing jump host connectivity..." -ForegroundColor Yellow
    
    # Test connectivity to jump host first
    Write-Host "Testing connectivity to jump host ($JumpServer)..." -ForegroundColor Cyan
    try {
        if (Test-Connection -ComputerName $JumpServer -Count 2 -Quiet) {
            Write-Host "✅ Jump host network connectivity: OK" -ForegroundColor Green
        } else {
            Write-Host "❌ Jump host network connectivity: FAILED" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Jump host network test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test PowerShell remoting to jump host
    Write-Host "Testing PowerShell remoting to jump host..." -ForegroundColor Cyan
    try {
        $jumpSession = New-PSSession -ComputerName $JumpServer -ErrorAction SilentlyContinue
        if ($jumpSession) {
            Write-Host "✅ Jump host PowerShell remoting: OK" -ForegroundColor Green
            
            # Test connectivity from jump host to target
            Write-Host "Testing connectivity from jump host to target ($TargetServer)..." -ForegroundColor Cyan
            $targetConnectivity = Invoke-Command -Session $jumpSession -ScriptBlock {
                param($target)
                try {
                    if (Test-Connection -ComputerName $target -Count 2 -Quiet) {
                        return "OK"
                    } else {
                        return "FAILED"
                    }
                }
                catch {
                    return "ERROR: $($_.Exception.Message)"
                }
            } -ArgumentList $TargetServer
            
            if ($targetConnectivity -eq "OK") {
                Write-Host "✅ Jump host to target connectivity: OK" -ForegroundColor Green
            } else {
                Write-Host "❌ Jump host to target connectivity: $targetConnectivity" -ForegroundColor Red
            }
            
            # Test if target allows PowerShell remoting from jump host
            Write-Host "Testing PowerShell remoting from jump host to target..." -ForegroundColor Cyan
            $targetPSRemoting = Invoke-Command -Session $jumpSession -ScriptBlock {
                param($target)
                try {
                    $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                    if ($targetSession) {
                        Remove-PSSession $targetSession
                        return "OK"
                    } else {
                        return "FAILED"
                    }
                }
                catch {
                    return "ERROR: $($_.Exception.Message)"
                }
            } -ArgumentList $TargetServer
            
            if ($targetPSRemoting -eq "OK") {
                Write-Host "✅ Jump host to target PowerShell remoting: OK" -ForegroundColor Green
                $result = $true
            } else {
                Write-Host "❌ Jump host to target PowerShell remoting: $targetPSRemoting" -ForegroundColor Red
                Write-Host "   You may need to enable PSRemoting on $TargetServer" -ForegroundColor Yellow
                $result = "partial"
            }
            
            Remove-PSSession $jumpSession
            return $result
        } else {
            Write-Host "❌ Jump host PowerShell remoting: FAILED" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Jump host PowerShell remoting failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-JumpHostInfo {
    param([string]$JumpServer, [string]$TargetServer)
    
    Write-Host "`n📊 Gathering information via jump host..." -ForegroundColor Yellow
    
    try {
        $jumpSession = New-PSSession -ComputerName $JumpServer
        
        if ($jumpSession) {
            Write-Host "`n🖥️ Jump Host ($JumpServer) Information:" -ForegroundColor White
            $jumpInfo = Invoke-Command -Session $jumpSession -ScriptBlock {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem
                $computer = Get-CimInstance -ClassName Win32_ComputerSystem
                $network = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
                
                return @{
                    ComputerName = $computer.Name
                    Domain = $computer.Domain
                    OS = $os.Caption
                    Version = $os.Version
                    LastBoot = $os.LastBootUpTime
                    TotalMemory = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
                    IPAddresses = ($network | ForEach-Object { $_.IPAddress }) -join ", "
                }
            }
            
            Write-Host "Computer: $($jumpInfo.ComputerName)" -ForegroundColor Gray
            Write-Host "Domain: $($jumpInfo.Domain)" -ForegroundColor Gray
            Write-Host "OS: $($jumpInfo.OS)" -ForegroundColor Gray
            Write-Host "Memory: $($jumpInfo.TotalMemory) GB" -ForegroundColor Gray
            Write-Host "IP Addresses: $($jumpInfo.IPAddresses)" -ForegroundColor Gray
            Write-Host "Last Boot: $($jumpInfo.LastBoot)" -ForegroundColor Gray
            
            # Get target server info through jump host
            Write-Host "`n🖥️ Target Server ($TargetServer) Information (via jump host):" -ForegroundColor White
            $targetInfo = Invoke-Command -Session $jumpSession -ScriptBlock {
                param($target)
                try {
                    $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                    if ($targetSession) {
                        $info = Invoke-Command -Session $targetSession -ScriptBlock {
                            $os = Get-CimInstance -ClassName Win32_OperatingSystem
                            $computer = Get-CimInstance -ClassName Win32_ComputerSystem
                            $network = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
                            
                            # Check key services
                            $services = Get-Service | Where-Object {
                                $_.Name -in @('WinRM', 'HealthService', 'Microsoft Monitoring Agent', 'CertSvc', 'DNS', 'ADWS')
                            }
                            
                            return @{
                                ComputerName = $computer.Name
                                Domain = $computer.Domain
                                OS = $os.Caption
                                Version = $os.Version
                                LastBoot = $os.LastBootUpTime
                                TotalMemory = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
                                IPAddresses = ($network | ForEach-Object { $_.IPAddress }) -join ", "
                                Services = $services | ForEach-Object { "$($_.Name):$($_.Status)" }
                            }
                        }
                        Remove-PSSession $targetSession
                        return $info
                    } else {
                        return @{ Error = "Could not connect to target server" }
                    }
                }
                catch {
                    return @{ Error = $_.Exception.Message }
                }
            } -ArgumentList $TargetServer
            
            if ($targetInfo.Error) {
                Write-Host "❌ Error getting target info: $($targetInfo.Error)" -ForegroundColor Red
            } else {
                Write-Host "Computer: $($targetInfo.ComputerName)" -ForegroundColor Gray
                Write-Host "Domain: $($targetInfo.Domain)" -ForegroundColor Gray
                Write-Host "OS: $($targetInfo.OS)" -ForegroundColor Gray
                Write-Host "Memory: $($targetInfo.TotalMemory) GB" -ForegroundColor Gray
                Write-Host "IP Addresses: $($targetInfo.IPAddresses)" -ForegroundColor Gray
                Write-Host "Last Boot: $($targetInfo.LastBoot)" -ForegroundColor Gray
                
                Write-Host "`n🔧 Key Services on Target:" -ForegroundColor White
                foreach ($service in $targetInfo.Services) {
                    $parts = $service -split ":"
                    $serviceName = $parts[0]
                    $status = $parts[1]
                    $statusIcon = if ($status -eq "Running") { "✅" } else { "❌" }
                    $color = if ($status -eq "Running") { "Green" } else { "Red" }
                    Write-Host "$statusIcon $serviceName`: $status" -ForegroundColor $color
                }
            }
            
            Remove-PSSession $jumpSession
            return $true
        }
    }
    catch {
        Write-Host "❌ Failed to get jump host info: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Connect-ViaJumpHost {
    param([string]$JumpServer, [string]$TargetServer, [string]$User)
    
    Write-Host "`n🔗 Establishing connection via jump host..." -ForegroundColor Yellow
    
    try {
        # Create session to jump host
        Write-Host "Connecting to jump host ($JumpServer)..." -ForegroundColor Cyan
        
        $jumpSessionOptions = @{
            ComputerName = $JumpServer
        }
        
        if ($User) {
            $credential = Get-Credential -UserName $User -Message "Enter credentials for jump host ($JumpServer)"
            $jumpSessionOptions.Credential = $credential
        }
        
        $jumpSession = New-PSSession @jumpSessionOptions
        
        if ($jumpSession) {
            Write-Host "✅ Connected to jump host" -ForegroundColor Green
            
            # Create nested session to target through jump host
            Write-Host "Creating nested session to target ($TargetServer)..." -ForegroundColor Cyan
            
            # This creates a "double-hop" scenario which requires special configuration
            # For now, we'll provide instructions for manual connection
            Write-Host "`n📋 Manual Connection Instructions:" -ForegroundColor White
            Write-Host "1. You are now connected to the jump host ($JumpServer)" -ForegroundColor Yellow
            Write-Host "2. From the jump host, you can connect to the target:" -ForegroundColor Yellow
            Write-Host "   Enter-PSSession -ComputerName $TargetServer" -ForegroundColor Cyan
            Write-Host "3. Or run commands directly on the target:" -ForegroundColor Yellow
            Write-Host "   Invoke-Command -ComputerName $TargetServer -ScriptBlock { Get-Service }" -ForegroundColor Cyan
            
            Write-Host "`n🔗 Entering jump host session..." -ForegroundColor Cyan
            Write-Host "Use 'Exit-PSSession' to return to local session" -ForegroundColor Gray
            
            Enter-PSSession $jumpSession
            
            return $true
        } else {
            Write-Host "❌ Failed to connect to jump host" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Jump host connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Invoke-CommandViaJumpHost {
    param([string]$JumpServer, [string]$TargetServer, [string]$CommandToExecute)
    
    Write-Host "`n⚡ Executing command via jump host..." -ForegroundColor Yellow
    Write-Host "Command: $CommandToExecute" -ForegroundColor Gray
    
    try {
        $jumpSession = New-PSSession -ComputerName $JumpServer
        
        if ($jumpSession) {
            Write-Host "✅ Connected to jump host" -ForegroundColor Green
            
            # Execute command on target through jump host
            $result = Invoke-Command -Session $jumpSession -ScriptBlock {
                param($target, $command)
                try {
                    $targetSession = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
                    if ($targetSession) {
                        $output = Invoke-Command -Session $targetSession -ScriptBlock ([scriptblock]::Create($command))
                        Remove-PSSession $targetSession
                        return @{
                            Success = $true
                            Output = $output
                        }
                    } else {
                        return @{
                            Success = $false
                            Error = "Could not connect to target server"
                        }
                    }
                }
                catch {
                    return @{
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            } -ArgumentList $TargetServer, $CommandToExecute
            
            if ($result.Success) {
                Write-Host "`n✅ Command executed successfully:" -ForegroundColor Green
                Write-Host ($result.Output | Out-String) -ForegroundColor White
            } else {
                Write-Host "`n❌ Command execution failed: $($result.Error)" -ForegroundColor Red
            }
            
            Remove-PSSession $jumpSession
            return $result.Success
        }
    }
    catch {
        Write-Host "❌ Failed to execute command via jump host: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
try {
    switch ($Action) {
        "Test" {
            Test-JumpHostConnectivity -JumpServer $JumpHost -TargetServer $TargetHost
            Get-JumpHostInfo -JumpServer $JumpHost -TargetServer $TargetHost
        }
        "Info" {
            Get-JumpHostInfo -JumpServer $JumpHost -TargetServer $TargetHost
        }
        "Connect" {
            if (Test-JumpHostConnectivity -JumpServer $JumpHost -TargetServer $TargetHost) {
                Connect-ViaJumpHost -JumpServer $JumpHost -TargetServer $TargetHost -User $Username
            }
        }
        "Execute" {
            if (-not $Command) {
                Write-Host "❌ No command specified. Use -Command parameter." -ForegroundColor Red
                exit 1
            }
            Invoke-CommandViaJumpHost -JumpServer $JumpHost -TargetServer $TargetHost -CommandToExecute $Command
        }
    }
    
    if ($Action -ne "Connect") {
        Write-Host "`n✅ Operation completed!" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Test connectivity:    .\Connect-ViaJumpHost.ps1 -Action Test" -ForegroundColor White
Write-Host "Connect interactively: .\Connect-ViaJumpHost.ps1 -Action Connect" -ForegroundColor White
Write-Host "Execute command:      .\Connect-ViaJumpHost.ps1 -Action Execute -Command 'Get-Service'" -ForegroundColor White
Write-Host "Get server info:      .\Connect-ViaJumpHost.ps1 -Action Info" -ForegroundColor White
Write-Host "Custom servers:       .\Connect-ViaJumpHost.ps1 -JumpHost dc01 -TargetHost ca01 -Action Test" -ForegroundColor White