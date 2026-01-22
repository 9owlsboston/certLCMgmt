#!/bin/bash

# Deploy Missing Resources Script
# This script checks what resources exist and deploys only the missing ones

set -e

# Configuration - Update these values
RESOURCE_GROUP=""     # UPDATE THIS
UNIQUE_STRING=""      # UPDATE THIS
LOCATION="eastus"     # UPDATE THIS
DOMAIN_ADMIN_PASSWORD=""  # UPDATE THIS
CA_ADMIN_PASSWORD=""      # UPDATE THIS
RECIPIENT_EMAIL=""        # UPDATE THIS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploy Missing Resources${NC}"
echo "======================="

# Validate configuration
if [ -z "$RESOURCE_GROUP" ] || [ -z "$UNIQUE_STRING" ]; then
    echo -e "${RED}ERROR: Please update the configuration variables in this script${NC}"
    echo "Required variables:"
    echo "- RESOURCE_GROUP"
    echo "- UNIQUE_STRING"
    echo "- DOMAIN_ADMIN_PASSWORD (if deploying VMs)"
    echo "- CA_ADMIN_PASSWORD (if deploying VMs)"
    echo "- RECIPIENT_EMAIL"
    exit 1
fi

# Derived variables
KEY_VAULT_NAME="DEMO-KV-${UNIQUE_STRING}"
EVENT_GRID_NAME="DEMO-EG-${UNIQUE_STRING}"
STORAGE_ACCOUNT_NAME="demosa${UNIQUE_STRING}"
AUTOMATION_ACCOUNT_NAME="DEMO-AA-${UNIQUE_STRING}"
WORKSPACE_NAME="DEMO-LA-${UNIQUE_STRING}"
DEPLOYMENT_NAME="missing-resources-$(date +%Y%m%d-%H%M%S)"

echo "Configuration:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Unique String: $UNIQUE_STRING"
echo ""

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local resource_group=$3
    
    az resource show --resource-type "$resource_type" --name "$resource_name" --resource-group "$resource_group" &>/dev/null
}

# Check existing resources
echo -e "${YELLOW}Checking existing resources...${NC}"

KV_EXISTS=$(resource_exists "Microsoft.KeyVault/vaults" "$KEY_VAULT_NAME" "$RESOURCE_GROUP" && echo "true" || echo "false")
EG_EXISTS=$(resource_exists "Microsoft.EventGrid/systemTopics" "$EVENT_GRID_NAME" "$RESOURCE_GROUP" && echo "true" || echo "false")
SA_EXISTS=$(resource_exists "Microsoft.Storage/storageAccounts" "$STORAGE_ACCOUNT_NAME" "$RESOURCE_GROUP" && echo "true" || echo "false")
AA_EXISTS=$(resource_exists "Microsoft.Automation/automationAccounts" "$AUTOMATION_ACCOUNT_NAME" "$RESOURCE_GROUP" && echo "true" || echo "false")
LA_EXISTS=$(resource_exists "Microsoft.OperationalInsights/workspaces" "$WORKSPACE_NAME" "$RESOURCE_GROUP" && echo "true" || echo "false")

echo "Key Vault: $([ "$KV_EXISTS" = "true" ] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}")"
echo "Event Grid: $([ "$EG_EXISTS" = "true" ] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}")"
echo "Storage Account: $([ "$SA_EXISTS" = "true" ] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}")"
echo "Automation Account: $([ "$AA_EXISTS" = "true" ] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}")"
echo "Log Analytics: $([ "$LA_EXISTS" = "true" ] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}")"
echo ""

# Count missing resources
MISSING_COUNT=0
[ "$KV_EXISTS" = "false" ] && ((MISSING_COUNT++))
[ "$EG_EXISTS" = "false" ] && ((MISSING_COUNT++))
[ "$SA_EXISTS" = "false" ] && ((MISSING_COUNT++))
[ "$AA_EXISTS" = "false" ] && ((MISSING_COUNT++))
[ "$LA_EXISTS" = "false" ] && ((MISSING_COUNT++))

