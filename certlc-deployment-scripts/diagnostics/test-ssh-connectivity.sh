#!/bin/bash

# Quick SSH connectivity test script
echo "🔍 Testing SSH connectivity to Windows servers..."

echo ""
echo "Testing dc01..."
if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no administrator@dc01 "echo 'SSH connection successful to' \$env:COMPUTERNAME" 2>/dev/null; then
    echo "✅ dc01 SSH connection successful"
else
    echo "❌ dc01 SSH connection failed"
    echo "   Make sure you've:"
    echo "   1. Run configure-ssh-powershell.ps1 on dc01"
    echo "   2. Added your public key to authorized_keys"
    echo "   3. Restarted SSH service"
fi

echo ""
echo "Testing ca01..."
if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no administrator@ca01 "echo 'SSH connection successful to' \$env:COMPUTERNAME" 2>/dev/null; then
    echo "✅ ca01 SSH connection successful"
else
    echo "❌ ca01 SSH connection failed"
    echo "   Make sure you've:"
    echo "   1. Run configure-ssh-powershell.ps1 on ca01"
    echo "   2. Added your public key to authorized_keys"
    echo "   3. Restarted SSH service"
fi

echo ""
echo "🚀 Once SSH is working, you can use:"
echo "   pwsh ./Connect-ViaSSH.ps1 -Action Test"
echo "   pwsh ./Manage-HybridWorker-SSH.ps1 -Action Status"