# CA01 Server Connection Helper Scripts
# Use these scripts to connect to ca01 for troubleshooting

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = "ca01",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("RDP", "PowerShell", "Test", "Info")]
    [string]$ConnectionType = "Test",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnablePSRemoting
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CA01 Server Connection Helper" -ForegroundColor Cyan
Write-Host "Target: $ComputerName" -ForegroundColor Cyan
Write-Host "Connection Type: $ConnectionType" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

function Test-ServerAccess {
    param([string]$Computer)
    
    Write-Host "`n🔍 Testing access to $Computer..." -ForegroundColor Yellow
    
    # Network connectivity
    Write-Host "Testing network connectivity..." -ForegroundColor Cyan
    try {
        if (Test-Connection -ComputerName $Computer -Count 2 -Quiet) {
            Write-Host "✅ Network connectivity: OK" -ForegroundColor Green
        } else {
            Write-Host "❌ Network connectivity: FAILED" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Network test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # PowerShell remoting
    Write-Host "Testing PowerShell remoting..." -ForegroundColor Cyan
    try {
        $session = New-PSSession -ComputerName $Computer -ErrorAction SilentlyContinue
        if ($session) {
            Write-Host "✅ PowerShell remoting: OK" -ForegroundColor Green
            Remove-PSSession $session
        } else {
            Write-Host "❌ PowerShell remoting: FAILED" -ForegroundColor Red
            Write-Host "   Try running with -EnablePSRemoting to configure" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ PowerShell remoting failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Try running with -EnablePSRemoting to configure" -ForegroundColor Yellow
    }
    
    # WMI/CIM access
    Write-Host "Testing WMI/CIM access..." -ForegroundColor Cyan
    try {
        $os = Get-CimInstance -ComputerName $Computer -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            Write-Host "✅ WMI/CIM access: OK" -ForegroundColor Green
            Write-Host "   OS: $($os.Caption)" -ForegroundColor Gray
            Write-Host "   Version: $($os.Version)" -ForegroundColor Gray
            Write-Host "   Last Boot: $($os.LastBootUpTime)" -ForegroundColor Gray
        } else {
            Write-Host "❌ WMI/CIM access: FAILED" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ WMI/CIM access failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # RDP port check
    Write-Host "Testing RDP port (3389)..." -ForegroundColor Cyan
    try {
        $rdpTest = Test-NetConnection -ComputerName $Computer -Port 3389 -InformationLevel Quiet
        if ($rdpTest) {
            Write-Host "✅ RDP port accessible: OK" -ForegroundColor Green
        } else {
            Write-Host "❌ RDP port not accessible" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ RDP port test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $true
}

function Enable-PSRemotingOnTarget {
    param([string]$Computer)
    
    Write-Host "`n🔧 Attempting to enable PowerShell remoting on $Computer..." -ForegroundColor Yellow
    
    try {
        # Try using WMI to enable PSRemoting
        Write-Host "Attempting to enable PSRemoting via WMI..." -ForegroundColor Cyan
        
        $result = Invoke-CimMethod -ComputerName $Computer -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine = "powershell.exe -Command `"Enable-PSRemoting -Force -SkipNetworkProfileCheck`""
        }
        
        if ($result.ReturnValue -eq 0) {
            Write-Host "✅ PSRemoting enable command executed" -ForegroundColor Green
            Write-Host "⏳ Waiting for service to start..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            
            # Test if it worked
            $session = New-PSSession -ComputerName $Computer -ErrorAction SilentlyContinue
            if ($session) {
                Write-Host "✅ PowerShell remoting now working!" -ForegroundColor Green
                Remove-PSSession $session
                return $true
            } else {
                Write-Host "⚠️ Command executed but remoting still not working" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "❌ Failed to execute enable command (Return code: $($result.ReturnValue))" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Failed to enable PSRemoting: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Connect-ViaRDP {
    param([string]$Computer, [string]$User)
    
    Write-Host "`n🖥️ Initiating RDP connection to $Computer..." -ForegroundColor Yellow
    
    try {
        # Create RDP file
        $rdpContent = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$Computer
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
"@

        if ($User) {
            $rdpContent += "`nusername:s:$User"
        }
        
        $rdpFile = "$env:TEMP\connect-to-$Computer.rdp"
        $rdpContent | Out-File -FilePath $rdpFile -Encoding ASCII
        
        Write-Host "✅ RDP file created: $rdpFile" -ForegroundColor Green
        Write-Host "🚀 Launching RDP connection..." -ForegroundColor Cyan
        
        # Launch RDP
        Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile
        
        Write-Host "✅ RDP connection initiated!" -ForegroundColor Green
        Write-Host "If connection fails, check:" -ForegroundColor Yellow
        Write-Host "  - RDP is enabled on the target server" -ForegroundColor Yellow
        Write-Host "  - Windows Firewall allows RDP" -ForegroundColor Yellow
        Write-Host "  - Network connectivity to port 3389" -ForegroundColor Yellow
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to initiate RDP: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Connect-ViaPowerShell {
    param([string]$Computer, [string]$User)
    
    Write-Host "`n💻 Creating PowerShell session to $Computer..." -ForegroundColor Yellow
    
    try {
        $sessionOptions = @{
            ComputerName = $Computer
        }
        
        if ($User) {
            $credential = Get-Credential -UserName $User -Message "Enter credentials for $Computer"
            $sessionOptions.Credential = $credential
        }
        
        Write-Host "Establishing session..." -ForegroundColor Cyan
        $session = New-PSSession @sessionOptions
        
        if ($session) {
            Write-Host "✅ PowerShell session established!" -ForegroundColor Green
            Write-Host "Session ID: $($session.Id)" -ForegroundColor Gray
            Write-Host "Computer: $($session.ComputerName)" -ForegroundColor Gray
            Write-Host "State: $($session.State)" -ForegroundColor Gray
            
            # Enter interactive session
            Write-Host "`n🔗 Entering interactive session..." -ForegroundColor Cyan
            Write-Host "Use 'Exit-PSSession' to return to local session" -ForegroundColor Yellow
            
            Enter-PSSession $session
            
            return $true
        } else {
            Write-Host "❌ Failed to create session" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ PowerShell connection failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
        Write-Host "  - Ensure PowerShell remoting is enabled: Enable-PSRemoting -Force" -ForegroundColor Yellow
        Write-Host "  - Check WinRM service is running: Get-Service WinRM" -ForegroundColor Yellow
        Write-Host "  - Verify firewall allows WinRM: Test-NetConnection $Computer -Port 5985" -ForegroundColor Yellow
        return $false
    }
}

function Get-ServerInfo {
    param([string]$Computer)
    
    Write-Host "`n📊 Gathering server information for $Computer..." -ForegroundColor Yellow
    
    try {
        # Get basic system info
        Write-Host "Collecting system information..." -ForegroundColor Cyan
        $os = Get-CimInstance -ComputerName $Computer -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $computer = Get-CimInstance -ComputerName $Computer -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $network = Get-CimInstance -ComputerName $Computer -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        
        if ($os -and $computer) {
            Write-Host "`n🖥️ System Information:" -ForegroundColor White
            Write-Host "Computer Name: $($computer.Name)" -ForegroundColor Gray
            Write-Host "Domain: $($computer.Domain)" -ForegroundColor Gray
            Write-Host "Operating System: $($os.Caption)" -ForegroundColor Gray
            Write-Host "Version: $($os.Version)" -ForegroundColor Gray
            Write-Host "Architecture: $($os.OSArchitecture)" -ForegroundColor Gray
            Write-Host "Total Memory: $([math]::Round($computer.TotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor Gray
            Write-Host "Last Boot: $($os.LastBootUpTime)" -ForegroundColor Gray
            Write-Host "Uptime: $((Get-Date) - $os.LastBootUpTime)" -ForegroundColor Gray
            
            Write-Host "`n🌐 Network Configuration:" -ForegroundColor White
            foreach ($adapter in $network) {
                Write-Host "Interface: $($adapter.Description)" -ForegroundColor Gray
                Write-Host "IP Address: $($adapter.IPAddress -join ', ')" -ForegroundColor Gray
                Write-Host "Subnet Mask: $($adapter.IPSubnet -join ', ')" -ForegroundColor Gray
                Write-Host "Default Gateway: $($adapter.DefaultIPGateway -join ', ')" -ForegroundColor Gray
                Write-Host "DNS Servers: $($adapter.DNSServerSearchOrder -join ', ')" -ForegroundColor Gray
                Write-Host "---" -ForegroundColor DarkGray
            }
        }
        
        # Check services
        Write-Host "`n🔧 Key Services Status:" -ForegroundColor White
        $services = Get-WmiObject -Class Win32_Service -ComputerName $Computer | Where-Object {
            $_.Name -in @('WinRM', 'HealthService', 'Microsoft Monitoring Agent', 'CertSvc', 'DNS', 'ADWS')
        }
        
        foreach ($service in $services) {
            $status = if ($service.State -eq "Running") { "✅" } else { "❌" }
            Write-Host "$status $($service.Name): $($service.State)" -ForegroundColor $(if ($service.State -eq "Running") { "Green" } else { "Red" })
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to get server info: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution logic
try {
    switch ($ConnectionType) {
        "Test" {
            Test-ServerAccess -Computer $ComputerName
            Get-ServerInfo -Computer $ComputerName
        }
        "Info" {
            Get-ServerInfo -Computer $ComputerName
        }
        "RDP" {
            if (Test-ServerAccess -Computer $ComputerName) {
                Connect-ViaRDP -Computer $ComputerName -User $Username
            }
        }
        "PowerShell" {
            if ($EnablePSRemoting) {
                Enable-PSRemotingOnTarget -Computer $ComputerName
            }
            Connect-ViaPowerShell -Computer $ComputerName -User $Username
        }
    }
    
    if ($ConnectionType -ne "PowerShell") {
        Write-Host "`n✅ Operation completed!" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage examples
Write-Host "`n📖 Usage Examples:" -ForegroundColor Cyan
Write-Host "Test connectivity:    .\Connect-CA01.ps1 -ConnectionType Test" -ForegroundColor White
Write-Host "RDP connection:       .\Connect-CA01.ps1 -ConnectionType RDP" -ForegroundColor White
Write-Host "PowerShell session:   .\Connect-CA01.ps1 -ConnectionType PowerShell" -ForegroundColor White
Write-Host "Enable PS remoting:   .\Connect-CA01.ps1 -ConnectionType PowerShell -EnablePSRemoting" -ForegroundColor White
Write-Host "With specific user:   .\Connect-CA01.ps1 -ConnectionType PowerShell -Username 'domain\admin'" -ForegroundColor White