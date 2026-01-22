#!/bin/bash

echo "🔄 Complete Hybrid Worker Recovery Automation"
echo "============================================="
echo "This script automates the full recovery process with monitoring"
echo ""

# Load configuration
source certlc-deployment-scripts/.env

echo "🎯 Recovery Process Overview:"
echo "============================="
echo "1. 🔌 Reconnect Azure Arc Agent"
echo "2. 🔄 Restart hybrid worker services"
echo "3. 📊 Monitor recovery progress"
echo "4. ✅ Verify successful reconnection"
echo ""

# Function to check current worker status
check_worker_status() {
    local subscription_id
    local last_seen
    subscription_id=$(az account show --query id --output tsv)
    last_seen=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$subscription_id/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups/EnterpriseRootCA/hybridRunbookWorkers/f47ceb57-e588-5f42-8431-78e508a58d3d?api-version=2023-11-01" \
        --query "properties.lastSeenDateTime" \
        --output tsv)
    
    echo "$last_seen"
}

# Function to check if worker is online (today's date)
is_worker_online() {
    local last_seen="$1"
    local current_date
    current_date=$(date +"%Y-%m-%d")
    
    if [[ "$last_seen" == *"$current_date"* ]]; then
        return 0  # Online
    else
        return 1  # Offline
    fi
}

echo "📊 Initial Status Check:"
echo "======================="
initial_status=$(check_worker_status)
echo "Current Last Seen: $initial_status"

if is_worker_online "$initial_status"; then
    echo "✅ Worker is already online!"
    exit 0
else
    echo "❌ Worker is offline - proceeding with recovery"
fi

echo ""
echo "🔧 Step 1: Execute Arc Agent Reconnection"
echo "========================================"

# Create the PowerShell script with current config values
cat > hybrid-worker-full-recovery.ps1 << EOF
# Complete Hybrid Worker Recovery Script
# Run as Administrator on ca01

param(
    [string]\$ResourceGroup = "$RESOURCE_GROUP",
    [string]\$TenantId = "$TENANT_ID", 
    [string]\$Location = "$LOCATION",
    [string]\$SubscriptionId = "$SUBSCRIPTION_ID"
)

Write-Host "🚀 Starting Complete Hybrid Worker Recovery" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

\$arcAgent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"

# Step 1: Check prerequisites
Write-Host "`n🔍 Checking Prerequisites..." -ForegroundColor Yellow
if (!(Test-Path \$arcAgent)) {
    Write-Host "❌ Azure Arc agent not found" -ForegroundColor Red
    exit 1
}

# Check if running as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Prerequisites met" -ForegroundColor Green

