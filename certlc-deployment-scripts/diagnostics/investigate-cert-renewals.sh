#!/bin/bash

# Certificate Renewal Analysis Script
# Investigates excessive certificate renewals and automation job failures

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

echo -e "${CYAN}🔍 Certificate Renewal Investigation${NC}"
echo "========================================"
echo ""

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Key Vault: $KEY_VAULT_NAME"
echo "  Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo ""

# 1. Analyze certificate versions and timing
echo -e "${CYAN}📜 Certificate Version Analysis${NC}"
echo "----------------------------------------"

echo "🔍 Getting certificate version count..."
CERT_COUNT=$(az keyvault certificate list-versions --vault-name "$KEY_VAULT_NAME" --name "democert" --query "length(@)" -o tsv 2>/dev/null || echo "0")
echo "  Total versions: $CERT_COUNT"

if [ "$CERT_COUNT" -gt 10 ]; then
    echo -e "${YELLOW}⚠️  WARNING: Excessive certificate versions detected!${NC}"
    echo ""
    
    echo "🕒 Recent certificate creation timeline (last 20 versions):"
    az keyvault certificate list-versions --vault-name "$KEY_VAULT_NAME" --name "democert" \
        --query "[0:20].{created:attributes.created, expires:attributes.expires}" -o table
    
    echo ""
    echo "⏰ Time gaps between certificate creations:"
    az keyvault certificate list-versions --vault-name "$KEY_VAULT_NAME" --name "democert" \
        --query "[0:10].attributes.created" -o tsv | \
        while IFS= read -r timestamp; do
            if [ -n "$timestamp" ]; then
                readable_time=$(date -d "$timestamp" '+%Y-%m-%d %H:%M:%S')
                echo "  $readable_time"
            fi
        done
fi

echo ""

# 2. Analyze automation schedules
echo -e "${CYAN}🤖 Automation Schedule Analysis${NC}"
echo "----------------------------------------"

echo "📅 Current automation schedules:"
az automation schedule list --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" \
    --query "[].{Name:name, Frequency:frequency, Interval:interval, Enabled:isEnabled, NextRun:nextRun}" -o table

echo ""

# 3. Analyze recent job failures
echo -e "${CYAN}❌ Job Failure Analysis${NC}"
echo "----------------------------------------"

echo "🔍 Recent job status summary:"
JOB_DATA=$(az automation job list --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --output json 2>/dev/null || echo "[]")

TOTAL_JOBS=$(echo "$JOB_DATA" | jq 'length')
FAILED_JOBS=$(echo "$JOB_DATA" | jq '[.[] | select(.status == "Failed")] | length')
COMPLETED_JOBS=$(echo "$JOB_DATA" | jq '[.[] | select(.status == "Completed")] | length')
SUSPENDED_JOBS=$(echo "$JOB_DATA" | jq '[.[] | select(.status == "Suspended")] | length')

echo "  Total jobs: $TOTAL_JOBS"
echo "  Failed jobs: $FAILED_JOBS"
echo "  Completed jobs: $COMPLETED_JOBS"
echo "  Suspended jobs: $SUSPENDED_JOBS"

if [ "$FAILED_JOBS" -gt 0 ]; then
    echo -e "${RED}🚨 High failure rate detected!${NC}"
    echo ""
    
    echo "⏰ Failed job timeline (last 10):"
    echo "$JOB_DATA" | jq -r '[.[] | select(.status == "Failed")][0:10] | .[] | "\(.startTime // "N/A") | \(.status) | \(.jobId)"' | \
        awk -F' | ' '{printf "  %-25s | %-10s | %s\n", $1, $2, $3}'
fi

echo ""

# 4. Certificate policy analysis
echo -e "${CYAN}📜 Certificate Policy Analysis${NC}"
echo "----------------------------------------"

echo "🔍 Certificate policy settings:"
CERT_POLICY=$(az keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "democert" --query "policy" -o json 2>/dev/null || echo "{}")

if [ "$CERT_POLICY" != "{}" ]; then
    echo "  Lifetime Actions:"
    echo "$CERT_POLICY" | jq -r '.lifetimeActions[]? | "    \(.action.actionType): \(.trigger.lifetimePercentage // .trigger.daysBeforeExpiry)% / \(.trigger.daysBeforeExpiry // "N/A") days"'
    
    echo ""
    echo "  Certificate Validity:"
    echo "    Validity: $(echo "$CERT_POLICY" | jq -r '.x509CertificateProperties.validityInMonths // "N/A"') months"
    
    echo ""
    echo "  Auto-renewal settings:"
    echo "$CERT_POLICY" | jq -r '.lifetimeActions[]? | select(.action.actionType == "AutoRenew") | "    Auto-renew triggered at: \(.trigger.lifetimePercentage // .trigger.daysBeforeExpiry)% of lifetime or \(.trigger.daysBeforeExpiry // "N/A") days before expiry"'
else
    echo -e "${YELLOW}⚠️  Could not retrieve certificate policy${NC}"
fi

echo ""

# 5. Recommendations
echo -e "${CYAN}💡 Analysis Summary & Recommendations${NC}"
echo "============================================"

echo -e "${YELLOW}🔍 FINDINGS:${NC}"

if [ "$CERT_COUNT" -gt 20 ]; then
    echo -e "${RED}  🚨 CRITICAL: Excessive certificate renewals ($CERT_COUNT versions)${NC}"
    echo "     This indicates a runaway renewal process"
fi

if [ "$FAILED_JOBS" -gt 5 ]; then
    echo -e "${RED}  🚨 CRITICAL: High job failure rate ($FAILED_JOBS failed jobs)${NC}"
    echo "     Failed jobs may be triggering retry mechanisms"
fi

echo ""
echo -e "${GREEN}🛠️  RECOMMENDATIONS:${NC}"

echo "  1. 🔄 Temporarily disable automation schedules:"
echo "     az automation schedule update --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP' --name 'injestData_hourly' --is-enabled false"
echo "     az automation schedule update --automation-account-name '$AUTOMATION_ACCOUNT_NAME' --resource-group '$RESOURCE_GROUP' --name 'Check CertLC Queue' --is-enabled false"

echo ""
echo "  2. 🔍 Investigate job failures:"
echo "     pwsh ./investigate-job-output.ps1 -ResourceGroupName '$RESOURCE_GROUP' -AutomationAccountName '$AUTOMATION_ACCOUNT_NAME'"

echo ""
echo "  3. 📜 Review certificate policy:"
echo "     Check if auto-renewal is triggered too aggressively (currently set to renew at a high frequency)"

echo ""
echo "  4. 🧹 Clean up old certificate versions (optional):"
echo "     Consider disabling old certificate versions to reduce clutter"

echo ""
echo "  5. ⚙️  Adjust schedule frequency:"
echo "     Change hourly schedule to daily or reduce frequency once issues are resolved"

echo ""
echo -e "${BLUE}📊 Quick Status Check:${NC}"
echo "  Current certificate expires: $(az keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "democert" --query "attributes.expires" -o tsv)"
echo "  Next scheduled run: $(az automation schedule show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --name "injestData_hourly" --query "nextRun" -o tsv)"

echo ""
echo "✅ Investigation completed!"