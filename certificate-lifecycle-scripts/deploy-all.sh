#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - Complete Deployment Script
# =============================================================================
# This script is idempotent and can be run multiple times safely.
# =============================================================================

set -e  # Exit on any error

echo "==============================================================================="
echo "Azure Certificate Management Services - Complete Deployment"
echo "==============================================================================="
echo ""
echo "This script will deploy all components for Azure Certificate Management:"
echo "• Azure Key Vault for certificate storage"
echo "• Event Grid for certificate expiry detection" 
echo "• Storage Account with queue for reliable processing"
echo "• Automation Account with PowerShell runbooks"
echo "• Log Analytics for monitoring and dashboards"
echo "• RBAC permissions for secure operations"
echo ""
echo "This deployment is IDEMPOTENT - it can be run multiple times safely."
echo "Existing resources will be detected and preserved."
echo ""
echo "==============================================================================="

# Prompt for confirmation
read -p "Do you want to proceed with the complete deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# =============================================================================
# VALIDATE PREREQUISITES
# =============================================================================

echo "Validating prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Check if curl is available (needed for downloading runbooks)
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is not installed. Please install it first."
    exit 1
fi

# Get current subscription info
CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

echo "✓ Prerequisites validated"
echo "✓ Current subscription: $CURRENT_SUBSCRIPTION"
echo "✓ Subscription ID: $SUBSCRIPTION_ID"

# =============================================================================
# PHASE 1: ENVIRONMENT SETUP
# =============================================================================

echo ""
echo "==============================================================================="
echo "PHASE 1: ENVIRONMENT SETUP"
echo "==============================================================================="

if [ ! -f "./01-environment-setup.sh" ]; then
    echo "ERROR: 01-environment-setup.sh not found in current directory"
    exit 1
fi

chmod +x ./01-environment-setup.sh
./01-environment-setup.sh

echo "✓ Phase 1 completed: Environment setup"

# =============================================================================
# PHASE 2: CORE INFRASTRUCTURE
# =============================================================================

echo ""
echo "==============================================================================="
echo "PHASE 2: CORE INFRASTRUCTURE DEPLOYMENT"
echo "==============================================================================="

if [ ! -f "./02-core-infrastructure.sh" ]; then
    echo "ERROR: 02-core-infrastructure.sh not found in current directory"
    exit 1
fi

chmod +x ./02-core-infrastructure.sh
./02-core-infrastructure.sh

echo "✓ Phase 2 completed: Core infrastructure deployed"

# =============================================================================
# PHASE 3: EVENT GRID SETUP
# =============================================================================

echo ""
echo "==============================================================================="
echo "PHASE 3: EVENT GRID CONFIGURATION"
echo "==============================================================================="

if [ ! -f "./03-event-grid-setup.sh" ]; then
    echo "ERROR: 03-event-grid-setup.sh not found in current directory"
    exit 1
fi

chmod +x ./03-event-grid-setup.sh
./03-event-grid-setup.sh

echo "✓ Phase 3 completed: Event Grid configured"

# =============================================================================
# PHASE 4: AUTOMATION SETUP
# =============================================================================

echo ""
echo "==============================================================================="
echo "PHASE 4: AUTOMATION COMPONENTS"
echo "==============================================================================="

if [ ! -f "./04-automation-setup.sh" ]; then
    echo "ERROR: 04-automation-setup.sh not found in current directory"
    exit 1
fi

chmod +x ./04-automation-setup.sh
./04-automation-setup.sh

echo "✓ Phase 4 completed: Automation components configured"

# =============================================================================
# PHASE 5: RBAC PERMISSIONS
# =============================================================================

echo ""
echo "==============================================================================="
echo "PHASE 5: SECURITY AND PERMISSIONS"
echo "==============================================================================="

if [ ! -f "./05-rbac-permissions.sh" ]; then
    echo "ERROR: 05-rbac-permissions.sh not found in current directory"
    exit 1
fi

chmod +x ./05-rbac-permissions.sh
./05-rbac-permissions.sh

echo "✓ Phase 5 completed: RBAC permissions configured"

# =============================================================================
# DEPLOYMENT VALIDATION
# =============================================================================

echo ""
echo "==============================================================================="
echo "DEPLOYMENT VALIDATION"
echo "==============================================================================="

# Source environment variables
source ./01-environment-setup.sh

echo "Validating deployed resources..."

# Check Resource Group
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Resource Group: $RESOURCE_GROUP_NAME"
else
    echo "✗ Resource Group: $RESOURCE_GROUP_NAME - NOT FOUND"
fi

