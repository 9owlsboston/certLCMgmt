# Environment Variable Management in Bash Scripts

## Standard Approaches for Environment Variables

### 1. **`.env` Files (Recommended)**

The `.env` file approach is widely adopted and considered best practice for configuration management.

#### Format:
```bash
# .env file format
VARIABLE_NAME=value
ANOTHER_VARIABLE="value with spaces"
NUMERIC_VARIABLE=123
BOOLEAN_VARIABLE=true

# Comments are supported
# Empty lines are ignored

# No spaces around the equals sign
CORRECT_FORMAT=value
# INCORRECT_FORMAT = value  # This would fail
```

#### Loading Methods:

**Method 1: Simple Source (Most Common)**
```bash
#!/bin/bash
if [ -f .env ]; then
    source .env
    # Alternative: . .env
fi
```

**Method 2: Export All Variables**
```bash
#!/bin/bash
if [ -f .env ]; then
    set -a  # Automatically export all variables
    source .env
    set +a  # Disable auto-export
fi
```

**Method 3: Secure Loading with Validation**
```bash
#!/bin/bash
load_env() {
    local env_file="${1:-.env}"
    
    if [ ! -f "$env_file" ]; then
        echo "Environment file not found: $env_file"
        return 1
    fi
    
    # Process each line
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
        
        # Validate variable name
        if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            export "$key"="$value"
        else
            echo "Invalid variable name: $key"
        fi
    done < "$env_file"
}
```

### 2. **Configuration Hierarchy (Best Practice)**

Use a priority system: **Command Line → Environment → .env → Defaults**

```bash
#!/bin/bash

# Set defaults first
DEFAULT_TIMEOUT=30
DEFAULT_RETRIES=3

# Load .env file if it exists
[ -f .env ] && source .env

# Use environment variables with fallback to defaults
TIMEOUT="${TIMEOUT:-$DEFAULT_TIMEOUT}"
RETRIES="${RETRIES:-$DEFAULT_RETRIES}"
API_URL="${API_URL:-https://api.example.com}"

# Command line arguments override everything
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --retries)
            RETRIES="$2"
            shift 2
            ;;
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Export for use by other scripts
export TIMEOUT RETRIES API_URL
```

### 3. **Multiple Environment Support**

```bash
#!/bin/bash

# Environment-specific configuration
ENVIRONMENT="${ENVIRONMENT:-development}"

# Load base configuration
[ -f .env ] && source .env

# Load environment-specific overrides
[ -f ".env.${ENVIRONMENT}" ] && source ".env.${ENVIRONMENT}"

# Load local overrides (git-ignored)
[ -f .env.local ] && source .env.local

echo "Running in $ENVIRONMENT environment"
```

### 4. **Validation and Required Variables**

```bash
#!/bin/bash

# Function to check required variables
check_required_vars() {
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "ERROR: Missing required environment variables:"
        printf '  %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please set these variables in your .env file or environment."
        return 1
    fi
}

# Define required variables
REQUIRED_VARS=(
    "API_KEY"
    "DATABASE_URL"
    "SERVICE_NAME"
)

# Load configuration
source .env

# Validate
check_required_vars "${REQUIRED_VARS[@]}"
```

## Advanced Patterns

### 1. **Secure Configuration Loading**

```bash
#!/bin/bash

# Function to securely load configuration
secure_load_config() {
    local config_file="$1"
    local temp_file
    
    # Create temporary file with restricted permissions
    temp_file=$(mktemp)
    chmod 600 "$temp_file"
    
    # Process configuration file
    if [ -f "$config_file" ]; then
        # Remove comments and empty lines, validate format
        grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$config_file" > "$temp_file"
        
        # Source the cleaned file
        source "$temp_file"
        
        # Clean up
        rm -f "$temp_file"
        
        echo "Configuration loaded from: $config_file"
    else
        rm -f "$temp_file"
        echo "Configuration file not found: $config_file"
        return 1
    fi
}
```

### 2. **Configuration with Type Validation**

```bash
#!/bin/bash

# Function to validate and convert variable types
validate_config() {
    # Validate boolean values
    validate_boolean() {
        local var_name="$1"
        local var_value="${!var_name}"
        
        case "${var_value,,}" in  # Convert to lowercase
            true|yes|1|on)
                export "$var_name"=true
                ;;
            false|no|0|off|"")
                export "$var_name"=false
                ;;
            *)
                echo "ERROR: $var_name must be boolean (true/false), got: $var_value"
                return 1
                ;;
        esac
    }
    
    # Validate numeric values
    validate_numeric() {
        local var_name="$1"
        local var_value="${!var_name}"
        local min_value="${2:-0}"
        local max_value="${3:-}"
        
        if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
            echo "ERROR: $var_name must be numeric, got: $var_value"
            return 1
        fi
        
        if [ "$var_value" -lt "$min_value" ]; then
            echo "ERROR: $var_name must be >= $min_value, got: $var_value"
            return 1
        fi
        
        if [ -n "$max_value" ] && [ "$var_value" -gt "$max_value" ]; then
            echo "ERROR: $var_name must be <= $max_value, got: $var_value"
            return 1
        fi
    }
    
    # Validate URL format
    validate_url() {
        local var_name="$1"
        local var_value="${!var_name}"
        
        if [[ ! "$var_value" =~ ^https?:// ]]; then
            echo "ERROR: $var_name must be a valid URL, got: $var_value"
            return 1
        fi
    }
    
    # Example validations
    validate_boolean ENABLE_SSL
    validate_numeric TIMEOUT 1 300
    validate_numeric RETRIES 1 10
    validate_url API_URL
}
```

