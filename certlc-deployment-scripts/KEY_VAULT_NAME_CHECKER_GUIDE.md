# Key Vault Name Checker - Updated for ARM Template Redeployment

## 🎯 Purpose

The `check-keyvault-names.sh` script is specifically designed to solve a common problem when redeploying ARM templates: **Key Vault name conflicts due to soft delete**.

## ❗ The Problem

When you delete a resource group in Azure, the Key Vault is not immediately purged. Instead, it goes into a **soft delete** state for 90 days (by default). During this time:

- The Key Vault name remains **globally reserved**
- ARM template redeployments fail with "Key Vault name already exists" errors
- Even though the resource group is deleted, the Key Vault name is still "taken"

## 🔍 What the Script Does

### 1. **Diagnoses Naming Conflicts**
- Checks if your configured Key Vault name is available
- Identifies if the conflict is due to:
  - An active Key Vault in your subscription
  - A soft-deleted Key Vault (most common cause)
  - A Key Vault in a different subscription/tenant

### 2. **Detects Soft-Deleted Vaults**
- Lists any soft-deleted Key Vaults with the same name
- Shows deletion date and recovery level
- Provides specific commands to resolve the issue

### 3. **Suggests Solutions**
- **Option 1**: Purge the soft-deleted vault permanently
- **Option 2**: Recover the soft-deleted vault
- **Option 3**: Use a different UNIQUE_STRING

### 4. **Finds Alternative Names**
- Generates available Key Vault names using current date/time
- Provides quick alternatives for immediate ARM template deployment
- Allows manual testing of specific names

## 🚀 Usage Scenarios

### Scenario 1: ARM Template Fails After Resource Group Deletion
```bash
# You deleted your resource group and tried to redeploy, but got:
# "The vault name 'DEMO-KV-lab01' is not available"

cd certlc-deployment-scripts
./diagnostics/check-keyvault-names.sh

# The script will:
# 1. Check your configured Key Vault name
# 2. Detect if it's soft-deleted
# 3. Provide exact commands to fix the issue
```

### Scenario 2: Need Alternative Names for Quick Deployment
```bash
# You need to deploy quickly with a different name

./diagnostics/check-keyvault-names.sh

# The script will:
# 1. Show your current name status
# 2. Suggest available alternatives with current date/time
# 3. Provide instructions to update your .env configuration
```

## 🔧 Configuration Integration

The script now uses the centralized configuration system:

- **With .env file**: Automatically loads your Key Vault name from configuration
- **Without .env file**: Falls back to manual input mode
- **Updates configuration**: Provides instructions to update UNIQUE_STRING in .env

## 📋 Example Output

```bash
🔍 Key Vault Name Availability Checker
========================================
Purpose: Diagnose Key Vault naming issues for ARM template redeployment

📋 Loading configuration from .env file...
Resource Group: rg-demo-certlc
Unique String: lab01
Key Vault Name: DEMO-KV-lab01

🔍 Step 1: Checking Key Vault name availability...
Checking: DEMO-KV-lab01

Results:
✓ Name Available: false
✓ Reason: AlreadyExists
✓ Message: The specified name is not available.

❌ PROBLEM: Key Vault name 'DEMO-KV-lab01' is NOT available

🔍 INVESTIGATING THE ISSUE...

🗑️  Checking for SOFT-DELETED Key Vaults (common cause of ARM failures)...

🎯 FOUND THE PROBLEM: Soft-deleted Key Vault(s)!

   Name: DEMO-KV-lab01
   Location: westus3
   Deletion Date: 2025-10-30T18:45:23Z
   Recovery Level: Recoverable+Purgeable

💡 SOLUTION FOR ARM TEMPLATE REDEPLOYMENT:
   The Key Vault is in soft delete state. You have two options:

   Option 1: PURGE the soft-deleted vault (PERMANENT deletion)
   az keyvault purge --name DEMO-KV-lab01
   ⚠️  WARNING: This permanently deletes the vault and all its contents!

   Option 2: RECOVER the soft-deleted vault
   az keyvault recover --name DEMO-KV-lab01
   📝 Note: This restores the vault with all previous contents

   Option 3: Use a different UNIQUE_STRING
   Update your .env file with a new UNIQUE_STRING value

🔍 Step 2: Finding alternative available names...
If you need an alternative name, here are some available options:
Using base name pattern: DEMO-KV

Checking quick alternatives...
✅ DEMO-KV-110111
✅ DEMO-KV-251101
✅ DEMO-KV-v1101
✅ DEMO-KV-new1101

🎉 Found available names above!
💡 To use one of these names:
   1. Pick an available name from the list above
   2. Extract the suffix (e.g., from 'DEMO-KV-110111', use '110111')
   3. Update UNIQUE_STRING in your .env file
   4. Run '../config.sh validate'
   5. Redeploy your ARM template
```

## 🛠️ Commands to Fix Common Issues

### Purge Soft-Deleted Key Vault (Most Common Solution)
```bash
# This permanently removes the soft-deleted vault
az keyvault purge --name YOUR-KEYVAULT-NAME
```

### Recover Soft-Deleted Key Vault
```bash
# This restores the vault with all previous contents
az keyvault recover --name YOUR-KEYVAULT-NAME
```

### Use Different Name
```bash
# Update your configuration with a new unique string
nano .env  # Update UNIQUE_STRING="new-value"
./config.sh validate
```

## ✅ Benefits

1. **Specific Problem Focus**: Addresses the exact ARM template redeployment issue
2. **Clear Diagnostics**: Identifies root cause (soft delete vs. active vault vs. external conflict)
3. **Actionable Solutions**: Provides exact commands to resolve issues
4. **Quick Alternatives**: Suggests immediately available names for fast deployment
5. **Configuration Integration**: Works seamlessly with the centralized config system

This script transforms a confusing Azure error into a clear diagnosis with specific steps to resolve the Key Vault naming conflict and successfully redeploy your ARM template.