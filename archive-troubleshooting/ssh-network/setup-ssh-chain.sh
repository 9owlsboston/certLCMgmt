#!/bin/bash

echo "🔧 SSH Chain Setup and Testing"
echo "=============================="
echo "This script sets up and tests the SSH key chain: Linux → DC01 → CA01"
echo ""

echo "📊 Step 1: Testing Current SSH Connectivity"
echo "==========================================="

echo "Testing connection to dc01..."
if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 demoadmin@4.227.115.235 "echo DC01_TEST_SUCCESS" 2>/dev/null | grep -q "DC01_TEST_SUCCESS"; then
    echo "✅ DC01 connection working"
else
    echo "❌ DC01 connection failed"
    echo "Make sure SSH key authentication to dc01 is working first"
    exit 1
fi

echo ""
echo "Testing SSH chain to ca01..."
if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 -o ConnectTimeout=10 demoadmin@10.0.0.5 \"echo CA01_TEST_SUCCESS\"" 2>/dev/null | grep -q "CA01_TEST_SUCCESS"; then
    echo "✅ CA01 connection working via SSH chain"
    echo "🎉 SSH automation is ready to use!"
    CHAIN_WORKING=true
else
    echo "❌ CA01 connection failed via SSH chain"
    echo "The SSH public key is not properly installed on ca01"
    CHAIN_WORKING=false
fi

if [ "$CHAIN_WORKING" = false ]; then
    echo ""
    echo "🔧 Step 2: Setting up SSH Key on CA01"
    echo "====================================="
    
    echo "Your public key content:"
    cat ~/.ssh/id_ed25519.pub
    echo ""
    
    # Create a script to install the SSH key on ca01
    cat > install-ssh-key-ca01.ps1 << 'INSTALL_SCRIPT'
# Install SSH public key on CA01
param(
    [string]$PublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007"
)

Write-Host "Installing SSH public key on CA01..." -ForegroundColor Green

# Create .ssh directory
$sshDir = "C:\Users\demoadmin\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Host "Created directory: $sshDir" -ForegroundColor Yellow
}

# Write public key to authorized_keys
$authorizedKeysFile = "$sshDir\authorized_keys"
$PublicKey | Out-File -FilePath $authorizedKeysFile -Encoding ascii -NoNewline
Write-Host "Installed public key to: $authorizedKeysFile" -ForegroundColor Green

# Set proper permissions
icacls $authorizedKeysFile /inheritance:r /grant "demoadmin:F" /grant "SYSTEM:F"
Write-Host "Set permissions on authorized_keys file" -ForegroundColor Green

# Display the file content to verify
Write-Host "`nVerifying authorized_keys content:" -ForegroundColor Cyan
Get-Content $authorizedKeysFile

# Restart SSH service
Write-Host "`nRestarting SSH service..." -ForegroundColor Yellow
Restart-Service sshd

Write-Host "`nSSH key installation complete!" -ForegroundColor Green
INSTALL_SCRIPT

    echo "✅ Created: install-ssh-key-ca01.ps1"
    echo ""
    echo "🚀 Option A: Automated SSH Key Installation"
    echo "=========================================="
    echo "Trying to install SSH key via existing SSH connection..."
    
    # Upload the script to dc01
    scp -i ~/.ssh/id_ed25519 install-ssh-key-ca01.ps1 demoadmin@4.227.115.235:C:/temp/install-key.ps1
    
    # Try to execute it on ca01 (may fail if SSH key not working)
    echo "Attempting to install SSH key on ca01..."
    if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "powershell.exe -Command \"& {ssh demoadmin@10.0.0.5 'powershell.exe -ExecutionPolicy Bypass -File C:\temp\install-key.ps1'}\"" 2>/dev/null; then
        echo "✅ SSH key installation attempted"
        
        echo ""
        echo "🔍 Testing SSH chain again..."
        sleep 5
        if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 -o ConnectTimeout=10 demoadmin@10.0.0.5 \"echo CA01_FIXED\"" 2>/dev/null | grep -q "CA01_FIXED"; then
            echo "🎉 SUCCESS! SSH chain is now working!"
            CHAIN_WORKING=true
        else
            echo "❌ SSH chain still not working"
        fi
    else
        echo "❌ Automated installation failed"
    fi
    
    if [ "$CHAIN_WORKING" = false ]; then
        echo ""
        echo "📝 Option B: Manual SSH Key Installation"
        echo "======================================="
        echo "Since automated installation didn't work, manual steps are needed:"
        echo ""
        echo "1. Connect to ca01 via RDP:"
        echo "   ssh demoadmin@4.227.115.235"
        echo "   mstsc /v:10.0.0.5"
        echo ""
        echo "2. Copy install-ssh-key-ca01.ps1 to ca01"
        echo ""
        echo "3. Run PowerShell as Administrator on ca01:"
        echo "   PowerShell -ExecutionPolicy Bypass -File install-ssh-key-ca01.ps1"
        echo ""
        echo "4. Test SSH chain again:"
        echo "   $0"
    fi
fi

if [ "$CHAIN_WORKING" = true ]; then
    echo ""
    echo "🎯 Step 3: Testing Arc Recovery Automation"
    echo "=========================================="
    echo "SSH chain is working! You can now use:"
    echo ""
    echo "✅ ./one-click-recovery.sh       - Quick automated fix"
    echo "✅ ./automated-recovery.sh       - Comprehensive recovery"
    echo ""
    echo "Both should now work with SSH automation!"
fi

echo ""
echo "📋 Summary:"
echo "==========="
echo "SSH to DC01: ✅ Working"
echo "SSH DC01→CA01: $([ "$CHAIN_WORKING" = true ] && echo '✅ Working' || echo '❌ Needs setup')"
echo "Arc Recovery: $([ "$CHAIN_WORKING" = true ] && echo '✅ Ready for automation' || echo '❌ Manual steps required')"