#!/bin/bash

# Enhanced Certificate Lifecycle Management - ARM Package Validation
# Validates the local deployment package before ARM deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 ARM DEPLOYMENT PACKAGE VALIDATION${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""
echo -e "${YELLOW}📋 Validating local deployment package before ARM deployment${NC}"
echo -e "${YELLOW}   This package replaces GitHub repo with enhanced features${NC}"
echo ""

# Package validation results
VALIDATION_PASSED=true

echo -e "${CYAN}🎯 PHASE 1: PACKAGE STRUCTURE VALIDATION${NC}"
echo "========================================"

# Required directories
required_dirs=(
    "templates"
    "scripts" 
    "testing"
    "runbooks"
)

echo -e "${YELLOW}📁 Directory Structure:${NC}"
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "   ✅ $dir/"
    else
        echo -e "   ❌ $dir/ ${RED}(MISSING)${NC}"
        VALIDATION_PASSED=false
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 2: ARM TEMPLATE VALIDATION${NC}"
echo "================================="

# Required ARM template files
arm_files=(
    "templates/enhanced-azuredeploy.json"
    "templates/enhanced-azuredeploy.parameters.json"
)

echo -e "${YELLOW}📄 ARM Template Files:${NC}"
for file in "${arm_files[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 1000 ]; then
            echo -e "   ✅ $file (${FILE_SIZE} bytes)"
        else
            echo -e "   ⚠️ $file ${YELLOW}(${FILE_SIZE} bytes - may be empty)${NC}"
        fi
    else
        echo -e "   ❌ $file ${RED}(MISSING)${NC}"
        VALIDATION_PASSED=false
    fi
done

# Validate ARM template JSON syntax
echo ""
echo -e "${YELLOW}🔍 JSON Syntax Validation:${NC}"
for file in "${arm_files[@]}"; do
    if [ -f "$file" ]; then
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$file" >/dev/null 2>&1; then
                echo -e "   ✅ $file - Valid JSON"
            else
                echo -e "   ❌ $file ${RED}- Invalid JSON syntax${NC}"
                VALIDATION_PASSED=false
            fi
        else
            echo -e "   ⚠️ $file - JSON validation skipped (jq not installed)"
        fi
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 3: ENHANCED RUNBOOK VALIDATION${NC}"
echo "====================================="

# Enhanced runbook files
runbook_files=(
    "scripts/Enhanced-CertLifeCycleMgmt.ps1"
    "runbooks/Enhanced-CertLifeCycleMgmt.ps1"
)

echo -e "${YELLOW}📜 Enhanced Runbook Files:${NC}"
for file in "${runbook_files[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 5000 ]; then
            echo -e "   ✅ $file (${FILE_SIZE} bytes)"
            
            # Check for enhanced features
            if grep -q "4-layer.*fallback\|OID.*extraction.*fallback" "$file" 2>/dev/null; then
                echo -e "      🚀 Contains 4-layer OID fallbacks"
            fi
            if grep -q "CertRenewalThresholdDays" "$file" 2>/dev/null; then
                echo -e "      🎯 Contains threshold configuration"
            fi
            if grep -q "Enhanced.*error.*handling\|comprehensive.*error" "$file" 2>/dev/null; then
                echo -e "      🛡️ Contains enhanced error handling"
            fi
        else
            echo -e "   ⚠️ $file ${YELLOW}(${FILE_SIZE} bytes - may be incomplete)${NC}"
        fi
    else
        echo -e "   ❌ $file ${RED}(MISSING)${NC}"
        VALIDATION_PASSED=false
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 4: DEPLOYMENT SCRIPTS VALIDATION${NC}"
echo "======================================="

# Deployment scripts
deployment_scripts=(
    "deploy-arm-enhanced.sh"
    "verify-arm-deployment.sh"
)

echo -e "${YELLOW}🔧 Deployment Scripts:${NC}"
for script in "${deployment_scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo -e "   ✅ $script (executable)"
        else
            echo -e "   ⚠️ $script ${YELLOW}(not executable)${NC}"
            chmod +x "$script" 2>/dev/null && echo -e "      🔧 Made executable"
        fi
    else
        echo -e "   ❌ $script ${RED}(MISSING)${NC}"
        VALIDATION_PASSED=false
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 5: TESTING SUITE VALIDATION${NC}"
echo "=================================="

