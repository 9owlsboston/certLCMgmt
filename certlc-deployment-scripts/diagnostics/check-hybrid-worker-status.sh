#!/bin/bash

# Load configuration from .env file  
if [ -f "../.env" ]; then
    source ../.env
    echo "✅ Configuration loaded from .env file"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
    echo "Subscription: $SUBSCRIPTION_ID"
else
    echo "❌ .env file not found"
    exit 1
fi

echo "========================================"
echo "Hybrid Worker Status Check (Azure CLI)"
echo "========================================"

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
    echo "❌ Not logged into Azure CLI. Please run 'az login'"
    exit 1
fi

# Set subscription
echo "🔄 Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Check hybrid worker groups
echo "🔍 Checking hybrid worker groups..."
az automation hrwg list \
    --resource-group "$RESOURCE_GROUP" \
    --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
    --output table

# Check specific hybrid worker group details
echo ""
echo "🔍 Checking EnterpriseRootCA worker group details..."
az automation hrwg show \
    --resource-group "$RESOURCE_GROUP" \
    --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
    --hybrid-runbook-worker-group-name "EnterpriseRootCA" \
    --output json

# List hybrid workers in the group
echo ""
echo "🔍 Listing workers in EnterpriseRootCA group..."
az automation hrwg hrw list \
    --resource-group "$RESOURCE_GROUP" \
    --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
    --hybrid-runbook-worker-group-name "EnterpriseRootCA" \
    --output table

echo ""
echo "✅ Hybrid worker status check completed!"