#!/bin/bash

# Certificate Lifecycle Management - Common Configuration Loader
# Source this file in your scripts to load configuration

# Get script directory
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

# Look for .env file in current directory or parent directories
find_env_file() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.env" ]; then
            echo "$dir/.env"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

ENV_FILE=""
if [ -f "$SCRIPT_DIR/.env" ]; then
    ENV_FILE="$SCRIPT_DIR/.env"
elif [ -f "$SCRIPT_DIR/../.env" ]; then
    ENV_FILE="$SCRIPT_DIR/../.env"
else
    ENV_FILE=$(find_env_file "$SCRIPT_DIR")
fi

if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED:-}ERROR: .env configuration file not found${NC:-}"
    echo "Please run: ./config.sh init"
    echo "Or: ./config.sh auto-populate --resource-group <your-resource-group>"
    exit 1
fi

# Load the environment file
# shellcheck source=/dev/null
source "$ENV_FILE"

# Auto-calculate derived resource names if not set
if [ -n "$UNIQUE_STRING" ] && [ "$UNIQUE_STRING" != "<auto-detect-failed>" ]; then
    # Set defaults for commonly used naming patterns
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-DEMO-KV-${UNIQUE_STRING}}"
    EVENT_GRID_NAME="${EVENT_GRID_NAME:-DEMO-EG-${UNIQUE_STRING}}"
    STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-demosa${UNIQUE_STRING}}"
    AUTOMATION_ACCOUNT_NAME="${AUTOMATION_ACCOUNT_NAME:-DEMO-AA-${UNIQUE_STRING}}"
    FUNCTION_APP_NAME="${FUNCTION_APP_NAME:-func-certlc-${UNIQUE_STRING}}"
    APP_SERVICE_PLAN_NAME="${APP_SERVICE_PLAN_NAME:-ASP-${UNIQUE_STRING}}"
    LOG_ANALYTICS_WORKSPACE_NAME="${LOG_ANALYTICS_WORKSPACE_NAME:-law-certlc-${UNIQUE_STRING}}"
fi

# Set default deployment name with timestamp
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-certlc-deployment-$(date +%Y%m%d-%H%M%S)}"

# Validate critical variables
validate_config() {
    local errors=0
    
    if [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${RED:-}ERROR: RESOURCE_GROUP is not set in .env file${NC:-}"
        errors=$((errors + 1))
    fi
    
    if [ -z "$LOCATION" ]; then
        echo -e "${RED:-}ERROR: LOCATION is not set in .env file${NC:-}"
        errors=$((errors + 1))
    fi
    
    if [ -z "$UNIQUE_STRING" ] || [ "$UNIQUE_STRING" = "<auto-detect-failed>" ]; then
        echo -e "${RED:-}ERROR: UNIQUE_STRING is not properly set in .env file${NC:-}"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo "Please run: ./config.sh validate"
        exit 1
    fi
}

# Function to display current configuration
show_config_summary() {
    echo -e "${BLUE:-}Configuration Summary:${NC:-}"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo "Unique String: $UNIQUE_STRING"
    echo "Key Vault: $KEY_VAULT_NAME"
    echo "Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
    echo ""
}

# Auto-validate if VALIDATE_CONFIG is set
if [ "${VALIDATE_CONFIG:-true}" = "true" ]; then
    validate_config
fi

# Export commonly used variables
export RESOURCE_GROUP
export LOCATION
export UNIQUE_STRING
export KEY_VAULT_NAME
export EVENT_GRID_NAME
export STORAGE_ACCOUNT_NAME
export AUTOMATION_ACCOUNT_NAME
export FUNCTION_APP_NAME
export APP_SERVICE_PLAN_NAME
export LOG_ANALYTICS_WORKSPACE_NAME
export DEPLOYMENT_NAME
export RECIPIENT_EMAIL
export TENANT_ID
export SUBSCRIPTION_ID