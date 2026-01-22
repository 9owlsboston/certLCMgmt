#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - RBAC Permissions Setup
# =============================================================================

set -e  # Exit on any error

# Source environment variables
if [ -f "./01-environment-setup.sh" ]; then
    source ./01-environment-setup.sh
else
    echo "ERROR: Please run 01-environment-setup.sh first to set environment variables"
    exit 1
fi

echo "Setting up RBAC permissions for certificate lifecycle management..."

# =============================================================================
# ROLE ASSIGNMENT HELPER FUNCTIONS
# =============================================================================

# Helper function to assign role if not already assigned
assign_role_if_not_exists() {
    local principal_id="$1"
    local role="$2"
    local scope="$3"
    local description="$4"
    
    # Check if role assignment already exists
    if az role assignment list \
        --assignee "$principal_id" \
        --role "$role" \
        --scope "$scope" \
        --query "[?principalId=='$principal_id' && roleDefinitionName=='$role']" \
        --output tsv | grep -q .; then
        echo "✓ Role '$role' already assigned to $description"
    else
        echo "Assigning role '$role' to $description..."
        az role assignment create \
            --assignee "$principal_id" \
            --role "$role" \
            --scope "$scope"
        echo "✓ Role assignment completed"
    fi
}

# =============================================================================
# GET SERVICE PRINCIPAL IDS
# =============================================================================

echo "Retrieving service principal IDs..."

