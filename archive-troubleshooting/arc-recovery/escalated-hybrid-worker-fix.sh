#!/bin/bash

echo "🚨 Hybrid Worker Still Offline After Extended Monitoring"
echo "======================================================="
echo "Issue: Last Seen still shows 2025-10-31T08:27:23 after 1+ hours"
echo "Conclusion: Azure Arc agent requires direct manual intervention"
echo ""

source certlc-deployment-scripts/.env

echo "📊 Current Status Summary:"
echo "========================="
echo "✅ Worker Registration: Valid (f47ceb57-e588-5f42-8431-78e508a58d3d)"
echo "✅ IP Address: Correct (10.0.0.5)"
echo "✅ Worker Type: HybridV2 (Azure Arc)"
echo "❌ Last Seen: 2025-10-31T08:27:23 (1.5+ days ago)"
echo "❌ Arc Agent: Likely disconnected/failed"
echo ""

echo "🎯 Required Actions (Manual Intervention Needed):"
echo "================================================="

cat << 'DIRECT_ACTIONS'

Since remote SSH restart didn't work, direct access to ca01 is required:

🔗 Method 1: RDP to CA01 (Recommended)
====================================
1. Connect to dc01: ssh demoadmin@4.227.115.235
2. From dc01 command prompt: mstsc /v:10.0.0.5
3. Login to ca01 as: demo\demoadmin
4. Open PowerShell as Administrator

🔗 Method 2: Direct Network Access (if available)
===============================================
If ca01 has direct network access, try:
- RDP directly to public IP (if configured)
- VPN connection to internal network
- Azure Bastion (if deployed)

🔧 On CA01 - PowerShell Commands to Run:
======================================

# 1. Check Azure Arc Agent Status
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show

# 2. Check critical services
Get-Service himds, ExtensionService, GCArcService | Format-Table Name, Status, StartType

# 3. Check for Arc agent errors
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='*Azure*'} -MaxEvents 20 | 
    Select-Object TimeCreated, LevelDisplayName, ProviderName, Message | Format-List

# 4. Restart Arc services forcefully
Stop-Service himds, ExtensionService, GCArcService -Force
Start-Service himds

# 5. If Arc agent is disconnected, reconnect:
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" disconnect --force-local-only
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --resource-group "rg-demo-certlc" `
  --tenant-id "b7e530b3-a1e1-465c-b820-dfddb9e77e7d" `
  --location "westus3" `
  --subscription-id "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0" `
  --correlation-id "hybridworker-fix-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# 6. Verify connection after 2-3 minutes
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show

DIRECT_ACTIONS

echo ""
echo "🔍 Alternative Diagnostic Commands:"
echo "=================================="

# Check if we can get more details about the automation account
echo "Checking Automation Account extensions and configuration..."

SUBSCRIPTION_ID=$(az account show --query id --output tsv)

echo ""
echo "📋 Automation Account Extensions:"
az rest \
    --method GET \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME?api-version=2023-11-01" \
    --query "{Name:name, State:properties.state, RuntimeConfiguration:properties.runtimeConfiguration}" \
    --output table

echo ""
echo "📋 Checking if VM has Arc agent installed in Azure:"
az connectedmachine show \
    --resource-group "$RESOURCE_GROUP" \
    --name "ca01" \
    --query "{Name:name, Status:status, AgentVersion:agentVersion, LastStatusChange:lastStatusChange}" \
    --output table 2>/dev/null || echo "❌ CA01 not found in Azure Arc or not connected"

echo ""
echo "🎯 Next Steps Priority:"
echo "======================"
echo "1. 🔴 HIGH: Direct RDP to ca01 and run the PowerShell commands above"
echo "2. 🟡 MED: If Arc agent reconnection fails, check network/firewall"
echo "3. 🟢 LOW: Monitor with: ./monitor-hybrid-worker.sh after manual fix"
echo ""
echo "⏱️  Expected Timeline:"
echo "- Arc agent reconnection: 2-5 minutes"
echo "- Hybrid worker check-in: 2-5 minutes after Arc connection"
echo "- Total: 5-10 minutes for full recovery"

echo ""
echo "🔄 Continue Monitoring:"
echo "======================"
echo "After manual intervention, run: ./monitor-hybrid-worker.sh"
echo "Look for Last Seen timestamp to update to today's date"