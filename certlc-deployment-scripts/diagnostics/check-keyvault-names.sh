#!/bin/bash

# Key Vault Name Availability Checker
# 
# PURPOSE: This script helps diagnose Key Vault naming issues when redeploying ARM templates
# PROBLEM: Even after deleting a resource group, Key Vault names remain reserved due to soft delete
# SOLUTION: Check availability, detect soft-deleted vaults, and suggest available alternatives
#
# Common scenario: You delete the resource group but ARM template fails because 
# Key Vault name is still "taken" by a soft-deleted vault

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Key Vault Name Availability Checker${NC}"
echo "========================================"
echo -e "${PURPLE}Purpose: Diagnose Key Vault naming issues for ARM template redeployment${NC}"
echo ""

# Load configuration from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    echo -e "${GREEN}📋 Loading configuration from .env file...${NC}"
    # shellcheck source=../common.sh
    VALIDATE_CONFIG=false source "$SCRIPT_DIR/../common.sh"
    
    # Show current configuration
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Unique String: $UNIQUE_STRING"
    echo "Key Vault Name: $KEY_VAULT_NAME"
    echo ""
else
    echo -e "${YELLOW}⚠️  No .env configuration found.${NC}"
    echo "Run '../config.sh init' or '../config.sh auto-populate --resource-group <name>' to set up configuration."
    echo ""
    
    # Fallback to manual input for standalone usage
    echo -e "${BLUE}Manual Input Mode:${NC}"
    BASE_NAME="DEMO-KV"
    read -p "Enter your unique string for Key Vault naming (e.g., 'lab01', '1101'): " UNIQUE_STRING
    
    if [ -z "$UNIQUE_STRING" ]; then
        echo -e "${RED}No unique string provided. Exiting.${NC}"
        exit 1
    fi
    
    KEY_VAULT_NAME="${BASE_NAME}-${UNIQUE_STRING}"
    echo "Testing Key Vault name: $KEY_VAULT_NAME"
    echo ""
fi

echo -e "${YELLOW}🔍 Step 1: Checking Key Vault name availability...${NC}"

