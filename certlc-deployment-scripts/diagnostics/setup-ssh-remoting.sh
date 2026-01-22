#!/bin/bash

# SSH PowerShell Remoting Setup Helper
# This script helps configure SSH-based PowerShell remoting for certificate lifecycle management

# Load configuration
if [ -f "../.env" ]; then
    source ../.env
    echo "✅ Configuration loaded from .env file"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Subscription: $SUBSCRIPTION_ID"
else
    echo "❌ .env file not found"
    exit 1
fi

echo "=========================================="
echo "SSH PowerShell Remoting Setup Helper"
echo "=========================================="

# Function to display server info
show_server_info() {
    echo ""
    echo "🖥️  Server Information:"
    echo "   Domain Controller (Jump Host): dc01"
    echo "   Certificate Authority: ca01 (IP: 10.0.0.5)"
    echo "   Resource Group: $RESOURCE_GROUP"
    echo ""
}

# Function to generate Windows configuration script
generate_windows_config() {
    echo "📝 Generating Windows server configuration script..."
    
    cat > configure-ssh-powershell.ps1 << 'EOF'
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

EOF

    echo "✅ Windows configuration script created: configure-ssh-powershell.ps1"
}

# Function to generate SSH key setup
setup_ssh_keys() {
    echo ""
    echo "🔑 Setting up SSH keys..."
    
    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "📝 Generating new SSH key..."
        ssh-keygen -t ed25519 -C "certlc-admin@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
        echo "✅ SSH key generated"
    else
        echo "✅ SSH key already exists"
    fi
    
    echo ""
    echo "📋 Your public key (copy this to Windows servers):"
    echo "=================================================="
    cat ~/.ssh/id_ed25519.pub
    echo "=================================================="
    echo ""
    echo "💡 To copy this key to Windows servers:"
    echo "   1. Copy the public key above"
    echo "   2. On Windows server, create: C:\\Users\\administrator\\.ssh\\authorized_keys"
    echo "   3. Paste the public key into that file"
    echo "   4. Set proper permissions on Windows"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    echo ""
    echo "🔍 Testing SSH connectivity..."
    
    echo "Testing dc01..."
    if timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no administrator@dc01 exit 2>/dev/null; then
        echo "✅ dc01 SSH connection successful"
    else
        echo "❌ dc01 SSH connection failed"
    fi
    
    echo "Testing ca01..."
    if timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no administrator@ca01 exit 2>/dev/null; then
        echo "✅ ca01 SSH connection successful"
    else
        echo "❌ ca01 SSH connection failed"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "📋 SSH PowerShell Remoting Setup Options:"
    echo "1. Show server information"
    echo "2. Generate Windows configuration script"
    echo "3. Setup SSH keys on Linux"
    echo "4. Test SSH connectivity"
    echo "5. All steps (recommended)"
    echo "6. Exit"
    echo ""
    read -p "Select option (1-6): " choice
    
    case $choice in
        1) show_server_info ;;
        2) generate_windows_config ;;
        3) setup_ssh_keys ;;
        4) test_ssh_connectivity ;;
        5) 
            show_server_info
            generate_windows_config
            setup_ssh_keys
            echo ""
            echo "📝 Next steps:"
            echo "1. Copy configure-ssh-powershell.ps1 to Windows servers"
            echo "2. Run it with Administrator privileges on dc01 and ca01"
            echo "3. Copy your SSH public key to Windows servers"
            echo "4. Test connectivity with option 4"
            ;;
        6) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option"; show_menu ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Start the script
show_server_info
show_menu