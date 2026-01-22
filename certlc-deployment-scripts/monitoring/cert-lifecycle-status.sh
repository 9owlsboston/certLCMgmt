#!/bin/bash

# Certificate Lifecycle End-to-End Status Checker
# This script provides comprehensive monitoring of all steps in the certificate lifecycle
# from creation through renewal events, automation jobs, and deployment verification

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Icons
CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"
CLOCK="🕐"
CERT="🔐"
AUTO="🤖"
EVENT="📡"
LOGS="📋"

# Function to print status headers
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check Azure CLI login
check_azure_login() {
    print_header "${INFO} Checking Azure Authentication"
    
    if ! az account show &>/dev/null; then
        echo -e "${CROSS} ${RED}Not logged into Azure. Please run 'az login' first.${NC}"
        exit 1
    fi
    
    local account_info=$(az account show --query '{subscription:name, tenant:tenantId, user:user.name}' -o json)
    echo -e "${CHECK} ${GREEN}Azure Authentication: OK${NC}"
    echo -e "${INFO} Subscription: $(echo $account_info | jq -r '.subscription')"
    echo -e "${INFO} User: $(echo $account_info | jq -r '.user')"
    echo -e "${INFO} Tenant: $(echo $account_info | jq -r '.tenant')"
}

# Function to get user input for certificate to monitor
get_certificate_info() {
    print_header "${CERT} Certificate Information"
    
    # Try to auto-detect from existing deployments
    echo -e "${INFO} Scanning for certificate lifecycle deployments..."
    
    local resource_groups=$(az group list --query "[?contains(name, 'certlc') || contains(name, 'cert') || contains(name, 'demo')].name" -o tsv)
    
    if [ -n "$resource_groups" ]; then
        echo -e "${INFO} Found potential certificate resource groups:"
        echo "$resource_groups" | nl -w2 -s'. '
        echo ""
        read -p "Enter resource group name (or press Enter to scan all): " RESOURCE_GROUP
    else
        read -p "Enter resource group name: " RESOURCE_GROUP
    fi
    
    if [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${WARN} ${YELLOW}No specific resource group provided. Scanning all accessible resource groups...${NC}"
        RESOURCE_GROUP=""
    fi
    
    read -p "Enter certificate name to monitor (or press Enter for auto-detect): " CERTIFICATE_NAME
    if [ -z "$CERTIFICATE_NAME" ]; then
        CERTIFICATE_NAME=""
        echo -e "${INFO} Will auto-detect certificates in the deployment"
    fi
    
    read -p "Enter Key Vault name (or press Enter for auto-detect): " KEY_VAULT_NAME
    if [ -z "$KEY_VAULT_NAME" ]; then
        KEY_VAULT_NAME=""
        echo -e "${INFO} Will auto-detect Key Vault in the deployment"
    fi
    
    read -p "Enter Automation Account name (or press Enter for auto-detect): " AUTOMATION_ACCOUNT
    if [ -z "$AUTOMATION_ACCOUNT" ]; then
        AUTOMATION_ACCOUNT=""
        echo -e "${INFO} Will auto-detect Automation Account in the deployment"
    fi
}

# Function to discover certificate lifecycle resources
discover_resources() {
    print_header "${INFO} Discovering Certificate Lifecycle Resources"
    
    # Discover Key Vaults
    if [ -z "$KEY_VAULT_NAME" ]; then
        echo -e "${INFO} Discovering Key Vaults..."
        if [ -n "$RESOURCE_GROUP" ]; then
            KEY_VAULTS=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || true)
        else
            KEY_VAULTS=$(az keyvault list --query "[].name" -o tsv 2>/dev/null || true)
        fi
        
        if [ -n "$KEY_VAULTS" ]; then
            echo -e "${CHECK} Found Key Vaults:"
            echo "$KEY_VAULTS" | nl -w2 -s'. '
            KEY_VAULT_NAME=$(echo "$KEY_VAULTS" | head -1)
            echo -e "${INFO} Using Key Vault: ${GREEN}$KEY_VAULT_NAME${NC}"
        else
            echo -e "${CROSS} ${RED}No Key Vaults found${NC}"
        fi
    fi
    
    # Discover Automation Accounts
    if [ -z "$AUTOMATION_ACCOUNT" ]; then
        echo -e "${INFO} Discovering Automation Accounts..."
        if [ -n "$RESOURCE_GROUP" ]; then
            AUTOMATION_ACCOUNTS=$(az automation account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || true)
        else
            AUTOMATION_ACCOUNTS=$(az automation account list --query "[].name" -o tsv 2>/dev/null || true)
        fi
        
        if [ -n "$AUTOMATION_ACCOUNTS" ]; then
            echo -e "${CHECK} Found Automation Accounts:"
            echo "$AUTOMATION_ACCOUNTS" | nl -w2 -s'. '
            AUTOMATION_ACCOUNT=$(echo "$AUTOMATION_ACCOUNTS" | head -1)
            echo -e "${INFO} Using Automation Account: ${GREEN}$AUTOMATION_ACCOUNT${NC}"
            
            # Get the resource group for the automation account
            if [ -z "$RESOURCE_GROUP" ]; then
                RESOURCE_GROUP=$(az automation account show --name "$AUTOMATION_ACCOUNT" --query "resourceGroup" -o tsv 2>/dev/null || true)
                echo -e "${INFO} Detected Resource Group: ${GREEN}$RESOURCE_GROUP${NC}"
            fi
        else
            echo -e "${CROSS} ${RED}No Automation Accounts found${NC}"
        fi
    fi
    
    # Discover certificates
    if [ -z "$CERTIFICATE_NAME" ] && [ -n "$KEY_VAULT_NAME" ]; then
        echo -e "${INFO} Discovering certificates in Key Vault..."
        CERTIFICATES=$(az keyvault certificate list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv 2>/dev/null || true)
        
        if [ -n "$CERTIFICATES" ]; then
            echo -e "${CHECK} Found certificates:"
            echo "$CERTIFICATES" | nl -w2 -s'. '
            
            # Look for short-lived or demo certificates first
            DEMO_CERT=$(echo "$CERTIFICATES" | grep -E "(shortlived|demo|test)" | head -1 || true)
            if [ -n "$DEMO_CERT" ]; then
                CERTIFICATE_NAME="$DEMO_CERT"
                echo -e "${INFO} Using certificate: ${GREEN}$CERTIFICATE_NAME${NC} (detected as demo/test cert)"
            else
                CERTIFICATE_NAME=$(echo "$CERTIFICATES" | head -1)
                echo -e "${INFO} Using certificate: ${GREEN}$CERTIFICATE_NAME${NC}"
            fi
        else
            echo -e "${WARN} ${YELLOW}No certificates found in Key Vault${NC}"
        fi
    fi
}