if [ -n "$KEY_VAULT_NAME" ]; then
    echo "Checking: $KEY_VAULT_NAME"
    
    # Check availability
    echo "Checking name availability..."
    
    # Check if Azure CLI is available and authenticated
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI not found${NC}"
        echo "Please install Azure CLI and run 'az login' to use this script."
        exit 1
    fi
    
    # Test Azure authentication
    if ! az account show &>/dev/null; then
        echo -e "${RED}❌ Not logged in to Azure${NC}"
        echo "Please run 'az login' to authenticate before using this script."
        exit 1
    fi
    
    # Check Key Vault name availability
    AVAILABILITY_RESULT=$(az keyvault check-name --name "$KEY_VAULT_NAME" --output json 2>/dev/null)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        NAME_AVAILABLE=$(echo "$AVAILABILITY_RESULT" | jq -r '.nameAvailable')
        REASON=$(echo "$AVAILABILITY_RESULT" | jq -r '.reason // "None"')
        MESSAGE=$(echo "$AVAILABILITY_RESULT" | jq -r '.message // "None"')
        
        echo ""
        echo -e "${BLUE}Results:${NC}"
        echo "✓ Name Available: $NAME_AVAILABLE"
        echo "✓ Reason: $REASON"
        echo "✓ Message: $MESSAGE"
        echo ""
        
        if [ "$NAME_AVAILABLE" = "true" ]; then
            echo -e "${GREEN}🎉 SUCCESS: Key Vault name '$KEY_VAULT_NAME' is available!${NC}"
            echo "✅ You can proceed with your ARM template deployment."
            
            # Check if the resource group exists for context
            if [ -n "$RESOURCE_GROUP" ] && az group show --name "$RESOURCE_GROUP" &>/dev/null; then
                echo "✅ Resource group '$RESOURCE_GROUP' exists and is ready for deployment."
            fi
            
            exit 0
        else
            echo -e "${RED}❌ PROBLEM: Key Vault name '$KEY_VAULT_NAME' is NOT available${NC}"
            echo ""
            echo -e "${YELLOW}🔍 INVESTIGATING THE ISSUE...${NC}"
            
            if [ "$REASON" = "AlreadyExists" ]; then
                echo ""
                echo -e "${BLUE}Checking if Key Vault exists in your current subscription...${NC}"
                
                if az keyvault show --name "$KEY_VAULT_NAME" &>/dev/null; then
                    EXISTING_LOCATION=$(az keyvault show --name "$KEY_VAULT_NAME" --query location -o tsv)
                    EXISTING_RG=$(az keyvault show --name "$KEY_VAULT_NAME" --query resourceGroup -o tsv)
                    echo -e "${YELLOW}📍 Found ACTIVE Key Vault in your current subscription:${NC}"
                    echo "   Resource Group: $EXISTING_RG"
                    echo "   Location: $EXISTING_LOCATION"
                    echo ""
                    echo -e "${PURPLE}💡 SOLUTIONS:${NC}"
                    echo "   1. Delete the existing Key Vault if it's not needed"
                    echo "   2. Use a different UNIQUE_STRING in your configuration"
                    echo "   3. Use the existing Key Vault (update ARM template parameters)"
                    echo ""
                    echo -e "${BLUE}Commands to delete existing Key Vault:${NC}"
                    echo "   az keyvault delete --name $KEY_VAULT_NAME --resource-group $EXISTING_RG"
                    echo "   az keyvault purge --name $KEY_VAULT_NAME  # Remove from soft delete"
                else
                    echo -e "${YELLOW}🤔 Key Vault not found in your current subscription.${NC}"
                    echo "   It likely exists in a different subscription or tenant, OR"
                    echo -e "${RED}   It's in SOFT DELETE state (most common cause!)${NC}"
                fi
                
                # Check for soft-deleted vaults (the main issue!)
                echo ""
                echo -e "${BLUE}🗑️  Checking for SOFT-DELETED Key Vaults (common cause of ARM failures)...${NC}"
                SOFT_DELETED=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json 2>/dev/null)
                
                if [ "$SOFT_DELETED" != "[]" ] && [ "$SOFT_DELETED" != "" ] && [ "$SOFT_DELETED" != "null" ]; then
                    echo -e "${RED}🎯 FOUND THE PROBLEM: Soft-deleted Key Vault(s)!${NC}"
                    echo ""
                    echo "$SOFT_DELETED" | jq -r '.[] | "   Name: \(.name)\n   Location: \(.location)\n   Deletion Date: \(.deletionDate)\n   Recovery Level: \(.recoveryLevel // "Unknown")\n"'
                    
                    echo -e "${PURPLE}💡 SOLUTION FOR ARM TEMPLATE REDEPLOYMENT:${NC}"
                    echo "   The Key Vault is in soft delete state. You have two options:"
                    echo ""
                    echo -e "${GREEN}   Option 1: PURGE the soft-deleted vault (PERMANENT deletion)${NC}"
                    echo "   az keyvault purge --name $KEY_VAULT_NAME"
                    echo "   ⚠️  WARNING: This permanently deletes the vault and all its contents!"
                    echo ""
                    echo -e "${GREEN}   Option 2: RECOVER the soft-deleted vault${NC}"
                    echo "   az keyvault recover --name $KEY_VAULT_NAME"
                    echo "   📝 Note: This restores the vault with all previous contents"
                    echo ""
                    echo -e "${BLUE}   Option 3: Use a different UNIQUE_STRING${NC}"
                    echo "   Update your .env file with a new UNIQUE_STRING value"
                else
                    echo -e "${GREEN}✅ No soft-deleted Key Vaults found with this name.${NC}"
                    echo "   The name conflict is likely from a different subscription/tenant."
                fi
            fi
        fi
    else
        echo -e "${RED}❌ Error checking name availability${NC}"
        echo "This could be due to:"
        echo "• Network connectivity issues"
        echo "• Azure CLI authentication problems"
        echo "• Azure service temporary unavailability"
        echo ""
        echo "Try running 'az login' and ensure you have internet connectivity."
    fi
else
    echo -e "${RED}❌ No Key Vault name configured.${NC}"
    echo "Please run '../config.sh init' or '../config.sh auto-populate --resource-group <name>' to set up configuration."
    exit 1
fi

echo ""
echo -e "${YELLOW}🔍 Step 2: Finding alternative available names...${NC}"

# Generate alternative names for ARM template redeployment
echo "If you need an alternative name, here are some available options:"

# Extract base name from current Key Vault name (e.g., "DEMO-KV" from "DEMO-KV-suffix")
if [ -n "$KEY_VAULT_NAME" ]; then
    BASE_NAME=$(echo "$KEY_VAULT_NAME" | sed 's/-[^-]*$//')
else
    BASE_NAME="DEMO-KV"  # Default fallback
fi

echo "Using base name pattern: $BASE_NAME"

# Function to check name availability
check_name() {
    local name=$1
    local result
    result=$(az keyvault check-name --name "$name" --query nameAvailable -o tsv 2>/dev/null)
    echo "$result"
}

# Try different patterns for quick alternatives
echo ""
echo -e "${BLUE}💡 Available Key Vault Names (for ARM template redeployment):${NC}"

FOUND_AVAILABLE=false

