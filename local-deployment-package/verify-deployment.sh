#!/bin/bash

# Verification Script for Enhanced Certificate Lifecycle Management Deployment
# Validates that all components are properly deployed and configured

set -e

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

echo -e "${CYAN}🔍 ENHANCED CERTIFICATE LIFECYCLE DEPLOYMENT VERIFICATION${NC}"
echo -e "${CYAN}=========================================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check PowerShell availability
if command_exists pwsh; then
    PWSH_CMD="pwsh"
elif command_exists powershell; then
    PWSH_CMD="powershell"
else
    echo -e "${RED}❌ PowerShell not found${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 DEPLOYMENT VERIFICATION${NC}"
echo "=========================="

# Verify with PowerShell
$PWSH_CMD -Command "
    Import-Module Az.Automation -Force
    Import-Module Az.KeyVault -Force

    Write-Host '🔍 VERIFICATION RESULTS' -ForegroundColor Cyan
    Write-Host '======================' -ForegroundColor Cyan
    Write-Host ''

    # 1. Verify Enhanced Runbook
    Write-Host '📋 1. Enhanced Runbook Verification' -ForegroundColor Yellow
    try {
        \$runbook = Get-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt' -ErrorAction Stop
        Write-Host \"   ✅ Enhanced-CertLifeCycleMgmt found\" -ForegroundColor Green
        Write-Host \"   📊 State: \$(\$runbook.State)\" -ForegroundColor White
        Write-Host \"   📅 Last Modified: \$(\$runbook.LastModifiedTime.ToString('yyyy-MM-dd HH:mm'))\" -ForegroundColor White
        
        if (\$runbook.State -eq 'Published') {
            Write-Host '   ✅ Runbook is Published and ready' -ForegroundColor Green
        } else {
            Write-Host '   ⚠️ Runbook is not Published' -ForegroundColor Yellow
        }
    } catch {
        Write-Host '   ❌ Enhanced-CertLifeCycleMgmt not found' -ForegroundColor Red
        Write-Host \"   Error: \$(\$_.Exception.Message)\" -ForegroundColor Red
    }
    Write-Host ''

    # 2. Verify Automation Variables
    Write-Host '📋 2. Automation Variables Verification' -ForegroundColor Yellow
    \$requiredVars = @{
        'CertRenewalThresholdDays' = '40'
        'DefaultCertificateTemplate' = 'WebServer'
        'DefaultEmailRecipient' = 'admin@MngEnv829153.onmicrosoft.com'
        'FallbackCAServer' = 'ca01.demo.com'
        'EnableDetailedLogging' = 'true'
        'MaxRetryAttempts' = '3'
        'RetryDelaySeconds' = '30'
        'CertificateKeySize' = '2048'
    }
    
    \$verifiedCount = 0
    foreach (\$varName in \$requiredVars.Keys) {
        try {
            \$var = Get-AzAutomationVariable -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name \$varName -ErrorAction Stop
            \$expectedValue = \$requiredVars[\$varName]
            
            if (\$var.Value -eq \$expectedValue) {
                Write-Host \"   ✅ \$varName = \$(\$var.Value) ✓\" -ForegroundColor Green
                \$verifiedCount++
            } else {
                Write-Host \"   ⚠️ \$varName = \$(\$var.Value) (expected: \$expectedValue)\" -ForegroundColor Yellow
            }
        } catch {
            Write-Host \"   ❌ \$varName not found\" -ForegroundColor Red
        }
    }
    
    Write-Host \"   📊 Variables verified: \$verifiedCount/\$(\$requiredVars.Count)\" -ForegroundColor White
    Write-Host ''

    # 3. Verify Key Vault Access
    Write-Host '📋 3. Key Vault Access Verification' -ForegroundColor Yellow
    try {
        \$certificates = Get-AzKeyVaultCertificate -VaultName '$KEY_VAULT' -ErrorAction Stop
        Write-Host \"   ✅ Key Vault accessible\" -ForegroundColor Green
        Write-Host \"   📊 Certificates found: \$(\$certificates.Count)\" -ForegroundColor White
        
        # Check for certificates needing renewal
        \$threshold = 40
        \$renewalCandidates = 0
        foreach (\$cert in \$certificates) {
            try {
                \$certDetail = Get-AzKeyVaultCertificate -VaultName '$KEY_VAULT' -Name \$cert.Name
                if (\$certDetail.Certificate) {
                    \$daysUntilExpiry = (\$certDetail.Certificate.NotAfter - (Get-Date)).Days
                    if (\$daysUntilExpiry -le \$threshold) {
                        \$renewalCandidates++
                    }
                }
            } catch { }
        }
        
        Write-Host \"   📊 Certificates needing renewal (≤\$threshold days): \$renewalCandidates\" -ForegroundColor White
        
        if (\$renewalCandidates -gt 0) {
            Write-Host '   ✅ Test certificates available for renewal validation' -ForegroundColor Green
        } else {
            Write-Host '   ⚠️ No certificates currently need renewal' -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host '   ❌ Key Vault access failed' -ForegroundColor Red
        Write-Host \"   Error: \$(\$_.Exception.Message)\" -ForegroundColor Red
    }
    Write-Host ''

    # 4. Verify Recent Automation Activity
    Write-Host '📋 4. Automation System Health' -ForegroundColor Yellow
    try {
        \$recentJobs = Get-AzAutomationJob -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' | 
                      Where-Object { \$_.StartTime -gt (Get-Date).AddHours(-24) } | 
                      Sort-Object StartTime -Descending | 
                      Select-Object -First 5
        
        if (\$recentJobs) {
            Write-Host '   📊 Recent automation jobs (last 24 hours):' -ForegroundColor White
            foreach (\$job in \$recentJobs) {
                \$statusIcon = switch (\$job.Status) {
                    'Completed' { '✅' }
                    'Running' { '🔄' }
                    'Failed' { '❌' }
                    default { '⏳' }
                }
                \$timeStr = \$job.StartTime.ToString('MM/dd HH:mm')
                Write-Host \"     \$statusIcon \$(\$job.RunbookName) | \$(\$job.Status) | \$timeStr\" -ForegroundColor White
            }
        } else {
            Write-Host '   📝 No recent automation activity' -ForegroundColor Gray
        }
    } catch {
        Write-Host '   ❌ Could not retrieve automation job history' -ForegroundColor Red
    }
    Write-Host ''

    # 5. Overall Status
    Write-Host '🎯 OVERALL DEPLOYMENT STATUS' -ForegroundColor Cyan
    Write-Host '============================' -ForegroundColor Cyan
    
    \$overallStatus = 'READY'
    \$issues = @()
    
    # Check critical components
    try {
        \$enhancedRunbook = Get-AzAutomationRunbook -AutomationAccountName '$AUTOMATION_ACCOUNT' -ResourceGroupName '$RESOURCE_GROUP' -Name 'Enhanced-CertLifeCycleMgmt' -ErrorAction Stop
        if (\$enhancedRunbook.State -ne 'Published') {
            \$issues += 'Enhanced runbook not published'
            \$overallStatus = 'NEEDS ATTENTION'
        }
    } catch {
        \$issues += 'Enhanced runbook missing'
        \$overallStatus = 'FAILED'
    }
    
    if (\$verifiedCount -lt 6) {
        \$issues += 'Missing automation variables'
        \$overallStatus = 'NEEDS ATTENTION'
    }
    
    # Display final status
    if (\$overallStatus -eq 'READY') {
        Write-Host '🎉 DEPLOYMENT STATUS: READY' -ForegroundColor Green
        Write-Host '✅ Enhanced certificate lifecycle management system is operational' -ForegroundColor Green
        Write-Host ''
        Write-Host '🔧 READY FOR TESTING:' -ForegroundColor Yellow
        Write-Host '1. Run certificate analysis: pwsh ./testing/direct-renewal-test.ps1' -ForegroundColor White
        Write-Host '2. Monitor automation: pwsh ./testing/monitor-simple.ps1' -ForegroundColor White
        Write-Host '3. Test runbook manually: pwsh ./testing/quick-manual-test.ps1' -ForegroundColor White
    } elseif (\$overallStatus -eq 'NEEDS ATTENTION') {
        Write-Host '⚠️ DEPLOYMENT STATUS: NEEDS ATTENTION' -ForegroundColor Yellow
        Write-Host 'Issues found:' -ForegroundColor Yellow
        foreach (\$issue in \$issues) {
            Write-Host \"   - \$issue\" -ForegroundColor White
        }
        Write-Host ''
        Write-Host 'Re-run deployment to fix issues: ./deploy-enhanced.sh' -ForegroundColor White
    } else {
        Write-Host '❌ DEPLOYMENT STATUS: FAILED' -ForegroundColor Red
        Write-Host 'Critical issues found:' -ForegroundColor Red
        foreach (\$issue in \$issues) {
            Write-Host \"   - \$issue\" -ForegroundColor White
        }
        Write-Host ''
        Write-Host 'Please re-run deployment: ./deploy-enhanced.sh' -ForegroundColor White
    }
"

echo ""
echo -e "${GREEN}✅ VERIFICATION COMPLETE${NC}"