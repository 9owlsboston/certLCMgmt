#!/bin/bash

# Quick deployment status checker
# Run this to see what happened with your failed deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deployment Status Checker${NC}"
echo "========================"

# Try to load configuration first, but allow manual input if not available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    echo -e "${GREEN}Loading configuration from .env file...${NC}"
    # shellcheck source=../common.sh
    VALIDATE_CONFIG=false source "$SCRIPT_DIR/../common.sh"
    echo "Using Resource Group: $RESOURCE_GROUP"
    echo ""
else
    echo -e "${YELLOW}No .env configuration found. Using manual input.${NC}"
    echo "Run '../config.sh init' to set up centralized configuration."
    echo ""
    
    # Get all resource groups
    echo -e "${YELLOW}Available Resource Groups:${NC}"
    az group list --query "[].{Name:name, Location:location}" -o table
    echo ""

    read -p "Enter your resource group name: " RESOURCE_GROUP

    if [ -z "$RESOURCE_GROUP" ]; then
        echo "No resource group specified. Exiting."
        exit 1
    fi
fi

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}ERROR: Resource group '$RESOURCE_GROUP' does not exist${NC}"
    exit 1
fi

echo -e "${BLUE}Checking deployments for resource group: $RESOURCE_GROUP${NC}"
echo ""

# List recent deployments
echo -e "${YELLOW}Recent Deployments:${NC}"
az deployment group list --resource-group "$RESOURCE_GROUP" \
    --query '[].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}' \
    -o table | head -10

echo ""

# Get failed deployments
echo -e "${YELLOW}Failed Deployments:${NC}"
FAILED_DEPLOYMENTS=$(az deployment group list --resource-group "$RESOURCE_GROUP" \
    --query "[?properties.provisioningState=='Failed'].name" -o tsv)

if [ -z "$FAILED_DEPLOYMENTS" ]; then
    echo "No failed deployments found."
else
    for deployment in $FAILED_DEPLOYMENTS; do
        echo -e "${RED}Failed Deployment: $deployment${NC}"
        echo "Detailed errors:"
        az deployment operation list --resource-group "$RESOURCE_GROUP" --name "$deployment" \
            --query "[?properties.provisioningState=='Failed'].{Resource:properties.targetResource.resourceName, ResourceType:properties.targetResource.resourceType, Error:properties.statusMessage.error.message}" \
            -o table
        echo ""
    done
fi

# Check existing resources
echo -e "${YELLOW}Existing Resources in Resource Group:${NC}"
az resource list --resource-group "$RESOURCE_GROUP" \
    --query "[].{Name:name, Type:type, Location:location}" -o table

echo ""
echo -e "${BLUE}Quick Actions:${NC}"
echo "1. To diagnose Key Vault issues: ./diagnose-keyvault.sh"
echo "2. To deploy only Key Vault: ./deploy-keyvault-only.sh"  
echo "3. To deploy missing resources: ./deploy-missing-resources.sh"
echo "4. To view detailed logs: az deployment operation list --resource-group $RESOURCE_GROUP --name <deployment-name>"