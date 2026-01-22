#!/bin/bash

echo "🔍 How to Check Hybrid Worker in Azure Portal"
echo "============================================="
echo "Corrected: Portal shows 'Last Seen' and 'Registration Time', not 'Status'"
echo ""

# Get current worker info first
source certlc-deployment-scripts/.env
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

echo "📊 Current Hybrid Worker Information:"
echo "===================================="

worker_info=$(az rest \
    --method GET \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups/EnterpriseRootCA/hybridRunbookWorkers/f47ceb57-e588-5f42-8431-78e508a58d3d?api-version=2023-11-01" \
    --output json)

echo "Worker Name: $(echo "$worker_info" | jq -r '.properties.workerName')"
echo "Worker ID: $(echo "$worker_info" | jq -r '.name')"
echo "IP Address: $(echo "$worker_info" | jq -r '.properties.ip')"
echo "Worker Type: $(echo "$worker_info" | jq -r '.properties.workerType')"
echo "Registration Time: $(echo "$worker_info" | jq -r '.properties.registeredDateTime')"
echo "Last Seen Time: $(echo "$worker_info" | jq -r '.properties.lastSeenDateTime')"

# Calculate time difference
last_seen=$(echo "$worker_info" | jq -r '.properties.lastSeenDateTime')
current_time=$(date -u +"%Y-%m-%dT%H:%M:%S")

echo ""
echo "🕐 Time Analysis:"
echo "================"
echo "Last Seen: $last_seen"
echo "Current Time: $current_time"

# Parse dates for comparison (simplified)
if [[ "$last_seen" == *"2025-11-02"* ]]; then
    echo "✅ Status: ONLINE (checked in today)"
elif [[ "$last_seen" == *"2025-11-01"* ]]; then
    echo "⚠️  Status: Checked in yesterday"
else
    echo "❌ Status: OFFLINE (last seen: $last_seen)"
fi

echo ""
echo "📋 Azure Portal Navigation:"
echo "=========================="
echo "1. Go to: https://portal.azure.com"
echo "2. Navigate to: Resource Groups → rg-demo-certlc → DEMO-AA-1030164500"
echo "3. Click: Automation → Process Automation → Hybrid worker groups"
echo "4. Click: EnterpriseRootCA"
echo "5. Look for worker: ca01 (IP: 10.0.0.5)"
echo ""

echo "🎯 What to Look for in Portal:"
echo "=============================="
echo "Field                | Expected Value        | Current Value"
echo "==================== | ==================== | =========================="
echo "Name                 | ca01                  | ca01"
echo "IP Address           | 10.0.0.5              | 10.0.0.5"
echo "Registration Time    | 2025-10-31T00:01:38   | 2025-10-31T00:01:38"
echo "Last Seen            | Recent (within 5 min) | 2025-10-31T08:27:23"
echo ""

echo "🚨 Current Issue:"
echo "================"
echo "❌ Last Seen: Over 1.5 days ago (October 31st at 8:27 AM)"
echo "❌ Should show: Today's date/time if worker is healthy"
echo ""

echo "✅ Success Criteria:"
echo "==================="
echo "- Last Seen should update to current date/time after Arc service restart"
echo "- Typically updates within 2-5 minutes of service restart"
echo "- Registration Time should remain unchanged (shows initial setup)"
echo ""

echo "🔄 To Fix:"
echo "=========="
echo "1. Connect to ca01 manually (RDP via dc01)"
echo "2. Restart Azure Arc services in PowerShell:"
echo "   Restart-Service himds -Force"
echo "3. Wait 2-5 minutes and refresh portal"
echo "4. Last Seen should update to current time"

echo ""
echo "📈 Monitor Progress:"
echo "==================="
echo "Run: ./monitor-hybrid-worker.sh"
echo "This script checks every 30 seconds for Last Seen updates"