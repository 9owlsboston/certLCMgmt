#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - Environment Setup
# =============================================================================

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
echo "Loading configuration..."
source "$SCRIPT_DIR/config.sh"

echo "Setting up environment variables for Azure Certificate Management Services..."

# =============================================================================
# ADDITIONAL CERTIFICATE LIFECYCLE SPECIFIC VARIABLES
# =============================================================================

# Certificate Configuration
export QUEUE_NAME="${QUEUE_NAME:-certlc}"
export WEBHOOK_NAME="${WEBHOOK_NAME:-CertLCWebhook}"
export WORKER_GROUP_NAME="${WORKER_GROUP_NAME:-CertLCWorkerGroup}"
export TABLE_NAME="${TABLE_NAME:-Clcdata}"

# Notification Configuration
export SMTP_SERVER="${SMTP_SERVER:-localhost}"
export EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-${NOTIFICATION_EMAIL:-admin@yourdomain.com}}"

# Security Configuration
export CERT_EXPIRY_DAYS="${CERT_EXPIRY_DAYS:-${CERTIFICATE_RENEWAL_DAYS_BEFORE:-30}}"
export WEBHOOK_EXPIRY_HOURS="${WEBHOOK_EXPIRY_HOURS:-8760}"  # 1 year

# Derived variables
export DATA_COLLECTION_ENDPOINT_NAME="${DATA_COLLECTION_ENDPOINT_NAME:-dce-certlc-${UNIQUE_SUFFIX}}"
export DATA_COLLECTION_RULE_NAME="${DATA_COLLECTION_RULE_NAME:-dcr-certlc-${UNIQUE_SUFFIX}}"
export EVENT_GRID_TOPIC_NAME="${EVENT_GRID_TOPIC_NAME:-egt-certlc-${UNIQUE_SUFFIX}}"
export UNIQUE_SUFFIX
export KEY_VAULT_NAME
export STORAGE_ACCOUNT_NAME
export AUTOMATION_ACCOUNT_NAME
export EVENT_GRID_TOPIC_NAME
export LOG_ANALYTICS_WORKSPACE_NAME
export DATA_COLLECTION_ENDPOINT_NAME
export DATA_COLLECTION_RULE_NAME
export QUEUE_NAME
export WEBHOOK_NAME
export WORKER_GROUP_NAME
export TABLE_NAME
export SMTP_SERVER
export EMAIL_RECIPIENT
export CERT_EXPIRY_DAYS
export WEBHOOK_EXPIRY_HOURS

# =============================================================================
# VALIDATION AND SETUP
# =============================================================================

echo "==============================================================================="
echo "Azure Certificate Management Services Configuration"
echo "==============================================================================="
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo "Unique Suffix: $UNIQUE_SUFFIX"
echo ""
echo "Resource Names:"
echo "  Key Vault: $KEY_VAULT_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo "  Event Grid Topic: $EVENT_GRID_TOPIC_NAME"
echo "  Log Analytics: $LOG_ANALYTICS_WORKSPACE_NAME"
echo "==============================================================================="

# Validate Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Set subscription
echo "Setting Azure subscription to: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Register required resource providers
echo "Registering required Azure resource providers..."
echo "  - Registering Microsoft.KeyVault..."
az provider register --namespace Microsoft.KeyVault --wait
echo "  - Registering Microsoft.Storage..."
az provider register --namespace Microsoft.Storage --wait
echo "  - Registering Microsoft.Automation..."
az provider register --namespace Microsoft.Automation --wait
echo "  - Registering Microsoft.EventGrid..."
az provider register --namespace Microsoft.EventGrid --wait
echo "  - Registering Microsoft.OperationalInsights..."
az provider register --namespace Microsoft.OperationalInsights --wait
echo "  - Registering Microsoft.Insights..."
az provider register --namespace Microsoft.Insights --wait

# =============================================================================
# CHECK RESOURCE NAME AVAILABILITY
# =============================================================================

echo ""
echo "Checking resource name availability..."

# Check Key Vault name availability
echo "Checking Key Vault name availability: $KEY_VAULT_NAME"
KV_AVAILABLE=$(az keyvault check-name --name "$KEY_VAULT_NAME" --query "nameAvailable" -o tsv 2>/dev/null || echo "false")
if [ "$KV_AVAILABLE" = "true" ]; then
    echo "✓ Key Vault name '$KEY_VAULT_NAME' is available"
else
    KV_REASON=$(az keyvault check-name --name "$KEY_VAULT_NAME" --query "reason" -o tsv 2>/dev/null || echo "Unknown")
    if [ "$KV_REASON" = "AlreadyExists" ]; then
        echo "⚠ Key Vault name '$KEY_VAULT_NAME' already exists - will check if it's in current resource group"
    else
        echo "❌ Key Vault name '$KEY_VAULT_NAME' is not available: $KV_REASON"
        echo "Please modify the UNIQUE_SUFFIX or KEY_VAULT_NAME in the script and try again"
        exit 1
    fi
fi

# Check Storage Account name availability
echo "Checking Storage Account name availability: $STORAGE_ACCOUNT_NAME"
SA_AVAILABLE=$(az storage account check-name --name "$STORAGE_ACCOUNT_NAME" --query "nameAvailable" -o tsv 2>/dev/null || echo "false")
if [ "$SA_AVAILABLE" = "true" ]; then
    echo "✓ Storage Account name '$STORAGE_ACCOUNT_NAME' is available"
else
    SA_REASON=$(az storage account check-name --name "$STORAGE_ACCOUNT_NAME" --query "reason" -o tsv 2>/dev/null || echo "Unknown")
    if [ "$SA_REASON" = "AlreadyExists" ]; then
        echo "⚠ Storage Account name '$STORAGE_ACCOUNT_NAME' already exists - will check if it's in current resource group"
    else
        echo "❌ Storage Account name '$STORAGE_ACCOUNT_NAME' is not available: $SA_REASON"
        echo "Please modify the UNIQUE_SUFFIX or STORAGE_ACCOUNT_NAME in the script and try again"
        exit 1
    fi
fi

echo "Environment setup completed successfully!"
echo "You can now run the other scripts in sequence."