#!/bin/bash

# Load environment variables
source certlc-deployment-scripts/.env

echo "🔍 Checking Hybrid Worker Status"
echo "================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo ""

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure CLI. Please run: az login"
    exit 1
fi

echo "📋 Listing all Hybrid Worker Groups:"
echo "------------------------------------"
az automation hrwg list \
    --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{Name:name, GroupType:groupType}" \
    --output table

echo ""
echo "🔍 Checking Hybrid Workers in each group:"
echo "----------------------------------------"

# Get all hybrid worker groups
groups=$(az automation hrwg list \
    --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].name" \
    --output tsv)

for group in $groups; do
    echo ""
    echo "Group: $group"
    echo "-------------"
    
    # List workers in this group
    az automation hrwg hrw list \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --hybrid-runbook-worker-group-name "$group" \
        --query "[].{Name:name, IP:ip, LastSeenDateTime:lastSeenDateTime}" \
        --output table 2>/dev/null || echo "No workers found in group $group"
done

echo ""
echo "🕐 Current Time: $(date)"
echo ""
echo "✅ Look for:"
echo "   - Worker name containing 'ca01' or your machine name"
echo "   - Recent 'LastSeenDateTime' (within last 5-10 minutes)"
echo "   - Correct IP address (10.0.0.5 for ca01)"