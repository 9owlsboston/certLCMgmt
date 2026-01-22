#!/bin/bash

# =============================================================================
# Environment Configuration Loader for Azure Certificate Lifecycle Management
# =============================================================================
# This script provides standardized environment variable loading and validation
# Usage: source ./config.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration file paths (in order of preference)
readonly CONFIG_FILES=(
    ".env.local"     # Local overrides (git-ignored)
    ".env"           # Main configuration
    ".env.example"   # Example/template
)

# Function to log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to load environment file
load_env_file() {
    local env_file="$1"
    
    if [ ! -f "$env_file" ]; then
        return 1
    fi
    
    log_info "Loading configuration from: $env_file"
    
    # Read file line by line, handle comments and empty lines
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Extract key=value pairs
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            # Export the variable only if not already set (allows override)
            if [ -z "${!key:-}" ]; then
                export "$key"="$value"
            fi
        fi
    done < "$env_file"
    
    return 0
}

# Function to load configuration with fallback
load_configuration() {
    local config_loaded=false
    
    for config_file in "${CONFIG_FILES[@]}"; do
        if load_env_file "$config_file"; then
            config_loaded=true
            break
        fi
    done
    
    if [ "$config_loaded" = false ]; then
        log_warn "No configuration file found. Using environment variables or defaults."
    fi
}

# Function to set default values
set_defaults() {
    # Azure defaults
    export LOCATION="${LOCATION:-eastus}"
    export KEY_VAULT_SKU="${KEY_VAULT_SKU:-standard}"
    export STORAGE_ACCOUNT_SKU="${STORAGE_ACCOUNT_SKU:-Standard_LRS}"
    export LOG_ANALYTICS_SKU="${LOG_ANALYTICS_SKU:-PerGB2018}"
    
    # Certificate defaults
    export CERTIFICATE_VALIDITY_DAYS="${CERTIFICATE_VALIDITY_DAYS:-365}"
    export CERTIFICATE_RENEWAL_DAYS_BEFORE="${CERTIFICATE_RENEWAL_DAYS_BEFORE:-30}"
    export POLLING_INTERVAL="${POLLING_INTERVAL:-43200}"
    
    # Storage defaults
    export STORAGE_QUEUE_NAME="${STORAGE_QUEUE_NAME:-cert-renewal-queue}"
    export CERTIFICATE_STORE_LOCATION="${CERTIFICATE_STORE_LOCATION:-/var/lib/waagent/Microsoft.Azure.KeyVault/certs}"
    
    # Security defaults
    export ENABLE_SOFT_DELETE="${ENABLE_SOFT_DELETE:-true}"
    export ENABLE_PURGE_PROTECTION="${ENABLE_PURGE_PROTECTION:-true}"
    export KEY_VAULT_FIREWALL_ENABLED="${KEY_VAULT_FIREWALL_ENABLED:-false}"
    
    # Backup defaults
    export BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
    
    # Generate unique suffix if not provided
    if [ -z "${UNIQUE_SUFFIX:-}" ]; then
        local temp_suffix
        temp_suffix=$(echo -n "${RESOURCE_GROUP_NAME:-default}" | sha256sum | cut -c1-8)
        export UNIQUE_SUFFIX="$temp_suffix"
    fi
    
    # Construct resource names with suffix if not explicitly set
    export KEY_VAULT_NAME="${KEY_VAULT_NAME:-kv-certlc-${UNIQUE_SUFFIX}}"
    export STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-stcertlc${UNIQUE_SUFFIX}}"
    export AUTOMATION_ACCOUNT_NAME="${AUTOMATION_ACCOUNT_NAME:-aa-certlc-${UNIQUE_SUFFIX}}"
    export LOG_ANALYTICS_WORKSPACE_NAME="${LOG_ANALYTICS_WORKSPACE_NAME:-law-certlc-${UNIQUE_SUFFIX}}"
}

