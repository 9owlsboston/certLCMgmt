#!/bin/bash

# =============================================================================
# Fix Key Vault Access - Diagnose and Re-enable Network Access
# =============================================================================
# Purpose: Handle Key Vault network access issues, specifically when public
#          network access is disabled by security policies
# Error: "Public network access is disabled and request is not from a trusted service"
# 
# This script provides multiple options to restore Key Vault access:
# 1. Temporarily enable public access for management
# 2. Configure trusted service bypass
# 3. Add your current IP to the firewall rules
# 4. Check private endpoint configuration
# =============================================================================

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load common configuration
if [[ -f "$ROOT_DIR/common.sh" ]]; then
    source "$ROOT_DIR/common.sh"
else
    echo "❌ Error: common.sh not found. Please ensure you're running from the correct directory."
    exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "\n${CYAN}🔐 $1${NC}"
    echo "========================================"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}📋 $1${NC}"
}

# Function to check if user is authenticated
check_azure_auth() {
    if ! az account show &>/dev/null; then
        print_error "Not authenticated to Azure. Please run 'az login' first."
        exit 1
    fi
    
    local account_info
    account_info=$(az account show --query "{name:name, id:id}" -o tsv)
    print_info "Using Azure subscription: $account_info"
}

# Function to get current public IP
get_current_ip() {
    local ip=""
    # Try multiple methods to get public IP
    if command -v curl &> /dev/null; then
        ip=$(curl -s https://api.ipify.org/ 2>/dev/null || echo "")
    fi
    
    if [[ -z "$ip" ]] && command -v wget &> /dev/null; then
        ip=$(wget -qO- https://api.ipify.org/ 2>/dev/null || echo "")
    fi
    
    if [[ -z "$ip" ]]; then
        ip=$(curl -s https://ifconfig.me/ 2>/dev/null || echo "unknown")
    fi
    
    echo "$ip"
}

# Function to diagnose Key Vault network configuration
diagnose_keyvault_network() {
    local kv_name="$1"
    
    print_header "Diagnosing Key Vault Network Configuration"
    
    print_info "Key Vault: $kv_name"
    
    # Get Key Vault network configuration
    echo "🔍 Checking current network access rules..."
    
    local network_rules
    network_rules=$(az keyvault show --name "$kv_name" \
        --query "{publicNetworkAccess:properties.publicNetworkAccess, \
                  networkAcls:properties.networkAcls}" \
        -o json 2>/dev/null || echo "{}")
    
    if [[ "$network_rules" == "{}" ]]; then
        print_error "Unable to retrieve Key Vault network configuration. Check permissions."
        return 1
    fi
    
    echo "📊 Current Network Configuration:"
    echo "$network_rules" | jq '.'
    
    # Check specific settings
    local public_access
    local default_action
    local bypass
    public_access=$(echo "$network_rules" | jq -r '.publicNetworkAccess // "null"')
    default_action=$(echo "$network_rules" | jq -r '.networkAcls.defaultAction // "null"')
    bypass=$(echo "$network_rules" | jq -r '.networkAcls.bypass // "null"')
    
    echo ""
    print_info "Analysis:"
    echo "  - Public Network Access: $public_access"
    echo "  - Default Action: $default_action"
    echo "  - Trusted Services Bypass: $bypass"
    
    if [[ "$public_access" == "Disabled" ]]; then
        print_warning "Public network access is DISABLED"
        echo "  This is likely the cause of your access issues."
    elif [[ "$default_action" == "Deny" ]]; then
        print_warning "Default action is DENY"
        echo "  Access is restricted by firewall rules."
    fi
    
    # Check IP rules
    local ip_rules
    ip_rules=$(echo "$network_rules" | jq -r '.networkAcls.ipRules // []' | jq length)
    echo "  - IP Rules configured: $ip_rules"
    
    # Check virtual network rules
    local vnet_rules
    vnet_rules=$(echo "$network_rules" | jq -r '.networkAcls.virtualNetworkRules // []' | jq length)
    echo "  - Virtual Network Rules: $vnet_rules"
    
    return 0
}

# Function to show available solutions
show_solutions() {
    local kv_name="$1"
    local current_ip="$2"
    
    print_header "Available Solutions"
    
    echo "Choose one of the following options to restore Key Vault access:"
    echo ""
    
    echo -e "${YELLOW}Option 1: Temporarily Enable Public Access${NC}"
    echo "   ⚠️  This allows access from anywhere (least secure, but quickest)"
    echo "   💡 Use this for quick troubleshooting, then re-secure afterwards"
    echo ""
    
    echo -e "${YELLOW}Option 2: Add Current IP to Firewall Rules${NC}"
    echo "   🔒 More secure - only allows access from your current IP"
    echo "   📍 Your current public IP: $current_ip"
    echo "   💡 Recommended for regular management access"
    echo ""
    
    echo -e "${YELLOW}Option 3: Enable Trusted Services Bypass${NC}"
    echo "   🛡️  Allows Azure trusted services to access the vault"
    echo "   💡 Good for Azure services integration"
    echo ""
    
    echo -e "${YELLOW}Option 4: Check Private Endpoint Configuration${NC}"
    echo "   🔐 For environments using private endpoints"
    echo "   💡 Advanced networking configuration"
    echo ""
    
    echo -e "${YELLOW}Option 5: Show Current Configuration Only${NC}"
    echo "   📊 Just display current settings without making changes"
    echo ""
}

# Function to enable public access temporarily
enable_public_access() {
    local kv_name="$1"
    
    print_header "Enabling Public Access (Temporary)"
    
    print_warning "This will enable public network access to the Key Vault"
    print_warning "Remember to re-secure the vault after your management tasks!"
    
    read -p "⚠️  Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 1
    fi
    
    echo "🔧 Enabling public network access..."
    az keyvault update --name "$kv_name" --public-network-access Enabled
    
    print_success "Public access enabled successfully!"
    print_warning "SECURITY REMINDER: Re-disable public access when done:"
    echo "  az keyvault update --name $kv_name --public-network-access Disabled"
}

# Function to add current IP to firewall rules
add_current_ip() {
    local kv_name="$1"
    local current_ip="$2"
    
    print_header "Adding Current IP to Firewall Rules"
    
    if [[ "$current_ip" == "unknown" ]]; then
        print_error "Unable to determine your current public IP address"
        read -p "Enter your public IP address manually: " -r manual_ip
        current_ip="$manual_ip"
    fi
    
    print_info "Adding IP: $current_ip to Key Vault firewall rules"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 1
    fi
    
    echo "🔧 Adding IP rule..."
    # First ensure public access is enabled
    az keyvault update --name "$kv_name" --public-network-access Enabled
    
    # Add IP rule
    az keyvault network-rule add --name "$kv_name" --ip-address "$current_ip"
    
    # Set default action to deny (this activates the firewall)
    az keyvault update --name "$kv_name" --default-action Deny
    
    print_success "IP rule added successfully!"
    print_info "Your IP ($current_ip) now has access to the Key Vault"
    print_info "To remove this rule later:"
    echo "  az keyvault network-rule remove --name $kv_name --ip-address $current_ip"
}

# Function to enable trusted services bypass
enable_trusted_services() {
    local kv_name="$1"
    
    print_header "Enabling Trusted Services Bypass"
    
    print_info "This allows Azure trusted services to access the Key Vault"
    print_info "even when network restrictions are in place."
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 1
    fi
    
    echo "🔧 Configuring trusted services bypass..."
    az keyvault update --name "$kv_name" --bypass AzureServices
    
    print_success "Trusted services bypass enabled!"
    print_info "Azure services can now access the Key Vault through trusted service endpoints"
}

# Function to check private endpoint configuration
check_private_endpoints() {
    local kv_name="$1"
    
    print_header "Checking Private Endpoint Configuration"
    
    echo "🔍 Looking for private endpoints..."
    local private_endpoints
    private_endpoints=$(az keyvault private-endpoint-connection list --vault-name "$kv_name" -o json 2>/dev/null || echo "[]")
    
    local endpoint_count
    endpoint_count=$(echo "$private_endpoints" | jq length)
    
    if [[ "$endpoint_count" -eq 0 ]]; then
        print_info "No private endpoints configured for this Key Vault"
        print_info "Private endpoints would allow access from specific virtual networks"
    else
        print_info "Found $endpoint_count private endpoint(s):"
        echo "$private_endpoints" | jq -r '.[] | "  - " + .name + " (" + .properties.connectionState.status + ")"'
        
        print_info "If you're connecting from a VM in the connected VNet, access should work"
        print_info "Otherwise, you may need to use one of the other access methods"
    fi
}

# Main function
main() {
    print_header "Key Vault Access Diagnostic and Fix Tool"
    echo "Purpose: Resolve Key Vault network access restrictions"
    echo ""
    
    # Check authentication
    check_azure_auth
    
    # Get Key Vault name from configuration
    if [[ -z "${KEY_VAULT_NAME:-}" ]]; then
        print_error "KEY_VAULT_NAME not found in configuration"
        print_info "Please set up your configuration first:"
        echo "  ./config.sh auto-populate --resource-group <your-resource-group>"
        exit 1
    fi
    
    print_info "Key Vault: $KEY_VAULT_NAME"
    print_info "Resource Group: $RESOURCE_GROUP"
    
    # Get current IP
    local current_ip
    current_ip=$(get_current_ip)
    print_info "Your current public IP: $current_ip"
    
    echo ""
    
    # Diagnose current configuration
    if ! diagnose_keyvault_network "$KEY_VAULT_NAME"; then
        print_error "Failed to diagnose Key Vault configuration"
        exit 1
    fi
    
    echo ""
    
    # Show available solutions
    show_solutions "$KEY_VAULT_NAME" "$current_ip"
    
    # Get user choice
    echo -n "Select an option (1-5): "
    read -r choice
    
    case $choice in
        1)
            enable_public_access "$KEY_VAULT_NAME"
            ;;
        2)
            add_current_ip "$KEY_VAULT_NAME" "$current_ip"
            ;;
        3)
            enable_trusted_services "$KEY_VAULT_NAME"
            ;;
        4)
            check_private_endpoints "$KEY_VAULT_NAME"
            ;;
        5)
            print_info "Current configuration displayed above."
            ;;
        *)
            print_error "Invalid option selected"
            exit 1
            ;;
    esac
    
    echo ""
    print_header "Testing Access After Changes"
    
    # Test access
    echo "🧪 Testing Key Vault access..."
    if az keyvault certificate list --vault-name "$KEY_VAULT_NAME" --query "length(@)" -o tsv &>/dev/null; then
        print_success "Key Vault access restored successfully!"
        print_info "You can now run your certificate lifecycle scripts"
    else
        print_warning "Access test failed. You may need to:"
        echo "  1. Wait a few minutes for changes to propagate"
        echo "  2. Try a different solution option"
        echo "  3. Check with your Azure administrator about network policies"
    fi
    
    echo ""
    print_info "🔧 To test your certificate lifecycle scripts:"
    echo "  cd .."
    echo "  ./quick-status.sh"
    echo ""
    print_warning "🔒 Security Reminder:"
    echo "  Remember to review and tighten network access rules after completing your tasks"
}

# Run main function
main "$@"