# Check Key Vault
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Key Vault: $KEY_VAULT_NAME"
else
    echo "✗ Key Vault: $KEY_VAULT_NAME - NOT FOUND"
fi

# Check Storage Account
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Storage Account: $STORAGE_ACCOUNT_NAME"
else
    echo "✗ Storage Account: $STORAGE_ACCOUNT_NAME - NOT FOUND"
fi

# Check Automation Account
if az automation account show --name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Automation Account: $AUTOMATION_ACCOUNT_NAME"
else
    echo "✗ Automation Account: $AUTOMATION_ACCOUNT_NAME - NOT FOUND"
fi

# Check Event Grid Topic
if az eventgrid system-topic show --name "$EVENT_GRID_TOPIC_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Event Grid Topic: $EVENT_GRID_TOPIC_NAME"
else
    echo "✗ Event Grid Topic: $EVENT_GRID_TOPIC_NAME - NOT FOUND"
fi

# Check Log Analytics Workspace
if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✓ Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE_NAME"
else
    echo "✗ Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE_NAME - NOT FOUND"
fi

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "🎉 AZURE CERTIFICATE MANAGEMENT SERVICES DEPLOYMENT COMPLETED! 🎉"
echo "==============================================================================="
echo ""
echo "📋 DEPLOYMENT SUMMARY:"
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ Component                    │ Name                                          │"
echo "├─────────────────────────────────────────────────────────────────────────────┤"
echo "│ Resource Group               │ $RESOURCE_GROUP_NAME"
echo "│ Key Vault                    │ $KEY_VAULT_NAME"
echo "│ Storage Account              │ $STORAGE_ACCOUNT_NAME"
echo "│ Queue Name                   │ $QUEUE_NAME"
echo "│ Automation Account           │ $AUTOMATION_ACCOUNT_NAME"
echo "│ Event Grid Topic             │ $EVENT_GRID_TOPIC_NAME"
echo "│ Log Analytics Workspace     │ $LOG_ANALYTICS_WORKSPACE_NAME"
echo "│ Data Collection Endpoint    │ $DATA_COLLECTION_ENDPOINT_NAME"
echo "│ Data Collection Rule         │ $DATA_COLLECTION_RULE_NAME"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo ""
echo "🔧 AUTOMATION COMPONENTS:"
echo "• PowerShell Runbooks: CertLifeCycleMgmt, CertLCDashboardDataInjestion"
echo "• Schedules: Certificate monitoring (every 4 hours), Dashboard updates (hourly)"
echo "• Event Subscriptions: Webhook and queue-based processing"
echo "• Variables: SMTP, storage, endpoints, and configuration settings"
echo ""
echo "🔒 SECURITY CONFIGURATION:"
echo "• RBAC permissions configured for Automation Account managed identity"
echo "• Key Vault access with Certificates Officer and Secrets User roles"
echo "• Storage Queue access with Data Contributor and Message Processor roles"
echo "• Log Analytics access with Metrics Publisher role"
echo ""
echo "📊 MONITORING & DASHBOARDS:"
echo "• Custom table: ${TABLE_NAME}_CL in Log Analytics"
echo "• Saved searches for certificate status and listing"
echo "• Data collection rules for automatic log ingestion"
echo ""
echo "🌐 AZURE PORTAL LINKS:"
echo "• Resource Group: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"
echo "• Key Vault: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
echo "• Automation: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME"
echo "• Log Analytics: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_WORKSPACE_NAME"
echo ""
echo "📝 NEXT STEPS:"
echo "1. 📜 Add certificates to Key Vault: $KEY_VAULT_NAME"
echo "2. 🔔 Configure certificate expiry notifications (default: $CERT_EXPIRY_DAYS days)"
echo "3. 📈 Create dashboards in Log Analytics workspace"
echo "4. 🧪 Test the system by creating a test certificate with short expiry"
echo "5. ✉️ Verify email notifications are working"
echo ""
echo "🚀 SYSTEM OPERATION:"
echo "• Event Grid monitors Key Vault for certificate near-expiry events"
echo "• Webhook triggers immediate processing of certificate events"
echo "• Queue provides reliable message processing"
echo "• Scheduled jobs ensure regular certificate monitoring"
echo "• Dashboard data is automatically collected and stored"
echo ""
echo "📖 DOCUMENTATION:"
echo "• View runbook execution history in Automation Account"
echo "• Monitor certificate data in Log Analytics using saved searches"
echo "• Check Event Grid metrics for subscription health"
echo "• Review storage queue for pending certificate renewal requests"
echo ""
echo "==============================================================================="
echo "✅ Deployment completed successfully! Your certificate management system is ready."
echo "==============================================================================="