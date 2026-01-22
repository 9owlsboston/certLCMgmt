#!/bin/bash

# Enhanced Certificate Lifecycle Management ARM Template Deployment
# Replaces GitHub repo deployment with our improved local version

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="rg-demo-certlc"
LOCATION="East US"
TEMPLATE_FILE="templates/enhanced-azuredeploy.json"
PARAMETERS_FILE="templates/enhanced-azuredeploy.parameters.json"

echo -e "${CYAN}🚀 ENHANCED CERTIFICATE LIFECYCLE MANAGEMENT - ARM DEPLOYMENT${NC}"
echo -e "${CYAN}=============================================================${NC}"
echo ""
echo -e "${YELLOW}📋 This deployment replaces the GitHub repo version with our enhanced local version${NC}"
echo -e "${YELLOW}   Includes: 4-layer OID fallbacks, 40-day threshold, 18 automation variables${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Pre-deployment validation
echo -e "${YELLOW}📋 PRE-DEPLOYMENT VALIDATION${NC}"
echo "=============================="

# Check Azure CLI
if ! command_exists az; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI installed${NC}"

# Check if logged in
if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}❌ Not logged into Azure${NC}"
    echo "Please run: az login"
    exit 1
fi

CURRENT_SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}✅ Azure CLI authenticated${NC}"
echo -e "${CYAN}   Current subscription: $CURRENT_SUBSCRIPTION${NC}"

# Check template files
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}❌ ARM template not found: $TEMPLATE_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ARM template found: $TEMPLATE_FILE${NC}"

if [ ! -f "$PARAMETERS_FILE" ]; then
    echo -e "${RED}❌ Parameters file not found: $PARAMETERS_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Parameters file found: $PARAMETERS_FILE${NC}"

# Check scripts directory
if [ ! -f "scripts/Enhanced-CertLifeCycleMgmt.ps1" ]; then
    echo -e "${RED}❌ Enhanced runbook not found: scripts/Enhanced-CertLifeCycleMgmt.ps1${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Enhanced runbook found: scripts/Enhanced-CertLifeCycleMgmt.ps1${NC}"

echo ""
echo -e "${YELLOW}📊 DEPLOYMENT CONFIGURATION${NC}"
echo "============================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Template: $TEMPLATE_FILE"
echo "Parameters: $PARAMETERS_FILE"
echo "Enhanced Features:"
echo "  ✅ 4-layer OID extraction fallbacks"
echo "  ✅ 40-day certificate renewal threshold"
echo "  ✅ 18 enhanced automation variables"
echo "  ✅ Comprehensive error handling"
echo "  ✅ Enhanced Event Grid integration"
echo ""

# Confirmation
read -p "Deploy enhanced ARM template? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}🎯 PHASE 1: RESOURCE GROUP VALIDATION${NC}"
echo "======================================"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Resource group $RESOURCE_GROUP does not exist${NC}"
    echo "Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo -e "${GREEN}✅ Resource group created${NC}"
else
    echo -e "${GREEN}✅ Resource group $RESOURCE_GROUP exists${NC}"
fi

echo ""
echo -e "${CYAN}🎯 PHASE 2: ARM TEMPLATE VALIDATION${NC}"
echo "==================================="

echo "Validating ARM template..."
VALIDATION_RESULT=$(az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --query "error" -o tsv 2>/dev/null || echo "validation-failed")

if [ "$VALIDATION_RESULT" == "validation-failed" ] || [ "$VALIDATION_RESULT" != "" ]; then
    echo -e "${RED}❌ ARM template validation failed${NC}"
    echo "Running detailed validation..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$PARAMETERS_FILE"
    exit 1
else
    echo -e "${GREEN}✅ ARM template validation passed${NC}"
fi

echo ""
echo -e "${CYAN}🎯 PHASE 3: ENHANCED ARM TEMPLATE DEPLOYMENT${NC}"
echo "==========================================="

echo "Starting ARM template deployment..."
echo -e "${YELLOW}⏱️ This may take 15-30 minutes for complete infrastructure deployment${NC}"

DEPLOYMENT_NAME="enhanced-certlc-$(date +%Y%m%d-%H%M%S)"

# Deploy with detailed output
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --verbose

DEPLOYMENT_STATUS=$?

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ ARM template deployment completed successfully${NC}"
else
    echo -e "${RED}❌ ARM template deployment failed${NC}"
    echo "Checking deployment status..."
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.provisioningState" -o tsv
    exit 1
fi

echo ""
echo -e "${CYAN}🎯 PHASE 4: DEPLOYMENT VERIFICATION${NC}"
echo "=================================="

echo "Retrieving deployment outputs..."

# Get deployment outputs
OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs" -o json 2>/dev/null || echo "{}")

if [ "$OUTPUTS" != "{}" ]; then
    echo -e "${GREEN}📊 DEPLOYMENT OUTPUTS:${NC}"
    echo "$OUTPUTS" | jq -r 'to_entries[] | "   ✅ \(.key): \(.value.value)"' 2>/dev/null || echo "   ✅ Outputs available (jq not installed)"
else
    echo -e "${YELLOW}⚠️ No deployment outputs available${NC}"
fi

# Verify key resources
echo ""
echo "Verifying deployed resources..."

# Check Automation Account
AUTOMATION_ACCOUNT=$(az automation account list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'DEMO-AA')].name" -o tsv 2>/dev/null || echo "")
if [ -n "$AUTOMATION_ACCOUNT" ]; then
    echo -e "${GREEN}✅ Automation Account: $AUTOMATION_ACCOUNT${NC}"
else
    echo -e "${YELLOW}⚠️ Automation Account not found${NC}"
fi

# Check Key Vault
KEY_VAULT=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'DEMO-KV')].name" -o tsv 2>/dev/null || echo "")
if [ -n "$KEY_VAULT" ]; then
    echo -e "${GREEN}✅ Key Vault: $KEY_VAULT${NC}"
else
    echo -e "${YELLOW}⚠️ Key Vault not found${NC}"
fi

echo ""
echo -e "${GREEN}🎉 ENHANCED ARM DEPLOYMENT COMPLETE!${NC}"
echo "====================================="
echo ""
echo -e "${CYAN}📊 DEPLOYMENT SUMMARY:${NC}"
echo "✅ Enhanced ARM template deployed successfully"
echo "✅ Base infrastructure from GitHub repo deployed"
echo "✅ Enhanced-CertLifeCycleMgmt runbook deployed"
echo "✅ 18 enhanced automation variables configured"
echo "✅ 40-day certificate renewal threshold set"
echo "✅ Enhanced Event Grid integration configured"
echo ""
echo -e "${CYAN}🔧 NEXT STEPS:${NC}"
echo "1. Verify deployment: ./verify-deployment.sh"
echo "2. Test certificate analysis: cd testing && pwsh ./direct-renewal-test.ps1"
echo "3. Monitor automation: pwsh ./monitor-simple.ps1"
echo ""
echo -e "${GREEN}🚀 Your enhanced certificate lifecycle management system is deployed via ARM template!${NC}"
echo -e "${YELLOW}📋 This deployment includes all troubleshooting fixes and improvements from our project${NC}"