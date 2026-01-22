#!/bin/bash

# Key Vault Deployment Diagnostics and Recovery Script
# This script helps diagnose Key Vault deployment issues and deploy missing resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${GREEN}Key Vault Deployment Diagnostics${NC}"
echo "=================================="

# Show current configuration
show_config_summary

# Function to check if resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local resource_group=$3
    
    if az resource show --resource-type "$resource_type" --name "$resource_name" --resource-group "$resource_group" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $resource_name ($resource_type)"
        return 0
    else
        echo -e "${RED}✗${NC} $resource_name ($resource_type) - MISSING"
        return 1
    fi
}

echo -e "${YELLOW}Step 1: Checking existing resources...${NC}"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}ERROR: Resource group '$RESOURCE_GROUP' does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Resource group exists: $RESOURCE_GROUP"
echo ""

# Check individual resources
echo "Checking core resources:"
KV_EXISTS=0
EG_EXISTS=0
SA_EXISTS=0
AA_EXISTS=0

check_resource "Microsoft.KeyVault/vaults" "$KEY_VAULT_NAME" "$RESOURCE_GROUP" && KV_EXISTS=1 || true
check_resource "Microsoft.EventGrid/systemTopics" "$EVENT_GRID_NAME" "$RESOURCE_GROUP" && EG_EXISTS=1 || true
check_resource "Microsoft.Storage/storageAccounts" "$STORAGE_ACCOUNT_NAME" "$RESOURCE_GROUP" && SA_EXISTS=1 || true
check_resource "Microsoft.Automation/automationAccounts" "$AUTOMATION_ACCOUNT_NAME" "$RESOURCE_GROUP" && AA_EXISTS=1 || true

echo ""

# Check for common Key Vault issues
echo -e "${YELLOW}Step 2: Diagnosing Key Vault issues...${NC}"

if [ $KV_EXISTS -eq 0 ]; then
    echo "Key Vault is missing. Checking potential causes:"
    
    # Check if name is available
    echo "Checking Key Vault name availability..."
    NAME_AVAILABLE=$(az keyvault check-name --name "$KEY_VAULT_NAME" --query nameAvailable -o tsv 2>/dev/null || echo "false")
    
    if [ "$NAME_AVAILABLE" = "true" ]; then
        echo -e "${GREEN}✓${NC} Key Vault name '$KEY_VAULT_NAME' is available"
    else
        echo -e "${RED}✗${NC} Key Vault name '$KEY_VAULT_NAME' is not available"
        REASON=$(az keyvault check-name --name "$KEY_VAULT_NAME" --query reason -o tsv 2>/dev/null || echo "Unknown")
        echo "Reason: $REASON"
        
        if [ "$REASON" = "AlreadyExists" ]; then
            echo "The Key Vault might exist in a different subscription or be soft-deleted"
            echo "Checking for soft-deleted Key Vaults..."
            
            SOFT_DELETED=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME'].name" -o tsv 2>/dev/null || echo "")
            if [ -n "$SOFT_DELETED" ]; then
                echo -e "${YELLOW}Found soft-deleted Key Vault: $KEY_VAULT_NAME${NC}"
                echo "You need to either:"
                echo "1. Purge it: az keyvault purge --name $KEY_VAULT_NAME"
                echo "2. Recover it: az keyvault recover --name $KEY_VAULT_NAME"
                echo "3. Use a different name"
            fi
        fi
    fi
    
    # Check subscription limits
    echo "Checking Key Vault quota..."
    KV_COUNT=$(az keyvault list --query "length([?location=='$LOCATION'])" -o tsv 2>/dev/null || echo "0")
    echo "Current Key Vaults in $LOCATION: $KV_COUNT"
    
    # Check permissions
    echo "Checking permissions..."
    USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
    if [ -n "$USER_ID" ]; then
        echo "Current user ID: $USER_ID"
        # Check if user has Contributor or Owner role
        ROLE_ASSIGNMENT=$(az role assignment list --assignee "$USER_ID" --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP" --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='Contributor'].roleDefinitionName" -o tsv 2>/dev/null || echo "")
        if [ -n "$ROLE_ASSIGNMENT" ]; then
            echo -e "${GREEN}✓${NC} User has required permissions: $ROLE_ASSIGNMENT"
        else
            echo -e "${YELLOW}!${NC} User might not have sufficient permissions in resource group"
        fi
    fi
fi

echo ""
echo -e "${YELLOW}Step 3: Deployment options...${NC}"

if [ $KV_EXISTS -eq 0 ]; then
    echo -e "${BLUE}Option 1: Deploy Key Vault only${NC}"
    echo "Run: ./deploy-keyvault-only.sh"
    echo ""
fi

if [ $KV_EXISTS -eq 0 ] || [ $EG_EXISTS -eq 0 ] || [ $SA_EXISTS -eq 0 ] || [ $AA_EXISTS -eq 0 ]; then
    echo -e "${BLUE}Option 2: Deploy missing core resources${NC}"
    echo "Run: ./deploy-missing-resources.sh"
    echo ""
fi

echo -e "${BLUE}Option 3: Check deployment logs${NC}"
echo "Run: az deployment group list --resource-group $RESOURCE_GROUP --query '[].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}' -o table"
echo ""

echo -e "${BLUE}Option 4: View detailed deployment errors${NC}"
echo "Run: az deployment operation list --resource-group $RESOURCE_GROUP --name <deployment-name> --query '[?properties.provisioningState==\`Failed\`].{Resource:properties.targetResource.resourceName, Error:properties.statusMessage.error.message}' -o table"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the diagnostics above"
echo "2. Choose an appropriate deployment option"
echo "3. If Key Vault name is taken, try a different UNIQUE_STRING"