if [ $MISSING_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All core resources exist!${NC}"
    echo "You may want to check if all configurations and dependencies are properly set up."
    exit 0
fi

echo -e "${YELLOW}Found $MISSING_COUNT missing resource(s)${NC}"
echo ""

# Deployment strategies
echo -e "${BLUE}Deployment Options:${NC}"
echo "1. Deploy only missing core resources (Key Vault, Storage, Automation, Log Analytics)"
echo "2. Re-run full deployment (may fail on existing resources)"
echo "3. Deploy individual resources one by one"
echo ""

read -p "Choose option (1-3): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo -e "${YELLOW}Option 1: Deploying missing core resources...${NC}"
        
        # Create minimal template with only missing resources
        cat > missing-resources-template.json << 'EOF'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "KeyvaultName": {"type": "string"},
        "StorageAccountName": {"type": "string"},
        "AutomationAccountName": {"type": "string"},
        "workspaceName": {"type": "string"},
        "location": {"type": "string", "defaultValue": "[resourceGroup().location]"},
        "deployKeyVault": {"type": "bool", "defaultValue": true},
        "deployStorage": {"type": "bool", "defaultValue": true},
        "deployAutomation": {"type": "bool", "defaultValue": true},
        "deployLogAnalytics": {"type": "bool", "defaultValue": true}
    },
    "resources": [
        {
            "condition": "[parameters('deployKeyVault')]",
            "type": "Microsoft.KeyVault/vaults",
            "apiVersion": "2023-02-01",
            "name": "[parameters('KeyvaultName')]",
            "location": "[parameters('location')]",
            "properties": {
                "sku": {"family": "A", "name": "Standard"},
                "tenantId": "[subscription().tenantId]",
                "accessPolicies": [],
                "enabledForDeployment": false,
                "enabledForDiskEncryption": true,
                "enabledForTemplateDeployment": false,
                "enableSoftDelete": true,
                "softDeleteRetentionInDays": 90,
                "enableRbacAuthorization": true,
                "publicNetworkAccess": "Enabled"
            }
        },
        {
            "condition": "[parameters('deployStorage')]",
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2023-01-01",
            "name": "[parameters('StorageAccountName')]",
            "location": "[parameters('location')]",
            "sku": {"name": "Standard_LRS"},
            "kind": "StorageV2",
            "properties": {
                "accessTier": "Hot",
                "allowBlobPublicAccess": false,
                "minimumTlsVersion": "TLS1_2"
            }
        },
        {
            "condition": "[parameters('deployAutomation')]",
            "type": "Microsoft.Automation/automationAccounts",
            "apiVersion": "2022-08-08",
            "name": "[parameters('AutomationAccountName')]",
            "location": "[parameters('location')]",
            "identity": {"type": "SystemAssigned"},
            "properties": {
                "publicNetworkAccess": true,
                "disableLocalAuth": false,
                "sku": {"name": "Basic"}
            }
        },
        {
            "condition": "[parameters('deployLogAnalytics')]",
            "type": "Microsoft.OperationalInsights/workspaces",
            "apiVersion": "2022-10-01",
            "name": "[parameters('workspaceName')]",
            "location": "[parameters('location')]",
            "properties": {
                "sku": {"name": "PerGB2018"},
                "retentionInDays": 120,
                "features": {
                    "enableLogAccessUsingOnlyResourcePermissions": true
                }
            }
        }
    ]
}
EOF

        # Deploy with conditions
        echo "Deploying missing resources..."
        az deployment group create \
            --name "$DEPLOYMENT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --template-file "missing-resources-template.json" \
            --parameters \
                KeyvaultName="$KEY_VAULT_NAME" \
                StorageAccountName="$STORAGE_ACCOUNT_NAME" \
                AutomationAccountName="$AUTOMATION_ACCOUNT_NAME" \
                workspaceName="$WORKSPACE_NAME" \
                location="$LOCATION" \
                deployKeyVault="$([ "$KV_EXISTS" = "false" ] && echo "true" || echo "false")" \
                deployStorage="$([ "$SA_EXISTS" = "false" ] && echo "true" || echo "false")" \
                deployAutomation="$([ "$AA_EXISTS" = "false" ] && echo "true" || echo "false")" \
                deployLogAnalytics="$([ "$LA_EXISTS" = "false" ] && echo "true" || echo "false")" \
            --output table
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Missing resources deployed successfully!${NC}"
        else
            echo -e "${RED}✗ Deployment failed${NC}"
        fi
        ;;
        
    2)
        echo -e "${YELLOW}Option 2: Re-running full deployment...${NC}"
        echo "This may show warnings for existing resources but should complete successfully."
        echo ""
        
        if [ -z "$DOMAIN_ADMIN_PASSWORD" ] || [ -z "$CA_ADMIN_PASSWORD" ]; then
            echo -e "${RED}ERROR: Domain and CA admin passwords are required for full deployment${NC}"
            echo "Please set these variables in the script"
            exit 1
        fi
        
        az deployment group create \
            --name "$DEPLOYMENT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            # NOTE: Update path to point to cloned Microsoft repository
            # git clone https://github.com/Azure-Samples/certificate-lifecycle-management.git
            --template-file "./certificate-lifecycle-management/.armtemplate/fulllabdeploy.json" \
            --parameters \
                DomainAdminPassword="$DOMAIN_ADMIN_PASSWORD" \
                CaAdminPassword="$CA_ADMIN_PASSWORD" \
                UNIQUESTRING="$UNIQUE_STRING" \
                Recipient="$RECIPIENT_EMAIL" \
            --output table
        ;;
        
    3)
        echo -e "${YELLOW}Option 3: Individual resource deployment${NC}"
        echo "Use the following commands to deploy individual resources:"
        echo ""
        
        [ "$KV_EXISTS" = "false" ] && echo "Key Vault: ./deploy-keyvault-only.sh"
        [ "$SA_EXISTS" = "false" ] && echo "Storage Account: az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS"
        [ "$AA_EXISTS" = "false" ] && echo "Automation Account: az automation account create --name $AUTOMATION_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION"
        [ "$LA_EXISTS" = "false" ] && echo "Log Analytics: az monitor log-analytics workspace create --workspace-name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP --location $LOCATION"
        ;;
        
    *)
        echo "Invalid option selected."
        exit 1
        ;;
esac