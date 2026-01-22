# SSH PowerShell Remoting Configuration Script for Windows
# Run this script with Administrator privileges on each Windows server (dc01 and ca01)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SSH PowerShell Remoting Configuration" -ForegroundColor Cyan  
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Check PowerShell 7+ installation
Write-Host "🔍 Checking PowerShell 7+ installation..." -ForegroundColor Yellow
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
if (Test-Path $pwshPath) {
    Write-Host "✅ PowerShell 7+ found at: $pwshPath" -ForegroundColor Green
    & $pwshPath --version
} else {
    Write-Host "❌ PowerShell 7+ not found. Please install from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Red
    Write-Host "   Download and install PowerShell 7+ before continuing." -ForegroundColor Yellow
    Read-Host "Press Enter after installing PowerShell 7+"
}

# Step 2: Check OpenSSH Server availability
Write-Host "`n🔍 Checking OpenSSH Server availability..." -ForegroundColor Yellow
$sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCapability) {
    Write-Host "✅ OpenSSH Server capability found: $($sshCapability.Name)" -ForegroundColor Green
    Write-Host "   State: $($sshCapability.State)" -ForegroundColor Cyan
    
    if ($sshCapability.State -ne "Installed") {
        Write-Host "📥 Installing OpenSSH Server..." -ForegroundColor Yellow
        try {
            Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
            Write-Host "✅ OpenSSH Server installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to install OpenSSH Server: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "❌ OpenSSH Server capability not found" -ForegroundColor Red
    exit 1
}

# Step 3: Configure SSH service
Write-Host "`n🔧 Configuring SSH service..." -ForegroundColor Yellow
try {
    # Start SSH service
    Start-Service sshd -ErrorAction Stop
    Write-Host "✅ SSH service started" -ForegroundColor Green
    
    # Set to automatic startup
    Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction Stop
    Write-Host "✅ SSH service set to automatic startup" -ForegroundColor Green
    
    # Check service status
    $sshdStatus = Get-Service sshd
    Write-Host "   Service Status: $($sshdStatus.Status)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to configure SSH service: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Configure PowerShell subsystem
Write-Host "`n🔧 Configuring PowerShell subsystem..." -ForegroundColor Yellow
$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
$pwshSubsystem = "Subsystem powershell C:/Program Files/PowerShell/7/pwsh.exe -sshs -NoLogo"

if (Test-Path $sshdConfigPath) {
    $currentConfig = Get-Content $sshdConfigPath
    if ($currentConfig -notcontains $pwshSubsystem) {
        Write-Host "📝 Adding PowerShell subsystem to SSH config..." -ForegroundColor Yellow
        Add-Content -Path $sshdConfigPath -Value "`n$pwshSubsystem"
        Write-Host "✅ PowerShell subsystem added to SSH config" -ForegroundColor Green
        
        # Restart SSH service to apply changes
        Write-Host "🔄 Restarting SSH service..." -ForegroundColor Yellow
        Restart-Service sshd
        Write-Host "✅ SSH service restarted" -ForegroundColor Green
    } else {
        Write-Host "✅ PowerShell subsystem already configured" -ForegroundColor Green
    }
} else {
    Write-Host "❌ SSH config file not found at: $sshdConfigPath" -ForegroundColor Red
    exit 1
}

# Step 5: Configure Windows Firewall
Write-Host "`n🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    $firewallRule = Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue
    if (-not $firewallRule) {
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        Write-Host "✅ Firewall rule created for SSH" -ForegroundColor Green
    } else {
        Write-Host "✅ SSH firewall rule already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to configure firewall: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 6: Display connection information
Write-Host "`n📋 Connection Information:" -ForegroundColor Cyan
Write-Host "   Server: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "   SSH Port: 22" -ForegroundColor White
Write-Host "   PowerShell Path: $pwshPath" -ForegroundColor White
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" }
foreach ($ip in $ipAddresses) {
    Write-Host "   IP Address: $($ip.IPAddress)" -ForegroundColor White
}

Write-Host "`n🔍 Testing SSH connectivity..." -ForegroundColor Yellow
$sshTest = Test-NetConnection -ComputerName "localhost" -Port 22
if ($sshTest.TcpTestSucceeded) {
    Write-Host "✅ SSH is accessible on port 22" -ForegroundColor Green
} else {
    Write-Host "❌ SSH is not accessible on port 22" -ForegroundColor Red
}

Write-Host "`n✅ SSH PowerShell Remoting configuration completed!" -ForegroundColor Green
Write-Host "   You can now connect from Linux using:" -ForegroundColor Cyan
Write-Host "   Enter-PSSession -HostName $env:COMPUTERNAME -UserName administrator" -ForegroundColor White

