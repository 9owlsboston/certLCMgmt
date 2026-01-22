# Configuration Management System

This directory now includes a centralized configuration management system that eliminates hard-coded variables from shell scripts and provides auto-discovery of deployed resources.

## 🚀 Quick Start

### 1. Auto-populate from existing deployment
If you already have a LAB environment deployed:

```bash
# Auto-detect and populate configuration from your deployed resources
./config.sh auto-populate --resource-group rg-your-lab-name

# Validate the configuration
./config.sh validate

# View the current configuration
./config.sh show
```

### 2. Manual configuration
If you want to set up manually:

```bash
# Create .env file from template
./config.sh init

# Edit the .env file with your values
nano .env

# Validate the configuration
./config.sh validate
```

## 📋 Configuration Manager Commands

The `config.sh` script provides these commands:

- **`init`** - Create `.env` file from template
- **`auto-populate --resource-group <name>`** - Auto-populate from deployed resources
- **`validate`** - Validate current configuration
- **`show`** - Display current configuration
- **`reset`** - Reset `.env` file to template

## 🔧 How It Works

### Before (Hard-coded variables)
```bash
# Old way - each script had these hard-coded
RESOURCE_GROUP="rg-demo-certlc"  # UPDATE THIS
UNIQUE_STRING="certlc"           # UPDATE THIS
LOCATION="westus3"               # UPDATE THIS
```

### After (Centralized configuration)
```bash
# New way - scripts load from .env file
source "$SCRIPT_DIR/../common.sh"  # Loads configuration automatically
```

### Auto-Discovery Process

When you run `./config.sh auto-populate --resource-group <rg-name>`, the script:

1. **Detects the resource group** and validates it exists
2. **Extracts the unique string** by analyzing deployed resource names:
   - Looks for Key Vault names matching `DEMO-KV-*` or `kv-certlc-*`
   - Falls back to Storage Account names matching `demosa*` or `sacertlc*`
3. **Discovers actual resource names** from the deployment
4. **Generates a complete `.env` file** with all detected values

## 📁 File Structure

```
certlc-deployment-scripts/
├── .env.template          # Template for configuration values
├── .env                   # Your actual configuration (created by config.sh)
├── config.sh              # Configuration manager script
├── common.sh              # Common configuration loader for scripts
└── */                     # All subdirectory scripts now use common.sh
```

## 🔍 Configuration Variables

### Core Settings
- `RESOURCE_GROUP` - Your Azure resource group name
- `SUBSCRIPTION_ID` - Azure subscription ID (auto-detected)
- `LOCATION` - Azure region (auto-detected from resource group)
- `UNIQUE_STRING` - Unique identifier used in resource names

### Resource Names (Auto-calculated)
- `KEY_VAULT_NAME` - Key Vault name
- `STORAGE_ACCOUNT_NAME` - Storage account name
- `AUTOMATION_ACCOUNT_NAME` - Automation account name
- `FUNCTION_APP_NAME` - Function app name
- `LOG_ANALYTICS_WORKSPACE_NAME` - Log Analytics workspace name

### Manual Settings
- `RECIPIENT_EMAIL` - Email for notifications
- `DOMAIN_ADMIN_PASSWORD` - Domain admin password (for lab deployments)
- `CA_ADMIN_PASSWORD` - CA admin password (for lab deployments)

## 🛡️ Updated Scripts

The following scripts have been updated to use the new configuration system:

- ✅ `diagnostics/diagnose-keyvault.sh`
- ✅ `deployment/deploy.sh`
- ✅ `deployment/deploy-keyvault-only.sh`
- 🔄 Additional scripts will be updated as needed

## 📖 Example Usage

### Complete workflow for existing deployment:
```bash
cd certlc-deployment-scripts

# Auto-populate from your LAB deployment
./config.sh auto-populate --resource-group rg-certlc-lab-12345

# Review the generated configuration
./config.sh show

# Update email address (edit manually)
nano .env

# Validate everything is correct
./config.sh validate

# Now run any script - it will use your configuration
./diagnostics/diagnose-keyvault.sh
```

### Manual setup workflow:
```bash
cd certlc-deployment-scripts

# Create new configuration
./config.sh init

# Edit with your values
nano .env

# Set required values:
# RESOURCE_GROUP="rg-your-lab"
# UNIQUE_STRING="your-unique-id"
# LOCATION="westus3"
# RECIPIENT_EMAIL="you@domain.com"

# Validate
./config.sh validate

# Use the configuration
./deployment/deploy-keyvault-only.sh
```

## 🔧 Troubleshooting

### Configuration not found
```bash
ERROR: .env configuration file not found
Please run: ./config.sh init
```
**Solution:** Run `./config.sh init` or `./config.sh auto-populate --resource-group <name>`

### Auto-detection failed
```bash
Warning: Could not auto-detect unique string from resources
```
**Solution:** The script couldn't find resources with expected naming patterns. Edit `.env` manually to set `UNIQUE_STRING`.

### Validation errors
```bash
Error: RESOURCE_GROUP is not set
```
**Solution:** Edit `.env` file and set the missing required variables.

## 🎯 Benefits

1. **No more hard-coded variables** - All configuration centralized
2. **Auto-discovery** - Reads from existing deployments
3. **Validation** - Ensures configuration is complete and valid
4. **Consistency** - All scripts use the same configuration
5. **Easy maintenance** - Update once, applies everywhere
6. **Error prevention** - Validation catches missing values early

This system makes it much easier to work with the certificate lifecycle scripts and eliminates the need to manually edit variables in multiple files.