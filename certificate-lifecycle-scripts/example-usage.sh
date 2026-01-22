#!/bin/bash

# =============================================================================
# Example Usage of Configuration System
# =============================================================================

# This script demonstrates how to use the configuration system in your own scripts

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration - this handles all environment variable loading and validation
echo "Loading configuration..."
source "$SCRIPT_DIR/config.sh"

# Now all configuration variables are available
echo "Configuration loaded successfully!"

# Example: Use the configuration variables in your script
echo ""
echo "=== Current Configuration ==="
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Location: $LOCATION"
echo "Certificate: $CERTIFICATE_NAME"
echo "Polling Interval: $POLLING_INTERVAL seconds"

# Example: Check if we're in production
if [ "${TAG_ENVIRONMENT:-}" = "production" ]; then
    echo ""
    echo "⚠️  WARNING: Running in PRODUCTION environment!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Example: Use variables in Azure CLI commands
echo ""
echo "=== Testing Azure CLI with configuration ==="

# Check if resource group exists
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    echo "✅ Resource group '$RESOURCE_GROUP_NAME' exists"
else
    echo "❌ Resource group '$RESOURCE_GROUP_NAME' does not exist"
    echo "   You may need to create it first"
fi

# Check if Key Vault exists
if az keyvault show --name "$KEY_VAULT_NAME" &>/dev/null; then
    echo "✅ Key Vault '$KEY_VAULT_NAME' exists"
else
    echo "❌ Key Vault '$KEY_VAULT_NAME' does not exist"
    echo "   You may need to create it first"
fi

echo ""
echo "=== Configuration example completed ==="
echo "You can now use all the loaded variables in your scripts!"

# Example: Export additional derived variables if needed
export FULL_KEY_VAULT_URI="https://$KEY_VAULT_NAME.vault.azure.net/"
export CERTIFICATE_SECRET_URL="$FULL_KEY_VAULT_URI/secrets/$CERTIFICATE_NAME"

echo "Additional variables:"
echo "  Key Vault URI: $FULL_KEY_VAULT_URI"
echo "  Certificate URL: $CERTIFICATE_SECRET_URL"