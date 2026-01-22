#!/bin/bash

# =============================================================================
# Azure Certificate Lifecycle Management - Deployment Validation Script
# =============================================================================
# This script validates that all components of the Certificate Lifecycle
# Management solution have been deployed correctly and are functioning.
# This script is safe to run multiple times.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for validation results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate a resource exists
validate_resource() {
    local resource_type=$1
    local resource_name=$2
    local check_command=$3
    local description=$4
    
    print_status $BLUE "Testing: $description"
    
    if eval "$check_command" >/dev/null 2>&1; then
        print_status $GREEN "✓ PASS: $resource_name exists and is accessible"
        ((TESTS_PASSED++))
        return 0
    else
        print_status $RED "✗ FAIL: $resource_name not found or not accessible"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to validate a configuration
validate_config() {
    local config_name=$1
    local check_command=$2
    local description=$3
    local is_warning=${4:-false}
    
    print_status $BLUE "Testing: $description"
    
    if eval "$check_command" >/dev/null 2>&1; then
        print_status $GREEN "✓ PASS: $config_name is configured correctly"
        ((TESTS_PASSED++))
        return 0
    else
        if [ "$is_warning" = "true" ]; then
            print_status $YELLOW "⚠ WARNING: $config_name may not be configured correctly"
            ((TESTS_WARNING++))
        else
            print_status $RED "✗ FAIL: $config_name is not configured correctly"
            ((TESTS_FAILED++))
        fi
        return 1
    fi
}

print_status $BLUE "==============================================================================="
print_status $BLUE "Azure Certificate Lifecycle Management - Deployment Validation"
print_status $BLUE "==============================================================================="

# Check if environment variables are loaded
if [ -f "./01-environment-setup.sh" ]; then
    print_status $YELLOW "Loading environment variables..."
    source ./01-environment-setup.sh
    print_status $GREEN "✓ Environment variables loaded"
else
    print_status $RED "ERROR: Environment setup script not found"
    print_status $YELLOW "Please ensure you're running this from the certificate-lifecycle-scripts directory"
    exit 1
fi

# Check if user is logged in to Azure
if ! az account show >/dev/null 2>&1; then
    print_status $RED "ERROR: You are not logged in to Azure CLI"
    print_status $YELLOW "Please run: az login"
    exit 1
fi

CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
print_status $GREEN "✓ Logged in to Azure subscription: $CURRENT_SUBSCRIPTION"

print_status $BLUE ""
print_status $BLUE "==============================================================================="
print_status $BLUE "RESOURCE VALIDATION"
print_status $BLUE "==============================================================================="

# =============================================================================
# CORE INFRASTRUCTURE VALIDATION
# =============================================================================

print_status $YELLOW "Validating core infrastructure..."

# Resource Group
validate_resource "Resource Group" "$RESOURCE_GROUP_NAME" \
    "az group show --name '$RESOURCE_GROUP_NAME'" \
    "Resource Group exists"

# Key Vault
validate_resource "Key Vault" "$KEY_VAULT_NAME" \
    "az keyvault show --name '$KEY_VAULT_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Key Vault exists and is accessible"

# Storage Account
validate_resource "Storage Account" "$STORAGE_ACCOUNT_NAME" \
    "az storage account show --name '$STORAGE_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Storage Account exists"

# Automation Account
validate_resource "Automation Account" "$AUTOMATION_ACCOUNT_NAME" \
    "az automation account show --name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Automation Account exists"

# Log Analytics Workspace
validate_resource "Log Analytics Workspace" "$LOG_ANALYTICS_WORKSPACE_NAME" \
    "az monitor log-analytics workspace show --workspace-name '$LOG_ANALYTICS_WORKSPACE_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Log Analytics Workspace exists"

print_status $BLUE ""
print_status $BLUE "==============================================================================="
print_status $BLUE "EVENT GRID VALIDATION"
print_status $BLUE "==============================================================================="

print_status $YELLOW "Validating Event Grid components..."

# Event Grid System Topic
validate_resource "Event Grid Topic" "$EVENT_GRID_TOPIC_NAME" \
    "az eventgrid system-topic show --name '$EVENT_GRID_TOPIC_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Event Grid System Topic exists"

# Data Collection Endpoint
validate_resource "Data Collection Endpoint" "$DATA_COLLECTION_ENDPOINT_NAME" \
    "az monitor data-collection endpoint show --name '$DATA_COLLECTION_ENDPOINT_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Data Collection Endpoint exists"

# Data Collection Rule
validate_resource "Data Collection Rule" "$DATA_COLLECTION_RULE_NAME" \
    "az monitor data-collection rule show --name '$DATA_COLLECTION_RULE_NAME' --resource-group '$RESOURCE_GROUP_NAME'" \
    "Data Collection Rule exists"

print_status $BLUE ""
print_status $BLUE "==============================================================================="
print_status $BLUE "AUTOMATION VALIDATION"
print_status $BLUE "==============================================================================="

print_status $YELLOW "Validating Automation Account components..."

# Check if managed identity is enabled
validate_config "Automation Managed Identity" \
    "[ \"\$(az automation account show --name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME' --query 'identity.principalId' -o tsv)\" != \"null\" ]" \
    "Automation Account has managed identity enabled"

# Runbooks
validate_resource "CertLifeCycleMgmt Runbook" "CertLifeCycleMgmt" \
    "az automation runbook show --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME' --name 'CertLifeCycleMgmt'" \
    "Certificate Lifecycle Management runbook exists"

validate_resource "Dashboard Data Injection Runbook" "CertLCDashboardDataInjestion" \
    "az automation runbook show --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME' --name 'CertLCDashboardDataInjestion'" \
    "Dashboard Data Injection runbook exists"

# Schedules
validate_resource "Monitoring Schedule" "CertLCMonitoringSchedule" \
    "az automation schedule show --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME' --name 'CertLCMonitoringSchedule'" \
    "Certificate monitoring schedule exists"

validate_resource "Dashboard Schedule" "CertLCDashboardSchedule" \
    "az automation schedule show --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP_NAME' --name 'CertLCDashboardSchedule'" \
    "Dashboard data injection schedule exists"

print_status $BLUE ""
print_status $BLUE "==============================================================================="
print_status $BLUE "CONNECTIVITY VALIDATION"
print_status $BLUE "==============================================================================="

print_status $YELLOW "Validating connectivity and permissions..."

# Storage Queue (non-critical test)
validate_config "Storage Queue Access" \
    "az storage queue exists --name '$QUEUE_NAME' --account-name '$STORAGE_ACCOUNT_NAME' --auth-mode login" \
    "Storage queue is accessible with current credentials" true

# Key Vault Access
validate_config "Key Vault Access" \
    "az keyvault list --resource-group '$RESOURCE_GROUP_NAME' --query \"[?name=='$KEY_VAULT_NAME']\" | grep -q '$KEY_VAULT_NAME'" \
    "Key Vault is accessible with current credentials"

print_status $BLUE ""
print_status $BLUE "==============================================================================="
print_status $BLUE "VALIDATION SUMMARY"
print_status $BLUE "==============================================================================="

QUEUE_SUBSCRIPTION=$(az eventgrid system-topic event-subscription show \
    --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "CertLC-queue" \
    --query "name" -o tsv 2>/dev/null || echo "")

if [ -n "$WEBHOOK_SUBSCRIPTION" ]; then
    echo "✅ Event Subscription: CertLC-webhook"
else
    echo "❌ Event Subscription: CertLC-webhook - NOT FOUND"
    ((VALIDATION_ERRORS++))
fi

if [ -n "$QUEUE_SUBSCRIPTION" ]; then
    echo "✅ Event Subscription: CertLC-queue"
else
    echo "❌ Event Subscription: CertLC-queue - NOT FOUND"
    ((VALIDATION_ERRORS++))
fi

# =============================================================================
# VALIDATE STORAGE QUEUE
# =============================================================================

echo ""
echo "📬 Checking storage queue..."

QUEUE_EXISTS=$(az storage queue exists \
    --name "$QUEUE_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login \
    --query "exists" -o tsv 2>/dev/null || echo "false")

if [ "$QUEUE_EXISTS" = "true" ]; then
    echo "✅ Storage Queue: $QUEUE_NAME"
else
    echo "❌ Storage Queue: $QUEUE_NAME - NOT FOUND"
    ((VALIDATION_ERRORS++))
fi

# =============================================================================
# VALIDATE RBAC PERMISSIONS
# =============================================================================

echo ""
echo "🔐 Checking RBAC permissions..."

# Get Automation Account principal ID
AUTOMATION_PRINCIPAL_ID=$(az automation account show \
    --name "$AUTOMATION_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "identity.principalId" -o tsv)

if [ -n "$AUTOMATION_PRINCIPAL_ID" ]; then
    echo "✅ Automation Account Managed Identity: $AUTOMATION_PRINCIPAL_ID"
    
    # Check Key Vault permissions
    KEY_VAULT_ID=$(az keyvault show \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "id" -o tsv)
    
    KV_ROLES=$(az role assignment list \
        --assignee "$AUTOMATION_PRINCIPAL_ID" \
        --scope "$KEY_VAULT_ID" \
        --query "[].roleDefinitionName" -o tsv)
    
    if echo "$KV_ROLES" | grep -q "Key Vault Certificates Officer"; then
        echo "✅ Key Vault Certificates Officer role assigned"
    else
        echo "❌ Key Vault Certificates Officer role - NOT ASSIGNED"
        ((VALIDATION_ERRORS++))
    fi
    
    if echo "$KV_ROLES" | grep -q "Key Vault Secrets User"; then
        echo "✅ Key Vault Secrets User role assigned"
    else
        echo "❌ Key Vault Secrets User role - NOT ASSIGNED"
        ((VALIDATION_ERRORS++))
    fi
    
else
    echo "❌ Automation Account Managed Identity - NOT FOUND"
    ((VALIDATION_ERRORS++))
fi

# =============================================================================
# VALIDATE LOG ANALYTICS TABLE
# =============================================================================

echo ""
echo "📊 Checking Log Analytics table..."

TABLE_EXISTS=$(az monitor log-analytics workspace table show \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "${TABLE_NAME}_CL" \
    --query "name" -o tsv 2>/dev/null || echo "")

if [ -n "$TABLE_EXISTS" ]; then
    echo "✅ Log Analytics Table: ${TABLE_NAME}_CL"
else
    echo "❌ Log Analytics Table: ${TABLE_NAME}_CL - NOT FOUND"
    ((VALIDATION_ERRORS++))
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "VALIDATION SUMMARY"
echo "==============================================================================="

if [ $VALIDATION_ERRORS -eq 0 ]; then
    echo "🎉 ALL VALIDATION CHECKS PASSED!"
    echo ""
    echo "Your Azure Certificate Management Services deployment is complete and ready to use."
    echo ""
    echo "🚀 NEXT STEPS:"
    echo "1. Add a test certificate to Key Vault: $KEY_VAULT_NAME"
    echo "2. Set certificate expiry notification (e.g., 30 days before expiry)"
    echo "3. Monitor the first data collection in Log Analytics"
    echo "4. Verify automation jobs run successfully"
    echo ""
    echo "📊 MONITORING RESOURCES:"
    echo "• Automation Account: https://portal.azure.com/#@/resource$(az automation account show --name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "id" -o tsv)"
    echo "• Key Vault: https://portal.azure.com/#@/resource$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "id" -o tsv)"
    echo "• Log Analytics: https://portal.azure.com/#@/resource$(az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "id" -o tsv)"
    exit 0
else
    echo "❌ VALIDATION FAILED!"
    echo ""
    echo "Found $VALIDATION_ERRORS error(s) in the deployment."
    echo ""
    echo "🔧 TROUBLESHOOTING STEPS:"
    echo "1. Check the Azure portal for resource status"
    echo "2. Review deployment logs for any errors"
    echo "3. Verify Azure CLI permissions"
    echo "4. Re-run individual deployment scripts if needed"
    echo ""
    echo "🆘 COMMON SOLUTIONS:"
    echo "• Resource not found: Re-run the corresponding deployment script"
    echo "• Permission errors: Check Azure subscription roles"
    echo "• Timeout issues: Wait a few minutes and re-validate"
    echo ""
    echo "📞 SUPPORT:"
    echo "• Check deployment logs in Azure portal"
    echo "• Review script output for specific error messages"
    echo "• Ensure all prerequisite steps were completed"
    exit 1
fi