#!/bin/bash

# Full Certificate Lifecycle Analysis
# Convenience script for comprehensive monitoring using centralized configuration

set -euo pipefail

echo "🔍 Certificate Lifecycle - Full Analysis"
echo "========================================"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the right directory
if [ ! -d "monitoring" ]; then
    echo "❌ Error: This script must be run from the certlc-deployment-scripts directory"
    exit 1
fi

# Load common configuration
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
    echo "📋 Using centralized configuration:"
    echo "   Resource Group: $RESOURCE_GROUP"
    echo "   Key Vault: $KEY_VAULT_NAME"  
    echo "   Automation Account: $AUTOMATION_ACCOUNT_NAME"
    echo ""
else
    echo "⚠️  Warning: Centralized configuration not found. Using interactive mode."
    echo "💡 To set up configuration: ./config.sh auto-populate --resource-group <your-rg>"
    echo ""
fi

# Run comprehensive analysis with pre-configured values
echo "🔍 Running comprehensive certificate lifecycle analysis..."
if [[ -n "${RESOURCE_GROUP:-}" ]]; then
    # Use centralized configuration - pass values as input to avoid interactive prompts
    echo -e "$RESOURCE_GROUP\n\n\n\n" | ./monitoring/cert-lifecycle-status.sh
else
    # Fall back to interactive mode
    ./monitoring/cert-lifecycle-status.sh
fi

echo ""
echo "🎯 Additional Analysis Options:"
echo "  📊 PowerShell deep dive:  pwsh ./monitoring/cert-lifecycle-events.ps1 -Detailed"
echo "  🔎 Job investigation:     pwsh ./monitoring/investigate-job-output.ps1"  
echo "  🔧 Key Vault diagnostics: ./diagnostics/diagnose-keyvault.sh"
echo "  🔒 Key Vault access fix:  ./diagnostics/fix-keyvault-access.sh"