#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - Core Infrastructure
# =============================================================================

set -e  # Exit on any error

# Source environment variables
if [ -f "./01-environment-setup.sh" ]; then
    source ./01-environment-setup.sh
else
    echo "ERROR: Please run 01-environment-setup.sh first to set environment variables"
    exit 1
fi

echo "Creating core infrastructure for Azure Certificate Management Services..."

# =============================================================================
# CREATE RESOURCE GROUP
# =============================================================================

echo "Creating Resource Group: $RESOURCE_GROUP_NAME"
if az group show --name "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Resource Group '$RESOURCE_GROUP_NAME' already exists"
else
    echo "Creating new Resource Group..."
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags \
            Purpose="CertificateLifecycleManagement" \
            Environment="Production" \
            CreatedBy="AzureCLI-Script"
    echo "✓ Resource Group created: $RESOURCE_GROUP_NAME"
fi

# =============================================================================
# CREATE AZURE KEY VAULT
# =============================================================================

echo "Creating Azure Key Vault: $KEY_VAULT_NAME"
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Key Vault '$KEY_VAULT_NAME' already exists"
    
    # Update existing Key Vault configuration to match requirements
    echo "Updating Key Vault configuration..."
    az keyvault update \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --enable-rbac-authorization true \
        --enable-soft-delete true \
        --public-network-access Enabled
    echo "✓ Key Vault configuration updated"
else
    echo "Creating new Key Vault..."
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku Standard \
        --enable-rbac-authorization true \
        --enable-soft-delete true \
        --soft-delete-retention-days 90 \
        --enable-purge-protection false \
        --public-network-access Enabled \
        --tags \
            Purpose="CertificateStorage" \
            Component="KeyVault"
    echo "✓ Key Vault created: $KEY_VAULT_NAME"
fi

# =============================================================================
# CREATE STORAGE ACCOUNT
# =============================================================================

echo "Creating Storage Account: $STORAGE_ACCOUNT_NAME"
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Storage Account '$STORAGE_ACCOUNT_NAME' already exists"
    
    # Update existing Storage Account configuration if needed
    echo "Updating Storage Account configuration..."
    az storage account update \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access true \
        --allow-shared-key-access true \
        --https-only true
    echo "✓ Storage Account configuration updated"
else
    echo "Creating new Storage Account..."
    az storage account create \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --access-tier Hot \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access true \
        --allow-shared-key-access true \
        --https-only true \
        --tags \
            Purpose="CertificateQueue" \
            Component="Storage"
    echo "✓ Storage Account created: $STORAGE_ACCOUNT_NAME"
fi

# Enable queue services (this is usually enabled by default, but making it explicit)
echo "Configuring queue services for storage account..."
az storage cors add \
    --services q \
    --methods GET POST PUT DELETE \
    --origins "*" \
    --allowed-headers "*" \
    --exposed-headers "*" \
    --max-age 3600 \
    --account-name "$STORAGE_ACCOUNT_NAME" 2>/dev/null || echo "CORS already configured or not needed"

# Create the certificate lifecycle queue
echo "Creating certificate lifecycle queue: $QUEUE_NAME"
if az storage queue exists --name "$QUEUE_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login --query "exists" -o tsv 2>/dev/null | grep -q "true"; then
    echo "✓ Queue '$QUEUE_NAME' already exists"
else
    az storage queue create \
        --name "$QUEUE_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --auth-mode login
    echo "✓ Queue created: $QUEUE_NAME"
fi

# =============================================================================
# CREATE AUTOMATION ACCOUNT
# =============================================================================

echo "Creating Automation Account: $AUTOMATION_ACCOUNT_NAME"
if az automation account show --name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Automation Account '$AUTOMATION_ACCOUNT_NAME' already exists"
    
    # Ensure managed identity is enabled
    echo "Ensuring managed identity is enabled..."
    az automation account update \
        --name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --assign-identity
    echo "✓ Automation Account configuration updated"
else
    echo "Creating new Automation Account..."
    az automation account create \
        --name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku Basic \
        --assign-identity \
        --tags \
            Purpose="CertificateAutomation" \
            Component="Automation"
    echo "✓ Automation Account created: $AUTOMATION_ACCOUNT_NAME"
fi

# Wait a moment for the automation account to be fully ready
echo "Waiting for Automation Account to be fully provisioned..."
sleep 30

# =============================================================================
# INSTALL REQUIRED POWERSHELL MODULES
# =============================================================================

echo "Installing required PowerShell modules in Automation Account..."

# Install PSPKI module for certificate management
echo "Checking PSPKI module..."
if az automation module show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "PSPKI" --output none 2>/dev/null; then
    echo "✓ PSPKI module already exists"
    PSPKI_STATUS=$(az automation module show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "PSPKI" --query "provisioningState" -o tsv)
    echo "PSPKI module status: $PSPKI_STATUS"
else
    echo "Installing PSPKI module..."
    az automation module create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "PSPKI" \
        --content-link-uri "https://www.powershellgallery.com/api/v2/Packages/PSPKI/4.0.0"

    # Wait for module installation to complete
    echo "Waiting for PSPKI module installation..."
    for i in {1..20}; do
        status=$(az automation module show \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "PSPKI" \
            --query "provisioningState" -o tsv 2>/dev/null || echo "Installing")
        
        if [ "$status" = "Succeeded" ]; then
            echo "✓ PSPKI module installed successfully"
            break
        elif [ "$status" = "Failed" ]; then
            echo "⚠ WARNING: PSPKI module installation failed, continuing..."
            break
        else
            echo "PSPKI module status: $status - waiting... ($i/20)"
            sleep 30
        fi
    done
fi

# =============================================================================
# CREATE LOG ANALYTICS WORKSPACE
# =============================================================================

echo "Creating Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE_NAME"
if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Log Analytics Workspace '$LOG_ANALYTICS_WORKSPACE_NAME' already exists"
    
    # Update configuration if needed
    echo "Updating Log Analytics Workspace configuration..."
    az monitor log-analytics workspace update \
        --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --retention-time 120
    echo "✓ Log Analytics Workspace configuration updated"
else
    echo "Creating new Log Analytics Workspace..."
    az monitor log-analytics workspace create \
        --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku PerGB2018 \
        --retention-time 120 \
        --tags \
            Purpose="CertificateMonitoring" \
            Component="LogAnalytics"
    echo "✓ Log Analytics Workspace created: $LOG_ANALYTICS_WORKSPACE_NAME"
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "CORE INFRASTRUCTURE CREATED SUCCESSFULLY"
echo "==============================================================================="
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Queue Name: $QUEUE_NAME"
echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo "Log Analytics: $LOG_ANALYTICS_WORKSPACE_NAME"
echo ""
echo "Next steps:"
echo "1. Run 03-event-grid-setup.sh to configure Event Grid"
echo "2. Run 04-automation-setup.sh to configure automation components"
echo "3. Run 05-rbac-permissions.sh to set up permissions"
echo "==============================================================================="