# Function to validate required variables
validate_configuration() {
    local required_vars=(
        "SUBSCRIPTION_ID"
        "RESOURCE_GROUP_NAME"
        "KEY_VAULT_NAME"
        "STORAGE_ACCOUNT_NAME"
        "AUTOMATION_ACCOUNT_NAME"
        "LOG_ANALYTICS_WORKSPACE_NAME"
        "CERTIFICATE_NAME"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required configuration variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please create a .env file with the required variables."
        echo "You can copy .env.example as a starting point:"
        echo "  cp .env.example .env"
        echo ""
        return 1
    fi
    
    return 0
}

# Function to validate Azure resource naming conventions
validate_naming() {
    local errors=()
    
    # Key Vault name validation (3-24 chars, alphanumeric and hyphens)
    if [[ ! "$KEY_VAULT_NAME" =~ ^[a-zA-Z0-9-]{3,24}$ ]] || [[ "$KEY_VAULT_NAME" =~ ^- ]] || [[ "$KEY_VAULT_NAME" =~ -$ ]]; then
        errors+=("KEY_VAULT_NAME: Must be 3-24 characters, alphanumeric and hyphens, cannot start/end with hyphen")
    fi
    
    # Storage account name validation (3-24 chars, lowercase alphanumeric)
    if [[ ! "$STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
        errors+=("STORAGE_ACCOUNT_NAME: Must be 3-24 characters, lowercase alphanumeric only")
    fi
    
    # Automation account name validation (6-50 chars, alphanumeric and hyphens)
    if [[ ! "$AUTOMATION_ACCOUNT_NAME" =~ ^[a-zA-Z0-9-]{6,50}$ ]] || [[ "$AUTOMATION_ACCOUNT_NAME" =~ ^- ]] || [[ "$AUTOMATION_ACCOUNT_NAME" =~ -$ ]]; then
        errors+=("AUTOMATION_ACCOUNT_NAME: Must be 6-50 characters, alphanumeric and hyphens, cannot start/end with hyphen")
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        log_error "Naming convention violations:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
    
    return 0
}

# Function to display configuration summary
display_configuration() {
    echo ""
    echo "==============================================================================="
    echo "                    Azure Certificate Lifecycle Configuration"
    echo "==============================================================================="
    echo "Subscription ID:         $SUBSCRIPTION_ID"
    echo "Resource Group:          $RESOURCE_GROUP_NAME"
    echo "Location:                $LOCATION"
    echo ""
    echo "Key Vault:               $KEY_VAULT_NAME"
    echo "Storage Account:         $STORAGE_ACCOUNT_NAME"
    echo "Automation Account:      $AUTOMATION_ACCOUNT_NAME"
    echo "Log Analytics:           $LOG_ANALYTICS_WORKSPACE_NAME"
    echo ""
    echo "Certificate Name:        $CERTIFICATE_NAME"
    echo "Common Name:             ${CERTIFICATE_COMMON_NAME:-Not specified}"
    echo "SAN List:                ${CERTIFICATE_SAN_LIST:-Not specified}"
    echo "Validity Days:           $CERTIFICATE_VALIDITY_DAYS"
    echo "Renewal Days Before:     $CERTIFICATE_RENEWAL_DAYS_BEFORE"
    echo ""
    echo "Polling Interval:        $POLLING_INTERVAL seconds ($(($POLLING_INTERVAL / 3600)) hours)"
    echo "Certificate Store:       $CERTIFICATE_STORE_LOCATION"
    echo ""
    if [ -n "${TAG_ENVIRONMENT:-}" ]; then
        echo "Environment:             $TAG_ENVIRONMENT"
        echo "Project:                 ${TAG_PROJECT:-Not specified}"
        echo "Owner:                   ${TAG_OWNER:-Not specified}"
    fi
    echo "==============================================================================="
    echo ""
}

# Function to check Azure CLI login
check_azure_login() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        return 1
    fi
    
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure CLI. Please run: az login"
        return 1
    fi
    
    # Set subscription if specified
    local current_subscription
    current_subscription=$(az account show --query id -o tsv 2>/dev/null || echo "")
    if [ "$current_subscription" != "$SUBSCRIPTION_ID" ]; then
        log_info "Setting Azure subscription to: $SUBSCRIPTION_ID"
        if ! az account set --subscription "$SUBSCRIPTION_ID"; then
            log_error "Failed to set subscription. Please check SUBSCRIPTION_ID."
            return 1
        fi
    fi
    
    log_success "Azure CLI configured for subscription: $SUBSCRIPTION_ID"
    return 0
}

# Function to export common Azure CLI variables
export_azure_vars() {
    export AZURE_CORE_OUTPUT="${AZURE_CORE_OUTPUT:-table}"
    export AZURE_CORE_ONLY_SHOW_ERRORS="${AZURE_CORE_ONLY_SHOW_ERRORS:-true}"
}

# Main configuration loading function
configure_environment() {
    local skip_validation="${1:-false}"
    
    log_info "Configuring Azure Certificate Lifecycle Management environment..."
    
    # Load configuration files
    load_configuration
    
    # Set defaults
    set_defaults
    
    # Skip validation if requested (useful for partial configurations)
    if [ "$skip_validation" != "true" ]; then
        # Validate configuration
        if ! validate_configuration; then
            return 1
        fi
        
        # Validate naming conventions
        if ! validate_naming; then
            return 1
        fi
        
        # Check Azure CLI
        if ! check_azure_login; then
            return 1
        fi
    fi
    
    # Export Azure CLI variables
    export_azure_vars
    
    # Display configuration
    display_configuration
    
    log_success "Environment configuration completed successfully"
    return 0
}

# Function to create .env file from template
create_env_file() {
    if [ -f ".env" ]; then
        log_warn ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    if [ -f ".env.example" ]; then
        cp ".env.example" ".env"
        log_success ".env file created from template"
        log_info "Please edit .env file with your specific configuration values"
    else
        log_error ".env.example template not found"
        return 1
    fi
}

# Only run configuration if script is sourced directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script is being executed directly
    case "${1:-}" in
        "init")
            create_env_file
            ;;
        "validate")
            configure_environment
            ;;
        "show")
            configure_environment true
            ;;
        *)
            echo "Usage: $0 {init|validate|show}"
            echo "  init     - Create .env file from template"
            echo "  validate - Load and validate configuration"
            echo "  show     - Show current configuration without validation"
            ;;
    esac
else
    # Script is being sourced
    configure_environment
fi