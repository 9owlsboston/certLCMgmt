#!/bin/bash

# Load environment variables
source certlc-deployment-scripts/.env

echo "🔍 Checking Hybrid Worker Status via Azure REST API"
echo "=================================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo ""

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure CLI. Please run: az login"
    exit 1
fi

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Subscription: $SUBSCRIPTION_ID"
echo ""

# Use Azure REST API via az rest command (more reliable than automation extension)
echo "📋 Checking Hybrid Worker Groups via REST API:"
echo "---------------------------------------------"

# List hybrid worker groups
echo "Getting hybrid worker groups..."
az rest \
    --method GET \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups?api-version=2023-11-01" \
    --query "value[].{Name:name, GroupType:properties.groupType}" \
    --output table

echo ""
echo "🔍 Getting detailed worker information:"
echo "------------------------------------"

# Get worker groups and then list workers in each
groups=$(az rest \
    --method GET \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups?api-version=2023-11-01" \
    --query "value[].name" \
    --output tsv)

for group in $groups; do
    echo ""
    echo "Group: $group"
    echo "-------------"
    
    # Get workers in this group
    az rest \
        --method GET \
        --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME/hybridRunbookWorkerGroups/$group/hybridRunbookWorkers?api-version=2023-11-01" \
        --query "value[].{Name:name, IP:properties.ip, LastSeen:properties.lastSeenDateTime, Version:properties.workerVersion}" \
        --output table 2>/dev/null || echo "No workers found in group $group"
done

echo ""
echo "🕐 Current Time: $(date)"
echo ""
echo "✅ Look for:"
echo "   - Worker name containing 'ca01' or your machine name"
echo "   - Recent 'LastSeen' time (within last 5-10 minutes)"
echo "   - Correct IP address (10.0.0.5 for ca01)"
echo ""
echo "💡 If workers show as offline, the service restart should resolve it"
echo "💡 If no workers found, check if hybrid worker is properly registered"