### 3. **Configuration Templates and Initialization**

```bash
#!/bin/bash

# Function to initialize configuration from template
init_config() {
    local template_file=".env.template"
    local config_file=".env"
    
    if [ ! -f "$template_file" ]; then
        echo "ERROR: Template file $template_file not found"
        return 1
    fi
    
    if [ -f "$config_file" ]; then
        read -p "Configuration file exists. Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Copy template and prompt for values
    cp "$template_file" "$config_file"
    
    echo "Configuration initialized. Please edit $config_file with your values."
    
    # Optionally open in editor
    if command -v ${EDITOR:-nano} &> /dev/null; then
        ${EDITOR:-nano} "$config_file"
    fi
}
```

## File Organization Best Practices

### Recommended File Structure:
```
project/
├── .env.example          # Template file (committed to git)
├── .env                  # Main configuration (git-ignored)
├── .env.local           # Local overrides (git-ignored)
├── .env.development     # Development settings (git-ignored)
├── .env.staging         # Staging settings (git-ignored)
├── .env.production      # Production settings (git-ignored)
├── config/
│   ├── config.sh        # Configuration loader script
│   └── defaults.sh      # Default values
└── scripts/
    ├── deploy.sh        # Uses configuration
    └── setup.sh         # Uses configuration
```

### Git Configuration:
```gitignore
# .gitignore
.env
.env.local
.env.*.local
.env.development
.env.staging
.env.production

# Keep template files
!.env.example
!.env.template
```

## Security Considerations

### 1. **Sensitive Data Handling**
```bash
#!/bin/bash

# Never log sensitive variables
safe_echo() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    # List of sensitive variable patterns
    local sensitive_patterns=(
        "*PASSWORD*"
        "*SECRET*"
        "*KEY*"
        "*TOKEN*"
        "*CREDENTIAL*"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        if [[ "$var_name" == $pattern ]]; then
            echo "$var_name=***HIDDEN***"
            return
        fi
    done
    
    echo "$var_name=$var_value"
}
```

### 2. **File Permissions**
```bash
#!/bin/bash

# Set secure permissions on configuration files
secure_config_files() {
    local config_files=(.env .env.local .env.production)
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            chmod 600 "$file"  # Read/write for owner only
            echo "Secured permissions for: $file"
        fi
    done
}
```

### 3. **Environment Validation**
```bash
#!/bin/bash

# Validate environment before running sensitive operations
validate_environment() {
    local current_env="${ENVIRONMENT:-development}"
    
    case "$current_env" in
        production)
            echo "WARNING: Running in PRODUCTION environment"
            read -p "Are you sure you want to continue? (type 'yes'): " -r
            if [ "$REPLY" != "yes" ]; then
                echo "Operation cancelled"
                exit 1
            fi
            ;;
        staging)
            echo "Running in STAGING environment"
            ;;
        development)
            echo "Running in DEVELOPMENT environment"
            ;;
        *)
            echo "ERROR: Unknown environment: $current_env"
            exit 1
            ;;
    esac
}
```

## Azure CLI Scripts Integration

For Azure CLI scripts specifically, use this pattern:

```bash
#!/bin/bash

# Load Azure-specific configuration
source "$(dirname "$0")/config.sh"

# Azure CLI specific validations
validate_azure_config() {
    # Check Azure CLI installation
    if ! command -v az &> /dev/null; then
        echo "ERROR: Azure CLI not installed"
        return 1
    fi
    
    # Check login status
    if ! az account show &> /dev/null; then
        echo "ERROR: Not logged in to Azure CLI"
        return 1
    fi
    
    # Validate subscription
    if ! az account show --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
        echo "ERROR: Cannot access subscription: $SUBSCRIPTION_ID"
        return 1
    fi
    
    # Set subscription
    az account set --subscription "$SUBSCRIPTION_ID"
}

# Run validation
validate_azure_config

# Your Azure script logic here...
```

This approach provides:
- ✅ Standardized configuration management
- ✅ Environment-specific settings
- ✅ Validation and error handling
- ✅ Security best practices
- ✅ Easy maintenance and updates
- ✅ Integration with existing tools