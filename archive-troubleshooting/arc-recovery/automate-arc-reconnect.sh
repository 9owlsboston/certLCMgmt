#!/bin/bash

echo "🤖 Automated Azure Arc Agent Reconnection"
echo "========================================"
echo "This script automates the Arc agent reconnection process"
echo ""

# Load configuration
source certlc-deployment-scripts/.env

echo "📋 Configuration:"
echo "================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Location: $LOCATION"
echo ""

echo "🔗 Step 1: Testing SSH connectivity to ca01 via dc01"
echo "=================================================="

# Test if we can reach ca01 via jump host
if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 -o BatchMode=yes demoadmin@4.227.115.235 "ssh -o ConnectTimeout=10 -o BatchMode=yes demoadmin@10.0.0.5 'echo Connection successful'" 2>/dev/null; then
    echo "✅ SSH connectivity to ca01 working"
    USE_SSH=true
else
    echo "❌ SSH connectivity to ca01 failed"
    echo "💡 Will generate PowerShell script for manual execution"
    USE_SSH=false
fi

echo ""
echo "🔧 Step 2: Generating Arc agent reconnection commands"
echo "==================================================="

# Create PowerShell script for Arc agent reconnection
cat > arc-reconnect.ps1 << 'EOF'
# Azure Arc Agent Reconnection Script
# Run this script as Administrator on ca01

param(
    [string]$ResourceGroup = "rg-demo-certlc",
    [string]$TenantId = "b7e530b3-a1e1-465c-b820-dfddb9e77e7d",
    [string]$Location = "westus3",
    [string]$SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
)

Write-Host "🔄 Azure Arc Agent Reconnection Starting..." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

$arcAgent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"

if (!(Test-Path $arcAgent)) {
    Write-Host "❌ Azure Arc agent not found at: $arcAgent" -ForegroundColor Red
    exit 1
}

Write-Host "`n📊 Step 1: Current Arc Agent Status" -ForegroundColor Yellow
Write-Host "===================================="
try {
    & $arcAgent show
} catch {
    Write-Host "Arc agent status check failed: $_" -ForegroundColor Red
}

Write-Host "`n🛑 Step 2: Disconnecting Arc Agent (forced)" -ForegroundColor Yellow
Write-Host "============================================"
try {
    & $arcAgent disconnect --force-local-only
    Write-Host "✅ Arc agent disconnected" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Disconnect failed (may already be disconnected): $_" -ForegroundColor Yellow
}

Write-Host "`n🔌 Step 3: Reconnecting Arc Agent" -ForegroundColor Yellow
Write-Host "================================="
$connectArgs = @(
    "connect",
    "--resource-group", $ResourceGroup,
    "--tenant-id", $TenantId,
    "--location", $Location,
    "--subscription-id", $SubscriptionId,
    "--correlation-id", "hybridworker-autofix-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

Write-Host "Executing: $arcAgent $($connectArgs -join ' ')" -ForegroundColor Gray

try {
    & $arcAgent $connectArgs
    Write-Host "✅ Arc agent reconnection initiated" -ForegroundColor Green
} catch {
    Write-Host "❌ Arc agent reconnection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n⏳ Step 4: Waiting for connection to establish..." -ForegroundColor Yellow
Write-Host "==============================================="
Start-Sleep -Seconds 30

Write-Host "`n📊 Step 5: Verifying Arc Agent Connection" -ForegroundColor Yellow
Write-Host "========================================="
try {
    & $arcAgent show
    Write-Host "`n✅ Arc agent reconnection process completed!" -ForegroundColor Green
} catch {
    Write-Host "❌ Arc agent verification failed: $_" -ForegroundColor Red
}

Write-Host "`n🔄 Step 6: Restarting Related Services" -ForegroundColor Yellow
Write-Host "======================================"
$services = @("himds", "ExtensionService", "GCArcService")

foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Restart-Service -Name $service -Force
            Write-Host "✅ Restarted service: $service" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Service not found: $service" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Failed to restart $service : $_" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Arc Agent Reconnection Complete!" -ForegroundColor Green
Write-Host "Hybrid worker should check in within 2-5 minutes" -ForegroundColor Green
EOF

echo "✅ Created: arc-reconnect.ps1"

if [ "$USE_SSH" = true ]; then
    echo ""
    echo "🚀 Step 3: Executing Arc reconnection via SSH"
    echo "============================================="
    
    # Execute the PowerShell script via SSH
    echo "Uploading and executing PowerShell script on ca01..."
    
    # Upload script to ca01
    scp -i ~/.ssh/id_ed25519 arc-reconnect.ps1 demoadmin@4.227.115.235:/tmp/arc-reconnect.ps1
    
    # Copy to ca01 and execute
    ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 << 'OUTER_SSH'
        echo "Copying script to ca01..."
        scp -i C:\Users\demoadmin\.ssh\id_ed25519 /tmp/arc-reconnect.ps1 demoadmin@10.0.0.5:C:\temp\arc-reconnect.ps1
        
        echo "Executing Arc reconnection script on ca01..."
        ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 "powershell.exe -ExecutionPolicy Bypass -File C:\temp\arc-reconnect.ps1"
OUTER_SSH

    if [ $? -eq 0 ]; then
        echo "✅ Arc reconnection script executed successfully"
    else
        echo "❌ Arc reconnection script execution failed"
        echo "💡 Try manual execution (see instructions below)"
    fi
else
    echo ""
    echo "📝 Manual Execution Instructions"
    echo "==============================="
    echo "Since SSH automation isn't working, follow these steps:"
    echo ""
    echo "1. RDP to ca01:"
    echo "   - SSH to dc01: ssh demoadmin@4.227.115.235"
    echo "   - RDP to ca01: mstsc /v:10.0.0.5"
    echo ""
    echo "2. Copy arc-reconnect.ps1 to ca01"
    echo ""
    echo "3. Run PowerShell as Administrator on ca01:"
    echo "   PowerShell -ExecutionPolicy Bypass -File arc-reconnect.ps1"
fi

echo ""
echo "🔍 Step 4: Monitor Progress"
echo "========================="
echo "After Arc reconnection, monitor with:"
echo "./monitor-hybrid-worker.sh"
echo ""
echo "Look for 'Last Seen' timestamp to update to today's date"

echo ""
echo "📋 Files Created:"
echo "================"
echo "✅ arc-reconnect.ps1 - PowerShell script for Arc agent reconnection"
echo "✅ This script provides both automated and manual execution options"