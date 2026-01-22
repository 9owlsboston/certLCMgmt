#!/bin/bash

# Monitor hybrid worker status in real-time
source certlc-deployment-scripts/.env

echo "🔄 Monitoring Hybrid Worker Status (checking every 30 seconds)"
echo "============================================================="
echo "Worker Group: EnterpriseRootCA"
echo "Expected IP: 10.0.0.5"
echo "Press Ctrl+C to stop monitoring"
echo ""

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
count=1

while true; do
    timestamp=$(date)
    echo "[$count] Check at: $timestamp"
    echo "----------------------------------------"
    
    # Get worker status
    result=$(az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups/EnterpriseRootCA/hybridRunbookWorkers?api-version=2023-11-01" \
        --query "value[0].{Name:name, IP:properties.ip, LastSeen:properties.lastSeenDateTime}" \
        --output json 2>/dev/null)
    
    if [ "$result" != "null" ] && [ -n "$result" ]; then
        name=$(echo "$result" | jq -r '.Name // "unknown"')
        ip=$(echo "$result" | jq -r '.IP // "unknown"')
        lastSeen=$(echo "$result" | jq -r '.LastSeen // "unknown"')
        
        echo "Worker Name: $name"
        echo "IP Address: $ip"
        echo "Last Seen: $lastSeen"
        
        # Check if recently updated (today's date)
        current_date=$(date +"%Y-%m-%d")
        if [[ "$lastSeen" == *"$current_date"* ]]; then
            echo "🎉 SUCCESS! Worker is now ONLINE (Last Seen updated to today)" 
            echo "✅ Hybrid worker service restart was successful!"
            echo ""
            echo "📋 Final Status:"
            echo "   - Worker Group: EnterpriseRootCA"
            echo "   - Worker Name: ca01"
            echo "   - Worker IP: $ip"
            echo "   - Last Seen: $lastSeen (UPDATED TODAY)"
            echo "   - Status: Worker is communicating with Azure"
            break
        else
            echo "⏳ Still showing old timestamp - waiting for Last Seen to update..."
            echo "   Current Last Seen: $lastSeen"
            echo "   Looking for: Any timestamp from $current_date"
        fi
    else
        echo "❌ Could not retrieve worker status"
    fi
    
    echo ""
    count=$((count + 1))
    sleep 30
done

echo ""
echo "🎯 Next Steps:"
echo "1. Verify in Azure Portal that worker shows as 'Connected'"
echo "2. Test running a simple runbook to confirm functionality"
echo "3. Check certificate automation is working properly"