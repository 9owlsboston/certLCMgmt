#!/bin/bash
# Quick SSH diagnosis script

echo "🔍 SSH Key Authentication Diagnosis"
echo "=================================="

echo "1. Your SSH public key fingerprint:"
ssh-keygen -lf ~/.ssh/id_ed25519.pub

echo ""
echo "2. Testing SSH connection with verbose output (last 10 lines):"
ssh -o ConnectTimeout=10 -o BatchMode=yes -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 'echo "SSH key working!"' 2>&1 | tail -10

echo ""
echo "3. Checking SSH client configuration:"
ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 exit
status=$?

if [ $status -eq 0 ]; then
    echo "✅ SSH key authentication is working!"
else
    echo "❌ SSH key authentication failed (exit code: $status)"
    echo ""
    echo "Manual fix required:"
    echo "1. ssh demoadmin@4.227.115.235"
    echo "2. Run the PowerShell commands from setup-authorized-keys.ps1"
    echo "3. Exit and test again"
fi

echo ""
echo "4. Your public key (to copy manually if needed):"
cat ~/.ssh/id_ed25519.pub