#!/bin/bash

# Certificate Lifecycle Management - Deployment Script
# This script deploys the full lab environment for Certificate Lifecycle Management

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load configuration from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

echo -e "${GREEN}Certificate Lifecycle Management Deployment Script${NC}"
echo "================================================="

# Show current configuration
show_config_summary

# Check if passwords are set (required for lab deployment)
if [ -z "$DOMAIN_ADMIN_PASSWORD" ] || [ -z "$CA_ADMIN_PASSWORD" ]; then
    echo -e "${RED}ERROR: Please set DOMAIN_ADMIN_PASSWORD and CA_ADMIN_PASSWORD in .env file${NC}"
    echo "Password requirements:"
    echo "- At least 12 characters"
    echo "- Mix of uppercase, lowercase, numbers, and special characters"
    echo "- No dictionary words"
    echo ""
    echo "Update your .env file and run this script again."
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}ERROR: Template file not found: $TEMPLATE_FILE${NC}"
    echo "Please ensure you're running this script from the correct directory"
    echo "and that you have cloned the Microsoft repository:"
    echo "git clone https://github.com/Azure-Samples/certificate-lifecycle-management.git"
    exit 1
fi

# Check if Azure CLI is installed and user is logged in
if ! command -v az &> /dev/null; then
    echo -e "${RED}ERROR: Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}You are not logged in to Azure. Please log in:${NC}"
    az login
fi

echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Unique String: $UNIQUE_STRING"
echo "Recipient Email: $RECIPIENT_EMAIL"
echo "Template: $TEMPLATE_FILE"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo -e "${YELLOW}Step 1: Creating resource group (if it doesn't exist)...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

echo -e "${YELLOW}Step 2: Validating deployment template...${NC}"
az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        DomainAdminPassword="$DOMAIN_ADMIN_PASSWORD" \
        CaAdminPassword="$CA_ADMIN_PASSWORD" \
        UNIQUESTRING="$UNIQUE_STRING" \
        Recipient="$RECIPIENT_EMAIL" \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Template validation successful${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Running what-if analysis...${NC}"
az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        DomainAdminPassword="$DOMAIN_ADMIN_PASSWORD" \
        CaAdminPassword="$CA_ADMIN_PASSWORD" \
        UNIQUESTRING="$UNIQUE_STRING" \
        Recipient="$RECIPIENT_EMAIL"

echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo -e "${YELLOW}Step 4: Starting deployment (this will take ~30 minutes)...${NC}"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "Start Time: $(date)"

az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        DomainAdminPassword="$DOMAIN_ADMIN_PASSWORD" \
        CaAdminPassword="$CA_ADMIN_PASSWORD" \
        UNIQUESTRING="$UNIQUE_STRING" \
        Recipient="$RECIPIENT_EMAIL" \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
    echo "End Time: $(date)"
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Check the Azure Portal for all created resources"
    echo "2. Verify VMs are running and domain services are configured"
    echo "3. Test certificate renewal workflow"
    echo "4. Review the Azure Workbook dashboard"
    echo ""
    echo -e "${YELLOW}Resource Group URL:${NC}"
    echo "https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "Please check the deployment logs in Azure Portal for details"
    exit 1
fi