# Try with current date/time for uniqueness
DATE_STRING=$(date +%m%d)
TIME_STRING=$(date +%H%M)
YEAR_STRING=$(date +%y)

# Try quick patterns that are likely to be available
PATTERNS=(
    "${BASE_NAME}-${DATE_STRING}${TIME_STRING:0:2}"
    "${BASE_NAME}-${YEAR_STRING}${DATE_STRING}"
    "${BASE_NAME}-v${DATE_STRING}"
    "${BASE_NAME}-new${DATE_STRING}"
    "${BASE_NAME}-${DATE_STRING}a"
    "${BASE_NAME}-${DATE_STRING}b"
    "${BASE_NAME}-${RANDOM:0:4}"
)

echo "Checking quick alternatives..."
for pattern in "${PATTERNS[@]}"; do
    if [ ${#pattern} -le 24 ]; then  # Key Vault name limit
        available=$(check_name "$pattern")
        if [ "$available" = "true" ]; then
            echo -e "${GREEN}✅ $pattern${NC}"
            FOUND_AVAILABLE=true
        fi
    fi
done

if [ "$FOUND_AVAILABLE" = "true" ]; then
    echo ""
    echo -e "${GREEN}🎉 Found available names above!${NC}"
    if [ -f "$SCRIPT_DIR/../.env" ]; then
        echo -e "${PURPLE}💡 To use one of these names:${NC}"
        echo "   1. Pick an available name from the list above"
        echo "   2. Extract the suffix (e.g., from 'DEMO-KV-1101a', use '1101a')"
        echo "   3. Update UNIQUE_STRING in your .env file"
        echo "   4. Run '../config.sh validate'"
        echo "   5. Redeploy your ARM template"
    else
        echo "For example, if you choose 'DEMO-KV-1101a', set UNIQUE_STRING=\"1101a\""
    fi
else
    echo ""
    echo -e "${YELLOW}⚠️  No available names found in quick patterns.${NC}"
    echo "Try the manual testing below for custom names."
fi

echo ""
echo -e "${YELLOW}🧪 Step 3: Manual name testing (optional)...${NC}"
echo "Test specific names if the automatic suggestions don't work:"
echo ""

while true; do
    read -p "Enter a Key Vault name to test (or 'done' to finish): " TEST_NAME
    
    if [ "$TEST_NAME" = "done" ] || [ "$TEST_NAME" = "quit" ] || [ "$TEST_NAME" = "exit" ]; then
        break
    fi
    
    if [ -z "$TEST_NAME" ]; then
        continue
    fi
    
    # Validate name format
    if [[ ! "$TEST_NAME" =~ ^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] || [ ${#TEST_NAME} -lt 3 ] || [ ${#TEST_NAME} -gt 24 ]; then
        echo -e "${RED}❌ Invalid name format. Key Vault names must:${NC}"
        echo "   • Be 3-24 characters long"
        echo "   • Start with a letter"
        echo "   • End with a letter or number"
        echo "   • Contain only letters, numbers, and hyphens"
        continue
    fi
    
    available=$(check_name "$TEST_NAME")
    if [ "$available" = "true" ]; then
        echo -e "${GREEN}✅ '$TEST_NAME' is available!${NC}"
        
        # Extract unique string suggestion
        if [[ "$TEST_NAME" =~ ^${BASE_NAME}-(.+)$ ]]; then
            SUGGESTED_UNIQUE="${BASH_REMATCH[1]}"
            echo "   💡 Suggested UNIQUE_STRING for .env: '$SUGGESTED_UNIQUE'"
        fi
    else
        echo -e "${RED}❌ '$TEST_NAME' is not available${NC}"
    fi
    echo ""
done

echo ""
echo -e "${PURPLE}📝 SUMMARY FOR ARM TEMPLATE REDEPLOYMENT:${NC}"
echo "============================================="
echo ""
echo "If your ARM template deployment failed due to Key Vault naming conflicts:"
echo ""
echo -e "${BLUE}1. SOFT DELETE ISSUE (most common):${NC}"
echo "   • Run: az keyvault purge --name YOUR-KV-NAME"
echo "   • Then redeploy your ARM template"
echo ""
echo -e "${BLUE}2. USE DIFFERENT NAME:${NC}"
echo "   • Pick an available name from the suggestions above"
echo "   • Update UNIQUE_STRING in your .env file"
echo "   • Run: ../config.sh validate"
echo "   • Redeploy your ARM template"
echo ""
echo -e "${BLUE}3. RECOVER EXISTING VAULT:${NC}"
echo "   • Run: az keyvault recover --name YOUR-KV-NAME"
echo "   • Update your ARM template to use existing vault"
echo ""
echo -e "${GREEN}✅ After resolving the naming issue, your ARM template should deploy successfully!${NC}"