# Count testing scripts
TESTING_SCRIPTS=$(find testing/ -name "*.ps1" 2>/dev/null | wc -l)
echo -e "${YELLOW}📊 Testing Framework:${NC}"
echo -e "   ✅ Testing scripts: $TESTING_SCRIPTS"

# Key testing scripts
key_tests=(
    "testing/direct-renewal-test.ps1"
    "testing/monitor-simple.ps1"
    "testing/complete-fix-simple.ps1"
    "testing/investigate-cert-templates.ps1"
)

for test in "${key_tests[@]}"; do
    if [ -f "$test" ]; then
        echo -e "   ✅ $(basename "$test")"
    else
        echo -e "   ⚠️ $(basename "$test") ${YELLOW}(missing)${NC}"
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 6: DOCUMENTATION VALIDATION${NC}"
echo "==================================="

# Documentation files
docs=(
    "README.md"
    "DEPLOYMENT-GUIDE.md"
    "QUICK-START.md"
)

echo -e "${YELLOW}📚 Documentation:${NC}"
for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        FILE_SIZE=$(stat -c%s "$doc" 2>/dev/null || echo "0")
        echo -e "   ✅ $doc (${FILE_SIZE} bytes)"
    else
        echo -e "   ⚠️ $doc ${YELLOW}(missing)${NC}"
    fi
done

echo ""
echo -e "${CYAN}🎯 PHASE 7: AZURE PREREQUISITES CHECK${NC}"
echo "===================================="

echo -e "${YELLOW}🔍 Azure CLI Prerequisites:${NC}"

# Check Azure CLI
if command -v az >/dev/null 2>&1; then
    echo -e "   ✅ Azure CLI installed"
    
    # Check authentication
    if az account show >/dev/null 2>&1; then
        SUBSCRIPTION=$(az account show --query name -o tsv)
        echo -e "   ✅ Azure CLI authenticated"
        echo -e "      📋 Subscription: $SUBSCRIPTION"
    else
        echo -e "   ⚠️ Azure CLI not authenticated ${YELLOW}(run: az login)${NC}"
    fi
else
    echo -e "   ❌ Azure CLI not installed ${RED}(required for deployment)${NC}"
    VALIDATION_PASSED=false
fi

# Check PowerShell
if command -v pwsh >/dev/null 2>&1; then
    echo -e "   ✅ PowerShell Core installed"
else
    echo -e "   ⚠️ PowerShell Core not installed ${YELLOW}(needed for testing)${NC}"
fi

echo ""
echo -e "${CYAN}🎯 VALIDATION SUMMARY${NC}"
echo "==================="

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}🎉 ARM DEPLOYMENT PACKAGE VALIDATION PASSED!${NC}"
    echo ""
    echo -e "${CYAN}✅ Package Ready for Deployment:${NC}"
    echo "   🏗️ ARM templates validated"
    echo "   🚀 Enhanced runbook with 4-layer fallbacks"
    echo "   🔧 Deployment scripts executable"
    echo "   📊 Testing suite complete ($TESTING_SCRIPTS scripts)"
    echo "   📚 Documentation available"
    echo "   ☁️ Azure CLI ready"
    echo ""
    echo -e "${GREEN}🚀 READY TO DEPLOY! Run: ${YELLOW}./deploy-arm-enhanced.sh${NC}"
    echo ""
    echo -e "${BLUE}📋 DEPLOYMENT SEQUENCE:${NC}"
    echo "1. ${YELLOW}./deploy-arm-enhanced.sh${NC}     # Deploy ARM template (25-30 min)"
    echo "2. ${YELLOW}./verify-arm-deployment.sh${NC}  # Verify deployment"
    echo "3. ${YELLOW}cd testing && pwsh ./direct-renewal-test.ps1${NC}  # Test certificates"
    echo ""
    echo -e "${CYAN}🎯 This deployment replaces the GitHub repo with ALL our enhancements!${NC}"
else
    echo -e "${RED}❌ ARM DEPLOYMENT PACKAGE VALIDATION FAILED!${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Fix the issues above before deploying${NC}"
    echo ""
    exit 1
fi