# Get Automation Account managed identity principal ID
AUTOMATION_PRINCIPAL_ID=$(az automation account show \
    --name "$AUTOMATION_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "identity.principalId" -o tsv)

if [ -z "$AUTOMATION_PRINCIPAL_ID" ] || [ "$AUTOMATION_PRINCIPAL_ID" = "null" ]; then
    echo "ERROR: Could not retrieve Automation Account principal ID"
    echo "Make sure the Automation Account has a system-assigned managed identity enabled"
    exit 1
fi

echo "Automation Account Principal ID: $AUTOMATION_PRINCIPAL_ID"

# =============================================================================
# GET RESOURCE IDS
# =============================================================================

echo "Retrieving resource IDs for permission assignment..."

# Key Vault resource ID
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    KEY_VAULT_ID=$(az keyvault show \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    echo "✓ Key Vault ID retrieved: $KEY_VAULT_ID"
else
    echo "ERROR: Key Vault '$KEY_VAULT_NAME' not found"
    exit 1
fi

# Storage Account resource ID
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    STORAGE_ACCOUNT_ID=$(az storage account show \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    echo "✓ Storage Account ID retrieved: $STORAGE_ACCOUNT_ID"
else
    echo "ERROR: Storage Account '$STORAGE_ACCOUNT_NAME' not found"
    exit 1
fi

# Log Analytics Workspace resource ID
if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    WORKSPACE_ID=$(az monitor log-analytics workspace show \
        --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    echo "✓ Log Analytics Workspace ID retrieved: $WORKSPACE_ID"
else
    echo "ERROR: Log Analytics Workspace '$LOG_ANALYTICS_WORKSPACE_NAME' not found"
    exit 1
fi

# Data Collection Rule resource ID
if az monitor data-collection rule show --name "$DATA_COLLECTION_RULE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    DCR_ID=$(az monitor data-collection rule show \
        --name "$DATA_COLLECTION_RULE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    echo "✓ Data Collection Rule ID retrieved: $DCR_ID"
else
    echo "WARNING: Data Collection Rule '$DATA_COLLECTION_RULE_NAME' not found, skipping DCR permissions"
    DCR_ID=""
fi

# Data Collection Endpoint resource ID
if az monitor data-collection endpoint show --name "$DATA_COLLECTION_ENDPOINT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    DCE_ID=$(az monitor data-collection endpoint show \
        --name "$DATA_COLLECTION_ENDPOINT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    echo "✓ Data Collection Endpoint ID retrieved: $DCE_ID"
else
    echo "WARNING: Data Collection Endpoint '$DATA_COLLECTION_ENDPOINT_NAME' not found, skipping DCE permissions"
    DCE_ID=""
fi

echo "Resource ID retrieval completed"

# =============================================================================
# KEY VAULT PERMISSIONS
# =============================================================================

echo "Assigning Key Vault permissions..."

# Key Vault Certificates Officer role - allows reading and managing certificates
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Key Vault Certificates Officer" \
    "$KEY_VAULT_ID" \
    "Automation Account (Key Vault Certificates)"

# Key Vault Secrets User role - allows reading secrets (for certificate private keys)
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Key Vault Secrets User" \
    "$KEY_VAULT_ID" \
    "Automation Account (Key Vault Secrets)"

# =============================================================================
# STORAGE ACCOUNT PERMISSIONS
# =============================================================================

echo "Assigning Storage Account permissions..."

# Reader role on storage account
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Reader" \
    "$STORAGE_ACCOUNT_ID" \
    "Automation Account (Storage Account Reader)"

# Storage Queue Data Contributor role - allows reading from and writing to queues
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Storage Queue Data Contributor" \
    "$STORAGE_ACCOUNT_ID" \
    "Automation Account (Storage Queue Contributor)"

# Storage Queue Data Message Processor role - allows processing queue messages
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Storage Queue Data Message Processor" \
    "$STORAGE_ACCOUNT_ID" \
    "Automation Account (Storage Queue Processor)"

# =============================================================================
# LOG ANALYTICS PERMISSIONS
# =============================================================================

echo "Assigning Log Analytics permissions..."

# Monitoring Metrics Publisher role - allows publishing custom metrics and logs
assign_role_if_not_exists \
    "$AUTOMATION_PRINCIPAL_ID" \
    "Monitoring Metrics Publisher" \
    "$WORKSPACE_ID" \
    "Automation Account (Log Analytics Metrics)"

# =============================================================================
# DATA COLLECTION PERMISSIONS
# =============================================================================

echo "Assigning Data Collection permissions..."

# Monitoring Metrics Publisher role on Data Collection Rule (if exists)
if [ -n "$DCR_ID" ]; then
    assign_role_if_not_exists \
        "$AUTOMATION_PRINCIPAL_ID" \
        "Monitoring Metrics Publisher" \
        "$DCR_ID" \
        "Automation Account (Data Collection Rule)"
else
    echo "⚠ Skipping Data Collection Rule permissions (resource not found)"
fi

# Monitoring Metrics Publisher role on Data Collection Endpoint (if exists)
if [ -n "$DCE_ID" ]; then
    assign_role_if_not_exists \
        "$AUTOMATION_PRINCIPAL_ID" \
        "Monitoring Metrics Publisher" \
        "$DCE_ID" \
        "Automation Account (Data Collection Endpoint)"
else
    echo "⚠ Skipping Data Collection Endpoint permissions (resource not found)"
fi

# =============================================================================
# RESOURCE GROUP PERMISSIONS
# =============================================================================

echo "Assigning Resource Group permissions..."

# Get Resource Group ID
RESOURCE_GROUP_ID=$(az group show \
    --name "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

# Reader role on resource group - allows reading all resources in the group
az role assignment create \
    --assignee "$AUTOMATION_PRINCIPAL_ID" \
    --role "Reader" \
    --scope "$RESOURCE_GROUP_ID"

echo "✓ Reader role assigned to Resource Group"

# =============================================================================
# SUBSCRIPTION LEVEL PERMISSIONS (OPTIONAL)
# =============================================================================

echo "Checking subscription-level permissions..."

# Key Vault Reader role at subscription level (for discovering Key Vaults)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
SUBSCRIPTION_SCOPE="/subscriptions/$SUBSCRIPTION_ID"

# Check if user wants to assign subscription-level permissions
read -p "Do you want to assign Key Vault Reader role at subscription level? This allows automatic discovery of all Key Vaults. (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    az role assignment create \
        --assignee "$AUTOMATION_PRINCIPAL_ID" \
        --role "Key Vault Reader" \
        --scope "$SUBSCRIPTION_SCOPE"
    
    echo "✓ Key Vault Reader role assigned at subscription level"
else
    echo "⚠ Skipped subscription-level Key Vault Reader role assignment"
    echo "  Note: The automation will only work with the specific Key Vault created"
fi

# =============================================================================
# VERIFY PERMISSIONS
# =============================================================================

echo ""
echo "Verifying assigned permissions..."

echo "Key Vault permissions:"
az role assignment list \
    --assignee "$AUTOMATION_PRINCIPAL_ID" \
    --scope "$KEY_VAULT_ID" \
    --query "[].roleDefinitionName" -o table

echo ""
echo "Storage Account permissions:"
az role assignment list \
    --assignee "$AUTOMATION_PRINCIPAL_ID" \
    --scope "$STORAGE_ACCOUNT_ID" \
    --query "[].roleDefinitionName" -o table

echo ""
echo "Log Analytics permissions:"
az role assignment list \
    --assignee "$AUTOMATION_PRINCIPAL_ID" \
    --scope "$WORKSPACE_ID" \
    --query "[].roleDefinitionName" -o table

# =============================================================================
# CREATE SAVED SEARCHES IN LOG ANALYTICS
# =============================================================================

echo "Creating saved searches in Log Analytics..."

# Certificate list query
az monitor log-analytics workspace saved-search create \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --saved-search-id "CERTLC-certificate-list" \
    --display-name "CERTLC - certificate list" \
    --category "CERTLC" \
    --query "${TABLE_NAME}_CL | extend ExpirationDate = todatetime(CertExpiration) | extend ExpiryStatus = case(ExpirationDate <= now(), 'Expired', ExpirationDate <= now() + 5d, 'Expiring in 5 Days', 'Not Expired') | where TimeGenerated == toscalar(${TABLE_NAME}_CL | summarize max(TimeGenerated)) | project ExpiryStatus, CertExpiration, CertName, CertSubject, CertRecipient, KeyVault, CertThumbprint, TimeGenerated | sort by ExpiryStatus"

# Certificate status query
az monitor log-analytics workspace saved-search create \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --saved-search-id "CERTLC-certificate-status" \
    --display-name "CERTLC - certificate status" \
    --category "CERTLC" \
    --query "${TABLE_NAME}_CL | where TimeGenerated == toscalar(${TABLE_NAME}_CL | summarize max(TimeGenerated)) | extend ExpiryStatus = case(todatetime(CertExpiration) <= now(), 'Expired', todatetime(CertExpiration) <= now() + 5d, 'Expiring in 5 Days', 'Not Expired') | summarize CertificateCount = count() by ExpiryStatus"

echo "✓ Saved searches created successfully"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "RBAC PERMISSIONS SETUP COMPLETED SUCCESSFULLY"
echo "==============================================================================="
echo "Automation Account Principal ID: $AUTOMATION_PRINCIPAL_ID"
echo ""
echo "Key Vault Permissions ($KEY_VAULT_NAME):"
echo "  ✓ Key Vault Certificates Officer"
echo "  ✓ Key Vault Secrets User"
echo ""
echo "Storage Account Permissions ($STORAGE_ACCOUNT_NAME):"
echo "  ✓ Reader"
echo "  ✓ Storage Queue Data Contributor"
echo "  ✓ Storage Queue Data Message Processor"
echo ""
echo "Log Analytics Permissions ($LOG_ANALYTICS_WORKSPACE_NAME):"
echo "  ✓ Monitoring Metrics Publisher"
echo ""
echo "Data Collection Permissions:"
echo "  ✓ Monitoring Metrics Publisher (DCR)"
echo "  ✓ Monitoring Metrics Publisher (DCE)"
echo ""
echo "Resource Group Permissions ($RESOURCE_GROUP_NAME):"
echo "  ✓ Reader"
echo ""
echo "Additional Components Created:"
echo "  ✓ Saved searches for certificate monitoring"
echo ""
echo "==============================================================================="
echo "AZURE CERTIFICATE MANAGEMENT SERVICES SETUP COMPLETE!"
echo "==============================================================================="
echo ""
echo "Your certificate lifecycle management system is now ready!"
echo ""
echo "Next steps:"
echo "1. Add certificates to Key Vault: $KEY_VAULT_NAME"
echo "2. Configure certificate expiry notifications (30 days before expiry)"
echo "3. Monitor the dashboard in Log Analytics: $LOG_ANALYTICS_WORKSPACE_NAME"
echo "4. Check automation jobs in: $AUTOMATION_ACCOUNT_NAME"
echo ""
echo "Key Components:"
echo "• Event Grid will detect certificate near-expiry events"
echo "• Notifications will be sent to queue: $QUEUE_NAME"
echo "• Webhooks will trigger immediate processing"
echo "• Scheduled jobs will run certificate monitoring every 4 hours"
echo "• Dashboard data will be updated every hour"
echo ""
echo "Monitoring URLs:"
echo "• Key Vault: https://portal.azure.com/#@/resource$KEY_VAULT_ID"
echo "• Automation: https://portal.azure.com/#@/resource$AUTOMATION_ACCOUNT_ID"
echo "• Log Analytics: https://portal.azure.com/#@/resource$WORKSPACE_ID"
echo "==============================================================================="