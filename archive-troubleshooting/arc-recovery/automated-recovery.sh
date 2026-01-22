#!/bin/bash

echo "🤖 Automated Hybrid Worker Recovery"
echo "=================================="
echo "This script provides automation for Azure Arc agent reconnection"
echo ""

# Load configuration
source certlc-deployment-scripts/.env

echo "📋 Target Configuration:"
echo "======================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo "Tenant ID: $TENANT_ID"
echo "Subscription: $SUBSCRIPTION_ID"
echo "Location: $LOCATION"
echo ""

echo "🔧 Creating PowerShell Recovery Script"
echo "====================================="

# Create a clean PowerShell script
cat > arc-agent-reconnect.ps1 << 'POWERSHELL_SCRIPT'
# Azure Arc Agent Reconnection Script
# Run as Administrator on ca01

param(
    [string]$ResourceGroup = "rg-demo-certlc",
    [string]$TenantId = "b7e530b3-a1e1-465c-b820-dfddb9e77e7d",
    [string]$Location = "westus3", 
    [string]$SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
)

Write-Host "Starting Azure Arc Agent Reconnection..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$arcAgent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"

# Check if Arc agent exists
if (!(Test-Path $arcAgent)) {
    Write-Host "ERROR: Azure Arc agent not found at $arcAgent" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 1: Current Arc Agent Status" -ForegroundColor Yellow
Write-Host "================================"
try {
    & $arcAgent show
} catch {
    Write-Host "Arc agent show failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 2: Stopping Azure Services" -ForegroundColor Yellow  
Write-Host "==============================="
$services = @("himds", "ExtensionService", "GCArcService")
foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Stop-Service -Name $service -Force
            Write-Host "Stopped service: $service" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning stopping $service : $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 3: Disconnecting Arc Agent" -ForegroundColor Yellow
Write-Host "==============================="
try {
    & $arcAgent disconnect --force-local-only
    Write-Host "Arc agent disconnected successfully" -ForegroundColor Green
} catch {
    Write-Host "Disconnect warning: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 4: Reconnecting Arc Agent" -ForegroundColor Yellow
Write-Host "=============================="
try {
    & $arcAgent connect --resource-group $ResourceGroup --tenant-id $TenantId --location $Location --subscription-id $SubscriptionId
    Write-Host "Arc agent reconnection initiated" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Arc reconnection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Waiting for stabilization..." -ForegroundColor Yellow
Write-Host "===================================="
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Step 6: Starting Azure Services" -ForegroundColor Yellow
Write-Host "==============================="
foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Start-Service -Name $service
            Write-Host "Started service: $service" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning starting $service : $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 7: Final Verification" -ForegroundColor Yellow
Write-Host "========================="
Start-Sleep -Seconds 10
try {
    & $arcAgent show
    Write-Host ""
    Write-Host "SUCCESS: Arc agent reconnection completed!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Final verification failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Recovery process finished. Monitor hybrid worker in Azure portal." -ForegroundColor Cyan
POWERSHELL_SCRIPT

echo "✅ Created: arc-agent-reconnect.ps1"

echo ""
echo "🚀 Execution Methods:"
echo "===================="

echo ""
echo "Method 1: Try SSH Automation"
echo "============================"
echo "Testing connection to dc01 (Windows jump host)..."
if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 -o BatchMode=yes demoadmin@4.227.115.235 "echo DC01_CONNECTED" 2>/dev/null | grep -q "DC01_CONNECTED"; then
    echo "✅ DC01 reachable via SSH"
    
    echo "Testing SSH chain to ca01..."
    if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 -o ConnectTimeout=10 -o BatchMode=yes demoadmin@10.0.0.5 \"echo CA01_CONNECTED\"" 2>/dev/null | grep -q "CA01_CONNECTED"; then
        echo "✅ CA01 reachable via SSH through DC01"
        echo ""
        echo "🔄 Attempting automated execution..."
        
        # Copy script to DC01 (Windows paths)
        scp -i ~/.ssh/id_ed25519 arc-agent-reconnect.ps1 demoadmin@4.227.115.235:C:/temp/arc-script.ps1
        
        # Execute via SSH chain
        ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 << 'SSH_COMMANDS'
# Copy to CA01
scp -i C:\Users\demoadmin\.ssh\id_ed25519 C:\temp\arc-script.ps1 demoadmin@10.0.0.5:C:\temp\arc-script.ps1

# Execute on CA01
echo "Executing Arc reconnection script on CA01..."
ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 "powershell.exe -ExecutionPolicy Bypass -File C:\temp\arc-script.ps1"
SSH_COMMANDS
        
        if [ $? -eq 0 ]; then
            echo "✅ SSH automation successful!"
            echo ""
            echo "🔍 Starting monitoring..."
            sleep 10
            ./monitor-hybrid-worker.sh &
            MONITOR_PID=$!
            echo "Monitor started (PID: $MONITOR_PID)"
            echo "Press Ctrl+C to stop monitoring"
        else
            echo "❌ SSH automation failed - use manual method"
        fi
    else
        echo "❌ CA01 not reachable via SSH - likely SSH key issue between dc01→ca01"
        echo "💡 The SSH public key may not be properly installed on ca01"
    fi
else
    echo "❌ DC01 not reachable via SSH - check connectivity"
fi

echo ""
echo "Method 2: Manual Execution (Recommended if SSH fails)"
echo "==================================================="
echo "1. Connect to CA01:"
echo "   ssh demoadmin@4.227.115.235"
echo "   mstsc /v:10.0.0.5"
echo ""
echo "2. Copy arc-agent-reconnect.ps1 to CA01"
echo ""  
echo "3. Run as Administrator on CA01:"
echo "   PowerShell -ExecutionPolicy Bypass -File arc-agent-reconnect.ps1"
echo ""
echo "4. Monitor progress:"
echo "   ./monitor-hybrid-worker.sh"

echo ""
echo "📊 Expected Timeline:"
echo "===================="
echo "- Arc reconnection: 1-2 minutes"
echo "- Service restart: 30 seconds"
echo "- Hybrid worker check-in: 2-5 minutes"
echo "- Total recovery: 5-10 minutes"

echo ""
echo "✅ Files Created:"
echo "================"
echo "- arc-agent-reconnect.ps1: PowerShell script for Arc reconnection"
echo "- This automation script with SSH and manual options"