# Function to check certificate status
check_certificate_status() {
    print_header "${CERT} Certificate Status Analysis"
    
    if [ -z "$KEY_VAULT_NAME" ] || [ -z "$CERTIFICATE_NAME" ]; then
        echo -e "${WARN} ${YELLOW}Key Vault or Certificate name not available, skipping certificate checks${NC}"
        return
    fi
    
    echo -e "${INFO} Checking certificate: ${BLUE}$CERTIFICATE_NAME${NC} in Key Vault: ${BLUE}$KEY_VAULT_NAME${NC}"
    
    # Get certificate information
    local cert_info=$(az keyvault certificate show --vault-name "$KEY_VAULT_NAME" --name "$CERTIFICATE_NAME" 2>/dev/null || true)
    
    if [ -z "$cert_info" ]; then
        echo -e "${CROSS} ${RED}Certificate '$CERTIFICATE_NAME' not found in Key Vault '$KEY_VAULT_NAME'${NC}"
        return
    fi
    
    # Parse certificate details
    local created=$(echo "$cert_info" | jq -r '.attributes.created // "N/A"')
    local updated=$(echo "$cert_info" | jq -r '.attributes.updated // "N/A"')
    local expires=$(echo "$cert_info" | jq -r '.attributes.expires // "N/A"')
    local enabled=$(echo "$cert_info" | jq -r '.attributes.enabled // false')
    local subject=$(echo "$cert_info" | jq -r '.policy.x509_certificate_properties.subject // "N/A"')
    local issuer=$(echo "$cert_info" | jq -r '.policy.issuer.name // "N/A"')
    
    echo -e "${INFO} Subject: $subject"
    echo -e "${INFO} Issuer: $issuer"
    echo -e "${INFO} Enabled: $([ "$enabled" = "true" ] && echo "${GREEN}Yes${NC}" || echo "${RED}No${NC}")"
    
    if [ "$created" != "N/A" ]; then
        # Handle both ISO 8601 and Unix timestamp formats
        if [[ "$created" =~ ^[0-9]+$ ]]; then
            # Unix timestamp format
            local created_date=$(date -d "@$created" 2>/dev/null || echo "Invalid date")
        else
            # ISO 8601 format
            local created_date=$(date -d "$created" 2>/dev/null || echo "Invalid date")
        fi
        echo -e "${INFO} Created: $created_date"
    fi
    
    if [ "$updated" != "N/A" ]; then
        # Handle both ISO 8601 and Unix timestamp formats
        if [[ "$updated" =~ ^[0-9]+$ ]]; then
            # Unix timestamp format
            local updated_date=$(date -d "@$updated" 2>/dev/null || echo "Invalid date")
        else
            # ISO 8601 format
            local updated_date=$(date -d "$updated" 2>/dev/null || echo "Invalid date")
        fi
        echo -e "${INFO} Updated: $updated_date"
    fi
    
    if [ "$expires" != "N/A" ]; then
        # Handle both ISO 8601 and Unix timestamp formats
        local expires_date
        local expires_timestamp
        
        if [[ "$expires" =~ ^[0-9]+$ ]]; then
            # Unix timestamp format
            expires_date=$(date -d "@$expires" 2>/dev/null || echo "Invalid date")
            expires_timestamp="$expires"
        else
            # ISO 8601 format
            expires_date=$(date -d "$expires" 2>/dev/null || echo "Invalid date")
            expires_timestamp=$(date -d "$expires" +%s 2>/dev/null || echo "0")
        fi
        
        local current_time=$(date +%s)
        
        echo -e "${INFO} Expires: $expires_date"
        
        # Only do date comparisons if we have valid timestamps
        if [[ "$expires_timestamp" =~ ^[0-9]+$ ]] && [ "$expires_timestamp" -gt 0 ]; then
            if [ "$expires_timestamp" -lt "$current_time" ]; then
                echo -e "${CROSS} ${RED}Certificate is EXPIRED${NC}"
            elif [ $((expires_timestamp - current_time)) -lt 604800 ]; then  # 7 days
                echo -e "${WARN} ${YELLOW}Certificate expires within 7 days${NC}"
            else
                echo -e "${CHECK} ${GREEN}Certificate is valid${NC}"
            fi
        else
            echo -e "${WARN} ${YELLOW}Unable to determine certificate expiration status${NC}"
        fi
    fi
    
    # Check certificate versions
    echo -e "\n${INFO} Certificate versions:"
    local versions=$(az keyvault certificate list-versions --vault-name "$KEY_VAULT_NAME" --name "$CERTIFICATE_NAME" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    echo -e "${INFO} Total versions: $versions"
    
    if [ "$versions" -gt 1 ]; then
        echo -e "${CHECK} ${GREEN}Multiple versions found (certificate has been renewed)${NC}"
        
        # Show recent versions
        az keyvault certificate list-versions --vault-name "$KEY_VAULT_NAME" --name "$CERTIFICATE_NAME" \
            --query "[:3].{Version:id,Created:attributes.created,Expires:attributes.expires}" -o table 2>/dev/null || true
    fi
}

# Function to check automation account and runbooks
check_automation_status() {
    print_header "${AUTO} Automation Account Status"
    
    if [ -z "$AUTOMATION_ACCOUNT" ] || [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${WARN} ${YELLOW}Automation Account or Resource Group not available, skipping automation checks${NC}"
        return
    fi
    
    echo -e "${INFO} Checking Automation Account: ${BLUE}$AUTOMATION_ACCOUNT${NC}"
    
    # Check automation account status
    local aa_info=$(az automation account show --name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" 2>/dev/null || true)
    
    if [ -z "$aa_info" ]; then
        echo -e "${CROSS} ${RED}Automation Account '$AUTOMATION_ACCOUNT' not found${NC}"
        return
    fi
    
    local aa_state=$(echo "$aa_info" | jq -r '.state // "Unknown"')
    echo -e "${INFO} State: $([ "$aa_state" = "Ok" ] && echo "${GREEN}$aa_state${NC}" || echo "${RED}$aa_state${NC}")"
    
    # List runbooks
    echo -e "\n${INFO} Available runbooks:"
    local runbooks=$(az automation runbook list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name,State:state,Type:runbookType}" -o table 2>/dev/null || true)
    
    if [ -n "$runbooks" ]; then
        echo "$runbooks"
    else
        echo -e "${WARN} ${YELLOW}No runbooks found${NC}"
    fi
    
    # Check recent jobs
    echo -e "\n${INFO} Recent automation jobs (last 24 hours):"
    local start_time=$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)
    
    local recent_jobs=$(az automation job list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
        --query "[?startTime>='$start_time'].{JobId:jobId,Status:status,StartTime:startTime,RunbookName:runbookName}" \
        -o json 2>/dev/null || echo "[]")
    
    local job_count=$(echo "$recent_jobs" | jq 'length')
    
    if [ "$job_count" -gt 0 ]; then
        echo -e "${CHECK} Found $job_count jobs in the last 24 hours"
        echo "$recent_jobs" | jq -r '.[] | "\(.StartTime) | \(.Status) | \(.RunbookName) | \(.JobId)"' | \
            awk -F' | ' '{printf "%-20s | %-12s | %-30s | %s\n", $1, $2, $3, $4}' | head -10
        
        # Check for failed jobs
        local failed_jobs=$(echo "$recent_jobs" | jq '[.[] | select(.status == "Failed")]')
        local failed_count=$(echo "$failed_jobs" | jq 'length')
        
        if [ "$failed_count" -gt 0 ]; then
            echo -e "\n${CROSS} ${RED}Found $failed_count failed jobs:${NC}"
            echo "$failed_jobs" | jq -r '.[] | "\(.StartTime) | \(.RunbookName) | \(.JobId)"' | \
                awk -F' | ' '{printf "%-20s | %-30s | %s\n", $1, $2, $3}'
        fi
        
        # Check for certificate-related jobs
        if [ -n "$CERTIFICATE_NAME" ]; then
            echo -e "\n${INFO} Looking for certificate-related jobs..."
            local cert_jobs
            cert_jobs=$(echo "$recent_jobs" | jq --arg cert "$CERTIFICATE_NAME" '[.[] | select(.runbookName != null and (.runbookName | test("cert|renewal|lifecycle"; "i")))]')
            local cert_job_count
            cert_job_count=$(echo "$cert_jobs" | jq 'length' 2>/dev/null || echo "0")
            
            # Ensure cert_job_count is a valid number
            if [[ ! "$cert_job_count" =~ ^[0-9]+$ ]]; then
                cert_job_count=0
            fi
            
            if [ "$cert_job_count" -gt 0 ]; then
                echo -e "${CHECK} Found $cert_job_count certificate-related jobs"
                echo "$cert_jobs" | jq -r '.[] | "\(.startTime // "N/A") | \(.status // "Unknown") | \(.runbookName // "N/A") | \(.jobId // "N/A")"' | \
                    awk -F' | ' '{printf "%-25s | %-12s | %-30s | %s\n", $1, $2, $3, $4}'
            else
                echo -e "${INFO} No specific certificate-related jobs found"
            fi
        fi
    else
        echo -e "${INFO} No jobs found in the last 24 hours"
    fi
}

# Function to check Event Grid events
check_event_grid_status() {
    print_header "${EVENT} Event Grid Status"
    
    if [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${WARN} ${YELLOW}Resource Group not available, skipping Event Grid checks${NC}"
        return
    fi
    
    echo -e "${INFO} Checking Event Grid topics in resource group: ${BLUE}$RESOURCE_GROUP${NC}"
    
    # List Event Grid topics
    local topics=$(az eventgrid topic list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Endpoint:endpoint}" -o json 2>/dev/null || echo "[]")
    local topic_count=$(echo "$topics" | jq 'length')
    
    if [ "$topic_count" -gt 0 ]; then
        echo -e "${CHECK} Found $topic_count Event Grid topics:"
        echo "$topics" | jq -r '.[] | "  - \(.Name)"'
        
        # Check subscriptions for each topic
        echo "$topics" | jq -r '.[] | .Name' | while read -r topic_name; do
            echo -e "\n${INFO} Subscriptions for topic: $topic_name"
            local subscriptions=$(az eventgrid event-subscription list --source-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.EventGrid/topics/$topic_name" \
                --query "[].{Name:name,Destination:destination.endpointType,Filter:filter.subjectBeginsWith}" -o json 2>/dev/null || echo "[]")
            
            local sub_count=$(echo "$subscriptions" | jq 'length')
            if [ "$sub_count" -gt 0 ]; then
                echo "$subscriptions" | jq -r '.[] | "    \(.Name) -> \(.Destination) (Filter: \(.Filter // "None"))"'
            else
                echo -e "    ${WARN} No subscriptions found"
            fi
        done
    else
        echo -e "${INFO} No Event Grid topics found in resource group"
        
        # Check for system topics (Key Vault events)
        echo -e "\n${INFO} Checking for system topics..."
        local system_topics=$(az eventgrid system-topic list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Source:source,TopicType:topicType}" -o json 2>/dev/null || echo "[]")
        local sys_topic_count=$(echo "$system_topics" | jq 'length')
        
        if [ "$sys_topic_count" -gt 0 ]; then
            echo -e "${CHECK} Found $sys_topic_count system topics:"
            echo "$system_topics" | jq -r '.[] | "  - \(.Name) (\(.TopicType))"'
        fi
    fi
}

# Function to check deployment status
check_deployment_status() {
    print_header "${LOGS} Deployment Status"
    
    if [ -z "$RESOURCE_GROUP" ]; then
        echo -e "${WARN} ${YELLOW}Resource Group not available, skipping deployment checks${NC}"
        return
    fi
    
    echo -e "${INFO} Checking recent deployments in resource group: ${BLUE}$RESOURCE_GROUP${NC}"
    
    # List recent deployments
    local deployments=$(az deployment group list --resource-group "$RESOURCE_GROUP" \
        --query "[:5].{Name:name,State:properties.provisioningState,Timestamp:properties.timestamp,Duration:properties.duration}" \
        -o json 2>/dev/null || echo "[]")
    
    local deployment_count=$(echo "$deployments" | jq 'length')
    
    if [ "$deployment_count" -gt 0 ]; then
        echo -e "${CHECK} Found $deployment_count recent deployments:"
        echo "$deployments" | jq -r '.[] | "\(.Timestamp) | \(.State) | \(.Name) | \(.Duration // "N/A")"' | \
            awk -F' | ' '{printf "%-20s | %-12s | %-40s | %s\n", $1, $2, $3, $4}'
        
        # Check for failed deployments
        local failed_deployments=$(echo "$deployments" | jq '[.[] | select(.State == "Failed")]')
        local failed_count=$(echo "$failed_deployments" | jq 'length')
        
        if [ "$failed_count" -gt 0 ]; then
            echo -e "\n${CROSS} ${RED}Found $failed_count failed deployments${NC}"
            
            # Get error details for failed deployments
            echo "$failed_deployments" | jq -r '.[] | .Name' | head -3 | while read -r deployment_name; do
                echo -e "\n${INFO} Error details for: $deployment_name"
                az deployment group show --resource-group "$RESOURCE_GROUP" --name "$deployment_name" \
                    --query "properties.error.{Code:code,Message:message}" -o json 2>/dev/null | \
                    jq -r '"Code: \(.Code // "N/A")\nMessage: \(.Message // "No details available")"' || echo "Could not retrieve error details"
            done
        fi
    else
        echo -e "${INFO} No recent deployments found"
    fi
    
    # Check resource status
    echo -e "\n${INFO} Resource status in resource group:"
    local resources=$(az resource list --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name,Type:type,Location:location}" -o json 2>/dev/null || echo "[]")
    
    local resource_count=$(echo "$resources" | jq 'length')
    echo -e "${INFO} Total resources: $resource_count"
    
    if [ "$resource_count" -gt 0 ]; then
        # Group by resource type
        echo "$resources" | jq -r 'group_by(.Type)[] | "\(.[0].Type): \(length) resources"' | sort
    fi
}

# Function to generate summary report
generate_summary() {
    print_header "${LOGS} Certificate Lifecycle Status Summary"
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${INFO} Report generated: $current_time"
    echo ""
    
    echo -e "${CYAN}📊 Configuration Summary:${NC}"
    echo -e "   Resource Group: ${BLUE}${RESOURCE_GROUP:-"Not specified"}${NC}"
    echo -e "   Key Vault: ${BLUE}${KEY_VAULT_NAME:-"Not found"}${NC}"
    echo -e "   Certificate: ${BLUE}${CERTIFICATE_NAME:-"Not specified"}${NC}"
    echo -e "   Automation Account: ${BLUE}${AUTOMATION_ACCOUNT:-"Not found"}${NC}"
    echo ""
    
    echo -e "${CYAN}🎯 Quick Actions:${NC}"
    echo -e "   1. View certificate in Azure Portal:"
    if [ -n "$KEY_VAULT_NAME" ] && [ -n "$CERTIFICATE_NAME" ]; then
        echo -e "      ${BLUE}https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}/certificates${NC}"
    fi
    
    echo -e "   2. View automation jobs:"
    if [ -n "$AUTOMATION_ACCOUNT" ] && [ -n "$RESOURCE_GROUP" ]; then
        echo -e "      ${BLUE}https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Automation/automationAccounts/${AUTOMATION_ACCOUNT}/jobs${NC}"
    fi
    
    echo -e "   3. Run detailed job investigation:"
    echo -e "      ${BLUE}pwsh ./investigate-job-output.ps1 -ResourceGroupName \"$RESOURCE_GROUP\" -AutomationAccountName \"$AUTOMATION_ACCOUNT\" -CertificateName \"$CERTIFICATE_NAME\"${NC}"
    
    echo ""
    echo -e "${CYAN}📁 Related Scripts:${NC}"
    echo -e "   • ${BLUE}./diagnose-keyvault.sh${NC} - Key Vault diagnostics"
    echo -e "   • ${BLUE}./check-deployment-status.sh${NC} - Deployment verification"
    echo -e "   • ${BLUE}./investigate-job-output.ps1${NC} - Job analysis (PowerShell)"
}

# Main execution
main() {
    echo -e "${GREEN}🔐 Certificate Lifecycle End-to-End Status Checker${NC}"
    echo -e "${GREEN}===================================================${NC}"
    echo -e "${INFO} This script provides comprehensive monitoring of certificate lifecycle automation"
    echo ""
    
    # Check prerequisites
    if ! command -v az &> /dev/null; then
        echo -e "${CROSS} ${RED}Azure CLI is not installed or not in PATH${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${CROSS} ${RED}jq is not installed. Please install jq for JSON parsing${NC}"
        exit 1
    fi
    
    # Execute checks
    check_azure_login
    get_certificate_info
    discover_resources
    check_certificate_status
    check_automation_status
    check_event_grid_status
    check_deployment_status
    generate_summary
    
    echo -e "\n${CHECK} ${GREEN}Certificate lifecycle status check completed${NC}"
}

# Handle script interruption
trap 'echo -e "\n${WARN} Script interrupted by user"; exit 1' INT

# Run main function
main "$@"