#!/bin/bash

# Certificate Lifecycle Management Configuration Manager
# This script helps create and populate the .env configuration file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/.env.template"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${GREEN}Certificate Lifecycle Management Configuration Manager${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  init                 Create .env file from template"
    echo "  auto-populate        Auto-populate .env from deployed resources"
    echo "  validate            Validate current .env configuration"
    echo "  show                Show current configuration"
    echo "  reset               Reset .env file to template"
    echo ""
    echo "Options:"
    echo "  --resource-group RG  Specify resource group for auto-populate"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 auto-populate --resource-group rg-certlc-lab"
    echo "  $0 validate"
}

init_config() {
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Warning: .env file already exists${NC}"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    echo -e "${GREEN}Created .env file from template${NC}"
    echo "Please edit $ENV_FILE with your configuration values"
    echo "Or run: $0 auto-populate --resource-group <your-rg-name>"
}

auto_populate() {
    local resource_group="$1"
    
    if [ -z "$resource_group" ]; then
        echo -e "${RED}Error: Resource group is required for auto-populate${NC}"
        echo "Usage: $0 auto-populate --resource-group <resource-group-name>"
        exit 1
    fi
    
    echo -e "${BLUE}Auto-populating configuration from resource group: $resource_group${NC}"
    
    # Check if resource group exists
    if ! az group show --name "$resource_group" &>/dev/null; then
        echo -e "${RED}Error: Resource group '$resource_group' not found${NC}"
        exit 1
    fi
    
    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Get resource group location
    LOCATION=$(az group show --name "$resource_group" --query location -o tsv)
    
    # Try to detect the unique string from existing resources
    echo "Detecting unique string from deployed resources..."
    
    # Look for Key Vault with pattern and extract unique string
    KEY_VAULTS=$(az keyvault list --resource-group "$resource_group" --query "[].name" -o tsv)
    UNIQUE_STRING=""
    
    for kv in $KEY_VAULTS; do
        if [[ $kv =~ ^DEMO-KV-(.+)$ ]]; then
            UNIQUE_STRING="${BASH_REMATCH[1]}"
            break
        elif [[ $kv =~ ^kv-certlc-(.+)$ ]]; then
            UNIQUE_STRING="${BASH_REMATCH[1]}"
            break
        fi
    done
    
    # If no unique string found from Key Vault, try storage account
    if [ -z "$UNIQUE_STRING" ]; then
        STORAGE_ACCOUNTS=$(az storage account list --resource-group "$resource_group" --query "[].name" -o tsv)
        for sa in $STORAGE_ACCOUNTS; do
            if [[ $sa =~ ^demosa(.+)$ ]]; then
                UNIQUE_STRING="${BASH_REMATCH[1]}"
                break
            elif [[ $sa =~ ^sacertlc(.+)$ ]]; then
                UNIQUE_STRING="${BASH_REMATCH[1]}"
                break
            fi
        done
    fi
    
    if [ -z "$UNIQUE_STRING" ]; then
        echo -e "${YELLOW}Warning: Could not auto-detect unique string from resources${NC}"
        echo "Please manually set UNIQUE_STRING in the .env file"
        UNIQUE_STRING="<auto-detect-failed>"
    else
        echo -e "${GREEN}Detected unique string: $UNIQUE_STRING${NC}"
    fi
    
    # Get actual resource names
    KEY_VAULT_NAME=$(az keyvault list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    STORAGE_ACCOUNT_NAME=$(az storage account list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    AUTOMATION_ACCOUNT_NAME=$(az automation account list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    FUNCTION_APP_NAME=$(az functionapp list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    LOG_ANALYTICS_NAME=$(az monitor log-analytics workspace list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    # Get tenant ID
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    # Create or update .env file
    cat > "$ENV_FILE" << EOF
# Certificate Lifecycle Management Configuration
# Auto-generated on $(date)
# Resource Group: $resource_group

# Core deployment settings
RESOURCE_GROUP="$resource_group"
SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
LOCATION="$LOCATION"
UNIQUE_STRING="$UNIQUE_STRING"

# Email settings (update manually)
RECIPIENT_EMAIL=""

# Password settings (for lab deployments - update manually)
DOMAIN_ADMIN_PASSWORD=""
CA_ADMIN_PASSWORD=""

# Detected resource names
KEY_VAULT_NAME="$KEY_VAULT_NAME"
EVENT_GRID_NAME="DEMO-EG-$UNIQUE_STRING"
STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME"
AUTOMATION_ACCOUNT_NAME="$AUTOMATION_ACCOUNT_NAME"
FUNCTION_APP_NAME="$FUNCTION_APP_NAME"
APP_SERVICE_PLAN_NAME="ASP-$UNIQUE_STRING"
LOG_ANALYTICS_WORKSPACE_NAME="$LOG_ANALYTICS_NAME"

# ARM Template settings
TEMPLATE_FILE="./certificate-lifecycle-management/.armtemplate/fulllabdeploy.json"
DEPLOYMENT_NAME="certlc-deployment-\$(date +%Y%m%d-%H%M%S)"

# Azure AD/Entra ID
TENANT_ID="$TENANT_ID"

# Additional settings
ENABLE_MONITORING="true"
ENABLE_DIAGNOSTICS="true"
DEBUG_MODE="false"
EOF

    echo -e "${GREEN}Configuration file created successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Please review and update the following values manually:${NC}"
    echo "- RECIPIENT_EMAIL: Your email address for notifications"
    if [ -z "$KEY_VAULT_NAME" ]; then
        echo "- KEY_VAULT_NAME: Could not auto-detect"
    fi
    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
        echo "- STORAGE_ACCOUNT_NAME: Could not auto-detect"
    fi
    echo ""
    echo "Configuration saved to: $ENV_FILE"
}

validate_config() {
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        echo "Run: $0 init"
        exit 1
    fi
    
    # Source the .env file
    source "$ENV_FILE"
    
    echo -e "${BLUE}Validating configuration...${NC}"
    
    ERRORS=0
    WARNINGS=0
    
    # Check required variables
    if [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${RED}Error: RESOURCE_GROUP is not set${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ -z "$LOCATION" ]; then
        echo -e "${RED}Error: LOCATION is not set${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ -z "$UNIQUE_STRING" ]; then
        echo -e "${RED}Error: UNIQUE_STRING is not set${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check if resource group exists (if Azure CLI is available)
    if command -v az &> /dev/null && [ ! -z "$RESOURCE_GROUP" ]; then
        if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
            echo -e "${YELLOW}Warning: Resource group '$RESOURCE_GROUP' not found or not accessible${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    # Check email format
    if [ ! -z "$RECIPIENT_EMAIL" ] && [[ ! "$RECIPIENT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo -e "${YELLOW}Warning: RECIPIENT_EMAIL format appears invalid${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✓ Configuration validation passed${NC}"
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}Found $WARNINGS warning(s)${NC}"
        fi
    else
        echo -e "${RED}✗ Configuration validation failed with $ERRORS error(s)${NC}"
        exit 1
    fi
}

show_config() {
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        echo "Run: $0 init"
        exit 1
    fi
    
    echo -e "${BLUE}Current Configuration:${NC}"
    echo "====================="
    
    # Read and display the .env file with syntax highlighting
    while IFS= read -r line; do
        if [[ $line =~ ^#.* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line =~ ^[[:space:]]*$ ]]; then
            echo "$line"
        else
            echo -e "${YELLOW}$line${NC}"
        fi
    done < "$ENV_FILE"
}

reset_config() {
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Warning: This will reset your .env file to template${NC}"
        read -p "Are you sure? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            echo -e "${GREEN}Configuration reset to template${NC}"
        else
            echo "Cancelled."
        fi
    else
        echo -e "${YELLOW}No .env file found to reset${NC}"
    fi
}

# Main command processing
case "$1" in
    init)
        init_config
        ;;
    auto-populate)
        shift
        RESOURCE_GROUP=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --resource-group)
                    RESOURCE_GROUP="$2"
                    shift 2
                    ;;
                *)
                    echo -e "${RED}Unknown option: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done
        auto_populate "$RESOURCE_GROUP"
        ;;
    validate)
        validate_config
        ;;
    show)
        show_config
        ;;
    reset)
        reset_config
        ;;
    --help|-h|help)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac