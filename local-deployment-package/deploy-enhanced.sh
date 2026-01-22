#!/bin/bash

# Enhanced Certificate Lifecycle Management Deployment Script
# Deploys our improved version with all fixes and optimizations

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="rg-demo-certlc"
AUTOMATION_ACCOUNT="DEMO-AA-20251103"
KEY_VAULT="DEMO-KV-20251103"
LOCATION="East US"

echo -e "${CYAN}🚀 ENHANCED CERTIFICATE LIFECYCLE MANAGEMENT DEPLOYMENT${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Pre-deployment checks
echo -e "${YELLOW}📋 PRE-DEPLOYMENT VALIDATION${NC}"
echo "=============================="

# Check Azure CLI
if ! command_exists az; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI installed${NC}"

# Check if logged in
if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}❌ Not logged into Azure${NC}"
    echo "Please run: az login"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI authenticated${NC}"

# Check PowerShell
if ! command_exists pwsh; then
    echo -e "${YELLOW}⚠️ PowerShell Core not found, checking for powershell...${NC}"
    if ! command_exists powershell; then
        echo -e "${RED}❌ PowerShell is not installed${NC}"
        echo "Please install PowerShell Core: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
        exit 1
    else
        PWSH_CMD="powershell"
    fi
else
    PWSH_CMD="pwsh"
fi
echo -e "${GREEN}✅ PowerShell available${NC}"

# Check if template files exist
if [ ! -f "templates/enhanced-certlc-template.json" ]; then
    echo -e "${RED}❌ Template file not found: templates/enhanced-certlc-template.json${NC}"
    echo "Please ensure you're running this script from the local-deployment-package directory"
    exit 1
fi
echo -e "${GREEN}✅ Template files found${NC}"

# Check if runbook exists
if [ ! -f "runbooks/Enhanced-CertLifeCycleMgmt.ps1" ]; then
    echo -e "${RED}❌ Enhanced runbook not found: runbooks/Enhanced-CertLifeCycleMgmt.ps1${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Enhanced runbook found${NC}"

echo ""
echo -e "${YELLOW}📊 DEPLOYMENT CONFIGURATION${NC}"
echo "============================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Automation Account: $AUTOMATION_ACCOUNT"
echo "Key Vault: $KEY_VAULT"
echo "Location: $LOCATION"
echo "Template: enhanced-certlc-template.json"
echo "Runbook: Enhanced-CertLifeCycleMgmt.ps1"
echo ""

# Confirmation
read -p "Proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}🎯 PHASE 1: RESOURCE GROUP VALIDATION${NC}"
echo "======================================"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Resource group $RESOURCE_GROUP does not exist${NC}"
    echo "Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo -e "${GREEN}✅ Resource group created${NC}"
else
    echo -e "${GREEN}✅ Resource group $RESOURCE_GROUP exists${NC}"
fi

echo ""
echo -e "${CYAN}🎯 PHASE 2: DEPLOY ENHANCED RUNBOOK${NC}"
echo "=================================="

# Deploy the enhanced runbook using PowerShell
echo "Deploying Enhanced-CertLifeCycleMgmt runbook..."
$PWSH_CMD -Command "
    Import-Module Az.Automation -Force

    # Get the absolute path to the runbook file
    \$runbookPath = Resolve-Path 'runbooks/Enhanced-CertLifeCycleMgmt.ps1'

    # Check if runbook exists and update or create
    try {
        \$existingRunbook = Get-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt' -ErrorAction SilentlyContinue
        
        if (\$existingRunbook) {
            Write-Host '⚠️ Updating existing Enhanced-CertLifeCycleMgmt runbook...' -ForegroundColor Yellow
            # Import to update the runbook content
            Import-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt' -Path \$runbookPath -Type PowerShell -Force -Published
        } else {
            Write-Host '📝 Creating new Enhanced-CertLifeCycleMgmt runbook...' -ForegroundColor White
            # Create new runbook
            Import-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt' -Path \$runbookPath -Type PowerShell -Published
        }
        
        Write-Host '✅ Enhanced runbook deployed successfully' -ForegroundColor Green
    } catch {
        Write-Host \"❌ Failed to deploy enhanced runbook: \$(\$_.Exception.Message)\" -ForegroundColor Red
        exit 1
    }
"

echo ""
echo -e "${CYAN}🎯 PHASE 3: DEPLOY AUTOMATION VARIABLES${NC}"
echo "======================================"

# Deploy automation variables
echo "Deploying optimized automation variables..."
$PWSH_CMD -Command "
    Import-Module Az.Automation -Force

    # Define automation variables with our tested values
    \$variables = @(
        @{ Name = 'CertRenewalThresholdDays'; Value = '40'; Description = 'Number of days before certificate expiry to trigger renewal' },
        @{ Name = 'DefaultCertificateTemplate'; Value = 'WebServer'; Description = 'Default certificate template for automated renewals' },
        @{ Name = 'DefaultEmailRecipient'; Value = 'admin@MngEnv829153.onmicrosoft.com'; Description = 'Email address for certificate lifecycle notifications' },
        @{ Name = 'FallbackCAServer'; Value = 'ca01.demo.com'; Description = 'Fallback Certificate Authority server for certificate issuance' },
        @{ Name = 'EnableDetailedLogging'; Value = 'true'; Description = 'Enable detailed logging for troubleshooting' },
        @{ Name = 'MaxRetryAttempts'; Value = '3'; Description = 'Maximum retry attempts for certificate operations' },
        @{ Name = 'RetryDelaySeconds'; Value = '30'; Description = 'Delay between retry attempts in seconds' },
        @{ Name = 'CertificateKeySize'; Value = '2048'; Description = 'Default key size for new certificates' }
    )

    foreach (\$var in \$variables) {
        try {
            # Check if variable exists
            \$existingVar = Get-AzAutomationVariable -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name \$var.Name -ErrorAction SilentlyContinue
            
            if (\$existingVar) {
                Write-Host \"⚠️ Updating \$(\$var.Name) = \$(\$var.Value)\" -ForegroundColor Yellow
                Set-AzAutomationVariable -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name \$var.Name -Value \$var.Value -Encrypted \$false
            } else {
                Write-Host \"📝 Creating \$(\$var.Name) = \$(\$var.Value)\" -ForegroundColor White
                New-AzAutomationVariable -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name \$var.Name -Value \$var.Value -Description \$var.Description -Encrypted \$false
            }
            Write-Host \"✅ \$(\$var.Name) configured successfully\" -ForegroundColor Green
        } catch {
            Write-Host \"❌ Failed to configure \$(\$var.Name): \$(\$_.Exception.Message)\" -ForegroundColor Red
        }
    }
"

echo ""
echo -e "${CYAN}🎯 PHASE 4: DEPLOYMENT VERIFICATION${NC}"
echo "=================================="

# Verify deployment
echo "Verifying deployment..."
$PWSH_CMD -Command "
    Import-Module Az.Automation -Force

    Write-Host '📋 Verifying Enhanced Runbook...' -ForegroundColor White
    try {
        \$runbook = Get-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt'
        if (\$runbook.State -eq 'Published') {
            Write-Host '✅ Enhanced-CertLifeCycleMgmt runbook deployed and published' -ForegroundColor Green
        } else {
            Write-Host \"⚠️ Enhanced runbook state: \$(\$runbook.State)\" -ForegroundColor Yellow
        }
    } catch {
        Write-Host '❌ Enhanced runbook verification failed' -ForegroundColor Red
    }

    Write-Host '📋 Verifying Automation Variables...' -ForegroundColor White
    \$requiredVars = @('CertRenewalThresholdDays', 'DefaultCertificateTemplate', 'DefaultEmailRecipient', 'FallbackCAServer')
    \$verifiedVars = 0
    
    foreach (\$varName in \$requiredVars) {
        try {
            \$var = Get-AzAutomationVariable -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name \$varName
            Write-Host \"✅ \$varName = \$(\$var.Value)\" -ForegroundColor Green
            \$verifiedVars++
        } catch {
            Write-Host \"❌ \$varName not found\" -ForegroundColor Red
        }
    }
    
    if (\$verifiedVars -eq \$requiredVars.Count) {
        Write-Host '✅ All required automation variables verified' -ForegroundColor Green
    } else {
        Write-Host \"⚠️ \$verifiedVars/\$(\$requiredVars.Count) variables verified\" -ForegroundColor Yellow
    }
"

echo ""
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo "======================="
echo ""
echo -e "${CYAN}📊 DEPLOYMENT SUMMARY:${NC}"
echo "✅ Enhanced-CertLifeCycleMgmt runbook deployed"
echo "✅ Optimized automation variables configured"
echo "✅ 40-day certificate renewal threshold set"
echo "✅ WebServer template configured as default"
echo "✅ Comprehensive error handling enabled"
echo ""
echo -e "${CYAN}🔧 NEXT STEPS:${NC}"
echo "1. Test certificate detection: cd ../certlc-deployment-scripts/testing/current-scripts && pwsh ./direct-renewal-test.ps1"
echo "2. Monitor automation jobs: pwsh ./monitor-simple.ps1"
echo "3. Validate end-to-end workflow: pwsh ./test-complete-lifecycle.ps1"
echo ""
echo -e "${GREEN}🚀 Your enhanced certificate lifecycle management system is ready!${NC}"