# Step 2: Stop services before Arc reconnection
Write-Host "`n🛑 Stopping Azure services..." -ForegroundColor Yellow
\$services = @("himds", "ExtensionService", "GCArcService")
foreach (\$service in \$services) {
    try {
        if (Get-Service -Name \$service -ErrorAction SilentlyContinue) {
            Stop-Service -Name \$service -Force -ErrorAction SilentlyContinue
            Write-Host "✅ Stopped: \$service" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not stop \$service (may not exist)" -ForegroundColor Yellow
    }
}

# Step 3: Disconnect Arc agent
Write-Host "`n🔌 Disconnecting Arc Agent..." -ForegroundColor Yellow
try {
    & \$arcAgent disconnect --force-local-only
    Write-Host "✅ Arc agent disconnected" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Disconnect warning: \$_" -ForegroundColor Yellow
}

# Step 4: Reconnect Arc agent
Write-Host "`n🔗 Reconnecting Arc Agent..." -ForegroundColor Yellow
try {
    & \$arcAgent connect \`
        --resource-group \$ResourceGroup \`
        --tenant-id \$TenantId \`
        --location \$Location \`
        --subscription-id \$SubscriptionId \`
        --correlation-id "full-recovery-\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "✅ Arc agent reconnected" -ForegroundColor Green
} catch {
    Write-Host "❌ Arc reconnection failed: \$_" -ForegroundColor Red
    exit 1
}

# Step 5: Wait and start services
Write-Host "`n⏳ Waiting 30 seconds for Arc stabilization..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`n🔄 Starting Azure services..." -ForegroundColor Yellow
foreach (\$service in \$services) {
    try {
        if (Get-Service -Name \$service -ErrorAction SilentlyContinue) {
            Start-Service -Name \$service -ErrorAction SilentlyContinue
            Write-Host "✅ Started: \$service" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not start \$service: \$_" -ForegroundColor Yellow
    }
}

# Step 6: Verify Arc connection
Write-Host "`n📊 Verifying Arc Connection..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
try {
    \$arcStatus = & \$arcAgent show
    Write-Host "✅ Arc agent verification completed" -ForegroundColor Green
    Write-Host \$arcStatus
} catch {
    Write-Host "❌ Arc verification failed: \$_" -ForegroundColor Red
}

Write-Host "`n🎉 Recovery process completed!" -ForegroundColor Green
Write-Host "Monitor hybrid worker status in Azure portal" -ForegroundColor Green
Write-Host "Worker should check in within 2-5 minutes" -ForegroundColor Green
EOF

echo "✅ Created recovery script: hybrid-worker-full-recovery.ps1"

# Try SSH execution first
echo ""
echo "🚀 Attempting SSH Execution..."
echo "============================="

if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=15 demoadmin@4.227.115.235 "ssh -o ConnectTimeout=15 demoadmin@10.0.0.5 'echo SSH_WORKS'" 2>/dev/null | grep -q "SSH_WORKS"; then
    echo "✅ SSH connection working - executing recovery script"
    
    # Upload and execute the script
    scp -i ~/.ssh/id_ed25519 hybrid-worker-full-recovery.ps1 demoadmin@4.227.115.235:/tmp/recovery.ps1 2>/dev/null
    
    ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 << 'SSH_EXEC'
# Copy script to ca01 and execute
echo "Transferring script to ca01..."
scp -i C:\Users\demoadmin\.ssh\id_ed25519 /tmp/recovery.ps1 demoadmin@10.0.0.5:C:\temp\recovery.ps1

echo "Executing recovery script on ca01..."
ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 "powershell.exe -ExecutionPolicy Bypass -File C:\temp\recovery.ps1"
SSH_EXEC

    recovery_exit_code=$?
    
    if [ $recovery_exit_code -eq 0 ]; then
        echo "✅ Recovery script executed successfully via SSH"
        AUTO_EXECUTED=true
    else
        echo "❌ SSH execution failed - will provide manual instructions"
        AUTO_EXECUTED=false
    fi
else
    echo "❌ SSH connection failed - will provide manual instructions"
    AUTO_EXECUTED=false
fi

if [ "$AUTO_EXECUTED" != true ]; then
    echo ""
    echo "📝 Manual Execution Required:"
    echo "============================"
    echo "1. RDP to ca01 via dc01:"
    echo "   ssh demoadmin@4.227.115.235"
    echo "   mstsc /v:10.0.0.5"
    echo ""
    echo "2. Copy hybrid-worker-full-recovery.ps1 to ca01"
    echo ""
    echo "3. Run as Administrator:"
    echo "   PowerShell -ExecutionPolicy Bypass -File hybrid-worker-full-recovery.ps1"
fi

echo ""
echo "📊 Step 2: Automated Monitoring"
echo "=============================="
echo "Starting 5-minute monitoring cycle..."

# Monitor for up to 5 minutes (10 checks, 30 seconds apart)
for i in {1..10}; do
    echo ""
    echo "[$i/10] Checking worker status..."
    
    current_status=$(check_worker_status)
    echo "Last Seen: $current_status"
    
    if is_worker_online "$current_status"; then
        echo ""
        echo "🎉 SUCCESS! Hybrid Worker is now ONLINE!"
        echo "========================================"
        echo "✅ Last Seen: $current_status"
        echo "✅ Worker is communicating with Azure"
        echo "✅ Certificate automation should now work"
        
        # Verify in Azure Arc as well
        echo ""
        echo "🔍 Verifying Azure Arc connection..."
        if az connectedmachine show --resource-group "$RESOURCE_GROUP" --name "ca01" --query "status" --output tsv 2>/dev/null | grep -q "Connected"; then
            echo "✅ Azure Arc: Connected"
        else
            echo "⚠️ Azure Arc: Still connecting (may take a few more minutes)"
        fi
        
        exit 0
    else
        if [ $i -lt 10 ]; then
            echo "⏳ Still offline - waiting 30 seconds..."
            sleep 30
        fi
    fi
done

echo ""
echo "⚠️ Recovery Monitoring Complete"
echo "==============================="
echo "Worker did not come online within 5 minutes"
echo "This may indicate:"
echo "1. Manual intervention is still required"
echo "2. Network/firewall issues preventing Azure connectivity"
echo "3. Arc agent installation problems"
echo ""
echo "💡 Next steps:"
echo "- Check the manual execution results on ca01"
echo "- Verify network connectivity to Azure endpoints"
echo "- Continue monitoring with: ./monitor-hybrid-worker.sh"