#!/bin/bash

# Deploy Key Vault Only Script
# This script deploys only the Key Vault resource

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load configuration from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${GREEN}Key Vault Only Deployment${NC}"
echo "========================="

# Show current configuration
show_config_summary

# Derived variables
KEY_VAULT_NAME="DEMO-KV-${UNIQUE_STRING}"
DEPLOYMENT_NAME="keyvault-deployment-$(date +%Y%m%d-%H%M%S)"
TEMPLATE_FILE="./keyvault-only-template.json"

echo "Resource Group: $RESOURCE_GROUP"
echo "Key Vault Name: $KEY_VAULT_NAME"
echo "Location: $LOCATION"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}ERROR: Template file not found: $TEMPLATE_FILE${NC}"
    exit 1
fi

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}ERROR: Resource group '$RESOURCE_GROUP' does not exist${NC}"
    exit 1
fi

# Check if Key Vault already exists
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${GREEN}✓ Key Vault '$KEY_VAULT_NAME' already exists${NC}"
    exit 0
fi

# Check name availability
echo -e "${YELLOW}Checking Key Vault name availability...${NC}"
NAME_AVAILABLE=$(az keyvault check-name --name "$KEY_VAULT_NAME" --query nameAvailable -o tsv 2>/dev/null || echo "false")

if [ "$NAME_AVAILABLE" != "true" ]; then
    echo -e "${RED}ERROR: Key Vault name '$KEY_VAULT_NAME' is not available${NC}"
    
    # Check for soft-deleted vault
    SOFT_DELETED=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME'].name" -o tsv 2>/dev/null || echo "")
    if [ -n "$SOFT_DELETED" ]; then
        echo -e "${YELLOW}Found soft-deleted Key Vault with the same name.${NC}"
        read -p "Do you want to recover it? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Recovering soft-deleted Key Vault..."
            az keyvault recover --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP"
            echo -e "${GREEN}✓ Key Vault recovered successfully${NC}"
            exit 0
        else
            echo "Please either:"
            echo "1. Purge the soft-deleted vault: az keyvault purge --name $KEY_VAULT_NAME"
            echo "2. Use a different UNIQUE_STRING"
            exit 1
        fi
    else
        echo "Please use a different UNIQUE_STRING"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Key Vault name is available${NC}"

# Ask for confirmation
echo ""
read -p "Deploy Key Vault '$KEY_VAULT_NAME'? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo -e "${YELLOW}Step 1: Validating template...${NC}"
az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        KeyvaultName="$KEY_VAULT_NAME" \
        location="$LOCATION" \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Template validation successful${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 2: Deploying Key Vault...${NC}"
az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        KeyvaultName="$KEY_VAULT_NAME" \
        location="$LOCATION" \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Key Vault deployed successfully!${NC}"
    echo ""
    echo "Key Vault details:"
    az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query "{Name:name, Location:location, ResourceGroup:resourceGroup, VaultUri:properties.vaultUri}" -o table
    
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run the full deployment again to create missing resources"
    echo "2. Or run ./deploy-missing-resources.sh to deploy remaining components"
else
    echo -e "${RED}✗ Key Vault deployment failed${NC}"
    echo "Check the deployment logs for details:"
    echo "az deployment operation list --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query '[?properties.provisioningState==\`Failed\`]' -o table"
    exit 1
fi