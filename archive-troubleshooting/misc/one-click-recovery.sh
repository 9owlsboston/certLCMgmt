#!/bin/bash

echo "🎯 Simple One-Click Recovery"
echo "============================"
echo "This script tries all methods to recover the hybrid worker"
echo ""

# Load configuration
source certlc-deployment-scripts/.env

# Function to check worker status
check_worker() {
    local subscription_id
    subscription_id=$(az account show --query id --output tsv)
    az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$subscription_id/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups/EnterpriseRootCA/hybridRunbookWorkers/f47ceb57-e588-5f42-8431-78e508a58d3d?api-version=2023-11-01" \
        --query "properties.lastSeenDateTime" \
        --output tsv
}

echo "📊 Current Status:"
echo "=================="
current_status=$(check_worker)
echo "Last Seen: $current_status"

if [[ "$current_status" == *"$(date +%Y-%m-%d)"* ]]; then
    echo "✅ Worker is already online!"
    exit 0
fi

echo "❌ Worker offline - starting recovery..."
echo ""

# Create minimal PowerShell script
cat > quick-fix.ps1 << 'EOF'
Write-Host "Quick Arc Agent Fix" -ForegroundColor Green
$agent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"
if (Test-Path $agent) {
    Write-Host "Disconnecting..." -ForegroundColor Yellow
    & $agent disconnect --force-local-only
    Write-Host "Reconnecting..." -ForegroundColor Yellow  
    & $agent connect --resource-group "rg-demo-certlc" --tenant-id "b7e530b3-a1e1-465c-b820-dfddb9e77e7d" --location "westus3" --subscription-id "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
    Write-Host "Restarting services..." -ForegroundColor Yellow
    Restart-Service himds -Force
    Write-Host "Done!" -ForegroundColor Green
} else {
    Write-Host "Arc agent not found!" -ForegroundColor Red
}
EOF

echo "🚀 Attempting Quick Recovery..."
echo "=============================="

# Try SSH method - fixed for Windows jump host
echo "Testing SSH to dc01 (Windows)..."
if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=5 demoadmin@4.227.115.235 "echo DC01_READY" 2>/dev/null | grep -q "DC01_READY"; then
    echo "✅ DC01 reachable via SSH"
    
    echo "Testing SSH chain to ca01..."
    if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 -o ConnectTimeout=5 demoadmin@10.0.0.5 \"echo CA01_READY\"" 2>/dev/null | grep -q "CA01_READY"; then
        echo "✅ CA01 reachable via SSH chain - executing fix"
        
        # Upload script to dc01
        scp -i ~/.ssh/id_ed25519 quick-fix.ps1 demoadmin@4.227.115.235:C:/temp/fix.ps1
        
        # Execute via SSH chain
        ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "scp -i C:\Users\demoadmin\.ssh\id_ed25519 C:\temp\fix.ps1 demoadmin@10.0.0.5:C:\temp\fix.ps1"
        ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 \"powershell.exe -ExecutionPolicy Bypass -File C:\temp\fix.ps1\""
        
        echo "✅ Recovery script executed"
    else
        echo "❌ CA01 not reachable via SSH chain"
        echo "💡 SSH keys may not be properly configured between dc01 and ca01"
    fi
else
    echo "❌ DC01 not reachable via SSH"
fi

echo ""
echo "📊 Monitoring for 2 minutes..."
echo "============================="

for i in {1..4}; do
    echo "Check $i/4:"
    new_status=$(check_worker)
    echo "Last Seen: $new_status"
    
    if [[ "$new_status" == *"$(date +%Y-%m-%d)"* ]]; then
        echo ""
        echo "🎉 SUCCESS! Worker is now online!"
        echo "================================"
        exit 0
    fi
    
    if [ $i -lt 4 ]; then
        echo "Waiting 30 seconds..."
        sleep 30
    fi
done

echo ""
echo "⚠️ Automated recovery didn't work"
echo "================================="
echo "Manual steps required:"
echo "1. RDP to ca01: ssh demoadmin@4.227.115.235 → mstsc /v:10.0.0.5"
echo "2. Run as Admin: PowerShell -ExecutionPolicy Bypass -File quick-fix.ps1"
echo "3. Monitor: ./monitor-hybrid-worker.sh"