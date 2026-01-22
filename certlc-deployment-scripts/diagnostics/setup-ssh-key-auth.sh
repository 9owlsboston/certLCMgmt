#!/bin/bash

# SSH Key Setup Helper for Windows Server
# This script helps you properly configure SSH key authentication on the Windows server

echo "=========================================="
echo "SSH Key Authentication Setup Helper"
echo "=========================================="

# Display your public key
echo "🔑 Your SSH Public Key:"
echo "======================="
cat ~/.ssh/id_ed25519.pub
echo "======================="
echo ""

# Create PowerShell commands to run on Windows server
cat > setup_ssh_keys.ps1 << 'EOF'
# SSH Key Setup for Windows Server
# Run this script on the Windows server to set up SSH key authentication

Write-Host "=== SSH Key Authentication Setup ===" -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Green

# Create .ssh directory if it doesn't exist
$sshDir = "C:\Users\$env:USERNAME\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Host "✅ Created .ssh directory: $sshDir" -ForegroundColor Green
} else {
    Write-Host "✅ .ssh directory already exists: $sshDir" -ForegroundColor Green
}

# Display current authorized_keys if it exists
$authorizedKeysPath = Join-Path $sshDir "authorized_keys"
if (Test-Path $authorizedKeysPath) {
    Write-Host "📋 Current authorized_keys content:" -ForegroundColor Yellow
    Get-Content $authorizedKeysPath
    Write-Host ""
}

Write-Host "📝 Please paste your SSH public key when prompted:" -ForegroundColor Yellow
Write-Host "   (The key should start with 'ssh-ed25519')" -ForegroundColor Cyan
$publicKey = Read-Host "Paste your SSH public key here"

if ($publicKey -and $publicKey.StartsWith("ssh-")) {
    # Add the public key to authorized_keys
    Add-Content -Path $authorizedKeysPath -Value $publicKey
    Write-Host "✅ SSH public key added to authorized_keys" -ForegroundColor Green
    
    # Set proper permissions on authorized_keys file
    icacls $authorizedKeysPath /inheritance:r /grant "$env:USERNAME`:F" /grant "SYSTEM:F"
    Write-Host "✅ Set proper permissions on authorized_keys file" -ForegroundColor Green
    
    # Display the updated content
    Write-Host "📋 Updated authorized_keys content:" -ForegroundColor Cyan
    Get-Content $authorizedKeysPath
    
    Write-Host "✅ SSH key authentication setup completed!" -ForegroundColor Green
    Write-Host "   You should now be able to connect without a password using:" -ForegroundColor Cyan
    Write-Host "   ssh -i ~/.ssh/id_ed25519 $env:USERNAME@<server-ip>" -ForegroundColor White
} else {
    Write-Host "❌ Invalid SSH public key format. Please try again." -ForegroundColor Red
}

# Test SSH service status
Write-Host "`n🔍 Checking SSH service status..." -ForegroundColor Yellow
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshdService) {
    Write-Host "   SSH Service Status: $($sshdService.Status)" -ForegroundColor $(if($sshdService.Status -eq 'Running') { 'Green' } else { 'Red' })
    if ($sshdService.Status -ne 'Running') {
        Write-Host "🔄 Starting SSH service..." -ForegroundColor Yellow
        Start-Service sshd
        Write-Host "✅ SSH service started" -ForegroundColor Green
    }
} else {
    Write-Host "❌ SSH service not found. Please install OpenSSH Server first." -ForegroundColor Red
}
EOF

echo "📁 Created setup_ssh_keys.ps1 script"
echo ""
echo "🚀 Next Steps:"
echo "1. Copy the SSH public key shown above"
echo "2. Copy the setup_ssh_keys.ps1 script to your Windows server"
echo "3. Run the PowerShell script on the Windows server as administrator"
echo "4. Paste your public key when prompted"
echo ""
echo "📋 Manual Method (Alternative):"
echo "If you prefer to do it manually, run these commands on the Windows server:"
echo ""
echo "PowerShell commands to run on Windows server:"
echo "=============================================="
echo 'New-Item -ItemType Directory -Path "C:\Users\demoadmin\.ssh" -Force'
echo 'Set-Content -Path "C:\Users\demoadmin\.ssh\authorized_keys" -Value "'"$(cat ~/.ssh/id_ed25519.pub)"'"'
echo 'icacls "C:\Users\demoadmin\.ssh\authorized_keys" /inheritance:r /grant "demoadmin:F" /grant "SYSTEM:F"'
echo 'Restart-Service sshd'
echo "=============================================="
echo ""
echo "🔧 Quick Setup via SSH (with password):"
echo "You can also set it up remotely by running:"

# Create a one-liner command to set up SSH keys remotely
ENCODED_KEY=$(cat ~/.ssh/id_ed25519.pub | base64 -w 0)
echo ""
echo "ssh demoadmin@4.227.115.235 'powershell.exe -Command \""
echo "New-Item -ItemType Directory -Path C:\\Users\\demoadmin\\.ssh -Force;"
echo "Set-Content -Path C:\\Users\\demoadmin\\.ssh\\authorized_keys -Value ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('$ENCODED_KEY')));"
echo "icacls C:\\Users\\demoadmin\\.ssh\\authorized_keys /inheritance:r /grant demoadmin:F /grant SYSTEM:F;"
echo "Restart-Service sshd;"
echo "Write-Host 'SSH key authentication setup completed'"\"'"
echo ""
echo "After setting up the SSH key, test with:"
echo "ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 'echo SSH key authentication successful'"