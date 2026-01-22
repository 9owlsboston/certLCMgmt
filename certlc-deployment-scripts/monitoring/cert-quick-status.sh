#!/bin/bash

# Certificate Lifecycle Quick Status
# A fast overview script that provides the most important status information

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🔐 Certificate Lifecycle Quick Status${NC}"
echo "======================================="

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    exit 1
fi

if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Not logged into Azure${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Auto-discover main resource group
echo -e "\n${YELLOW}🔍 Auto-discovering resources...${NC}"

# Find certificate lifecycle resource groups
RG=$(az group list --query "[?contains(name, 'certlc') || contains(name, 'cert-') || contains(name, 'demo')].name" -o tsv | head -1)

if [ -z "$RG" ]; then
    echo -e "${YELLOW}⚠️ No obvious certificate resource groups found${NC}"
    echo "Available resource groups:"
    az group list --query "[].name" -o tsv | head -5
    exit 0
fi

echo -e "${BLUE}📁 Using Resource Group: $RG${NC}"

# Quick resource count
RESOURCE_COUNT=$(az resource list --resource-group "$RG" --query "length(@)" -o tsv 2>/dev/null || echo "0")
echo -e "${BLUE}📊 Resources in group: $RESOURCE_COUNT${NC}"

# Find Key Vault
KV=$(az keyvault list --resource-group "$RG" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$KV" ]; then
    echo -e "${BLUE}🔑 Key Vault: $KV${NC}"
    
    # Count certificates
    CERT_COUNT=$(az keyvault certificate list --vault-name "$KV" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    echo -e "${BLUE}📜 Certificates: $CERT_COUNT${NC}"
    
    # Find demo/test certificates
    DEMO_CERT=$(az keyvault certificate list --vault-name "$KV" --query "[?contains(name, 'demo') || contains(name, 'test') || contains(name, 'shortlived')].name" -o tsv | head -1 2>/dev/null || echo "")
    if [ -n "$DEMO_CERT" ]; then
        echo -e "${BLUE}🧪 Demo certificate: $DEMO_CERT${NC}"
        
        # Check expiration
        EXPIRES=$(az keyvault certificate show --vault-name "$KV" --name "$DEMO_CERT" --query "attributes.expires" -o tsv 2>/dev/null || echo "")
        if [ -n "$EXPIRES" ]; then
            CURRENT_TIME=$(date +%s)
            # Convert ISO date to Unix timestamp
            EXPIRES_TIMESTAMP=$(date -d "$EXPIRES" +%s 2>/dev/null || echo "0")
            if [ "$EXPIRES_TIMESTAMP" -lt "$CURRENT_TIME" ]; then
                echo -e "${RED}⏰ Status: EXPIRED${NC}"
            else
                echo -e "${GREEN}⏰ Status: Valid${NC}"
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠️ No Key Vault found${NC}"
fi

# Find Automation Account
AA=$(az automation account list --resource-group "$RG" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$AA" ]; then
    echo -e "${BLUE}🤖 Automation Account: $AA${NC}"
    
    # Check recent jobs (last 24 hours)
    START_TIME=$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)
    JOB_COUNT=$(az automation job list --automation-account-name "$AA" --resource-group "$RG" \
        --query "[?startTime>='$START_TIME'] | length(@)" -o tsv 2>/dev/null || echo "0")
    echo -e "${BLUE}🕐 Recent jobs (24h): $JOB_COUNT${NC}"
    
    # Check for failed jobs
    FAILED_COUNT=$(az automation job list --automation-account-name "$AA" --resource-group "$RG" \
        --query "[?startTime>='$START_TIME' && status=='Failed'] | length(@)" -o tsv 2>/dev/null || echo "0")
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ Failed jobs: $FAILED_COUNT${NC}"
    else
        echo -e "${GREEN}✅ No failed jobs${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ No Automation Account found${NC}"
fi

# Check deployment status
echo -e "\n${YELLOW}📋 Recent deployment status:${NC}"
LAST_DEPLOYMENT=$(az deployment group list --resource-group "$RG" \
    --query "[0].{Name:name,State:properties.provisioningState,Time:properties.timestamp}" -o json 2>/dev/null || echo "null")

if [ "$LAST_DEPLOYMENT" != "null" ]; then
    DEPLOY_NAME=$(echo "$LAST_DEPLOYMENT" | jq -r '.Name // "N/A"')
    DEPLOY_STATE=$(echo "$LAST_DEPLOYMENT" | jq -r '.State // "N/A"')
    DEPLOY_TIME=$(echo "$LAST_DEPLOYMENT" | jq -r '.Time // "N/A"')
    
    if [ "$DEPLOY_STATE" = "Succeeded" ]; then
        echo -e "${GREEN}✅ Last deployment: $DEPLOY_NAME ($DEPLOY_STATE)${NC}"
    else
        echo -e "${RED}❌ Last deployment: $DEPLOY_NAME ($DEPLOY_STATE)${NC}"
    fi
    echo -e "${BLUE}🕐 Time: $DEPLOY_TIME${NC}"
else
    echo -e "${YELLOW}⚠️ No deployments found${NC}"
fi

# Quick actions
echo -e "\n${YELLOW}🎯 Quick Actions:${NC}"
echo -e "${BLUE}  1. Full status check:${NC} ./cert-lifecycle-status.sh"
if [ -n "$RG" ] && [ -n "$AA" ] && [ -n "$DEMO_CERT" ]; then
    echo -e "${BLUE}  2. Event analysis:${NC} pwsh ./cert-lifecycle-events.ps1 -ResourceGroupName '$RG' -AutomationAccountName '$AA' -CertificateName '$DEMO_CERT'"
fi
echo -e "${BLUE}  3. Job investigation:${NC} pwsh ./investigate-job-output.ps1"
echo -e "${BLUE}  4. Key Vault diagnostics:${NC} ./diagnose-keyvault.sh"

echo -e "\n${GREEN}✅ Quick status check completed${NC}"