# Certificate Lifecycle Monitoring Guide

## 🎯 Overview

This guide covers the comprehensive certificate lifecycle monitoring tools that provide end-to-end visibility into certificate renewal automation, job execution, event processing, and deployment status.

## 🔧 Prerequisites

### Required Tools
- **Azure CLI** (`az`) - Must be logged in (`az login`)
- **jq** - JSON processing (for bash scripts)
- **PowerShell** - For detailed analysis scripts
- **Azure PowerShell** - For PowerShell scripts (`Connect-AzAccount`)

### Installation
```bash
# Install Azure CLI (if needed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install jq (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install jq

# Install PowerShell (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y powershell

# Login to Azure
az login
pwsh -c "Connect-AzAccount"
```

## 📊 Monitoring Tools Overview

### 1. `cert-quick-status.sh` - ⚡ Fast Overview
**Purpose**: Rapid health check of certificate lifecycle deployment

**Features**:
- Auto-discovers certificate lifecycle resources
- Shows certificate count and expiration status
- Displays recent automation job summary
- Identifies failed jobs in the last 24 hours
- Provides quick action suggestions

**Usage**:
```bash
./cert-quick-status.sh
```

**When to Use**:
- Daily health checks
- Initial deployment verification
- Quick troubleshooting triage
- Automated monitoring scripts

---

### 2. `cert-lifecycle-status.sh` - 🔍 Comprehensive Analysis
**Purpose**: Complete end-to-end certificate lifecycle monitoring

**Features**:
- **Certificate Analysis**: Versions, expiration, renewal history
- **Automation Account Status**: Job history, failed job details, runbook status
- **Event Grid Configuration**: Topics, subscriptions, event flow
- **Deployment Verification**: Recent deployments, resource status, error details
- **Interactive Discovery**: Auto-detects resources or prompts for input

**Usage**:
```bash
# Interactive mode (recommended for first use)
./cert-lifecycle-status.sh

# Pre-configured environment
export RESOURCE_GROUP="rg-demo-certlc"
export KEY_VAULT_NAME="kv-demo-certlc"
export CERTIFICATE_NAME="democert-shortlived"
export AUTOMATION_ACCOUNT="DEMO-AA-1030164500"
./cert-lifecycle-status.sh
```

**When to Use**:
- Comprehensive status reviews
- Troubleshooting certificate renewal issues
- Deployment validation
- Weekly/monthly reports

---

### 3. `cert-lifecycle-events.ps1` - 📊 PowerShell Deep Analysis
**Purpose**: Detailed event correlation and job analysis with PowerShell integration

**Features**:
- **Advanced Job Analysis**: Output parsing, error correlation, timing analysis
- **Event Timeline**: Certificate events with time-based correlation
- **Multi-version Tracking**: Certificate renewal history with timestamps
- **Failed Job Diagnostics**: Detailed error messages and stack traces
- **Azure Portal Integration**: Direct links to relevant resources

**Usage**:
```powershell
# Auto-discovery mode
.\cert-lifecycle-events.ps1

# Specific configuration
.\cert-lifecycle-events.ps1 `
    -ResourceGroupName "rg-demo-certlc" `
    -AutomationAccountName "DEMO-AA-1030164500" `
    -KeyVaultName "kv-demo-certlc" `
    -CertificateName "democert-shortlived" `
    -DaysBack 7 `
    -Detailed

# Focus on recent events
.\cert-lifecycle-events.ps1 -DaysBack 1 -Detailed
```

**Parameters**:
- `-ResourceGroupName`: Target resource group
- `-AutomationAccountName`: Automation account to analyze
- `-KeyVaultName`: Key vault containing certificates
- `-CertificateName`: Specific certificate to track
- `-DaysBack`: Days of history to analyze (default: 7)
- `-Detailed`: Include job output and error details

**When to Use**:
- Deep troubleshooting of failed renewals
- Certificate lifecycle event investigation
- Performance analysis of automation jobs
- Correlation between events and job execution

---

### 4. `investigate-job-output.ps1` - 🔎 Specific Job Investigation
**Purpose**: Detailed analysis of specific automation jobs (existing tool)

**Usage**:
```powershell
.\investigate-job-output.ps1 `
    -ResourceGroupName "rg-demo-certlc" `
    -AutomationAccountName "DEMO-AA-1030164500" `
    -CertificateName "democert-shortlived"
```

## 🔄 Certificate Lifecycle Monitoring Workflow

### Phase 1: Initial Assessment
```bash
# Start with quick overview
./cert-quick-status.sh
```

### Phase 2: Comprehensive Analysis (if issues found)
```bash
# Run full analysis
./cert-lifecycle-status.sh
```

### Phase 3: Deep Investigation (for specific issues)
```powershell
# Detailed PowerShell analysis
.\cert-lifecycle-events.ps1 -Detailed -DaysBack 3
```

### Phase 4: Specific Job Investigation (if jobs failed)
```powershell
# Focus on specific failed jobs
.\investigate-job-output.ps1 -ResourceGroupName "your-rg"
```

## 📋 Common Monitoring Scenarios

### Scenario 1: "Certificate Should Have Renewed But Didn't"
```bash
# 1. Check certificate status
./cert-lifecycle-status.sh

# 2. Analyze recent events and jobs
pwsh -c ".\cert-lifecycle-events.ps1 -DaysBack 3 -Detailed"

# 3. Check for failed automation jobs
# Look for jobs around expected renewal time
```

### Scenario 2: "Automation Jobs Are Failing"
```bash
# 1. Quick overview to identify scope
./cert-quick-status.sh

# 2. Detailed job analysis
pwsh -c ".\cert-lifecycle-events.ps1 -DaysBack 1 -Detailed"

# 3. Investigate specific failed job
pwsh -c ".\investigate-job-output.ps1"
```

### Scenario 3: "New Deployment - Verify Everything Works"
```bash
# 1. Comprehensive deployment check
./cert-lifecycle-status.sh

# 2. Create test certificate and monitor
pwsh -c ".\create-shortlived-cert.ps1"

# 3. Monitor renewal process
./cert-quick-status.sh  # Run periodically
```

### Scenario 4: "Regular Health Monitoring"
```bash
# Daily quick check (can be automated)
./cert-quick-status.sh

# Weekly comprehensive review
./cert-lifecycle-status.sh

# Monthly detailed analysis
pwsh -c ".\cert-lifecycle-events.ps1 -DaysBack 30 -Detailed"
```

## 🎯 Output Interpretation

### Status Indicators
- ✅ **Green/Success**: Component is working correctly
- ⚠️ **Yellow/Warning**: Attention needed but not critical
- ❌ **Red/Error**: Critical issue requiring immediate attention
- ℹ️ **Blue/Info**: Informational status
- 🔍 **Discovery**: Auto-detection in progress

### Certificate Status
- **Valid**: Certificate is not expired and has sufficient validity period
- **Expires within 7 days**: Certificate approaching expiration
- **EXPIRED**: Certificate has passed expiration date
- **Multiple versions found**: Certificate has been renewed (good sign)

### Job Status
- **Completed**: Job executed successfully
- **Failed**: Job encountered errors
- **Running**: Job currently executing
- **Recent**: Job executed in last few hours

## 🔧 Troubleshooting

### Common Issues and Solutions

#### "No resources found"
```bash
# Check resource group name
az group list --query "[].name" -o table

# Check current subscription
az account show --query "{name:name, id:id}"
```

#### "Permission denied" errors
```bash
# Check current permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Required permissions: Reader + Key Vault Secrets User
```

#### "PowerShell module not found"
```powershell
# Install required modules
Install-Module -Name Az -Force -AllowClobber
Connect-AzAccount
```

#### "jq not found" error
```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

## 📈 Automation and Integration

### Automated Daily Monitoring
```bash
#!/bin/bash
# daily-cert-check.sh
cd /path/to/certlc-deployment-scripts

# Quick status check
./cert-quick-status.sh > daily-status-$(date +%Y%m%d).log 2>&1

# Alert if failures detected
if grep -q "❌\|Failed" daily-status-$(date +%Y%m%d).log; then
    # Send alert (email, Teams, etc.)
    echo "Certificate lifecycle issues detected" | mail -s "ALERT: Certificate Issues" admin@company.com
fi
```

### Weekly Comprehensive Report
```bash
#!/bin/bash
# weekly-cert-report.sh
cd /path/to/certlc-deployment-scripts

# Generate comprehensive report
./cert-lifecycle-status.sh > weekly-report-$(date +%Y%m%d).log 2>&1

# Run PowerShell analysis
pwsh -c ".\cert-lifecycle-events.ps1 -DaysBack 7 -Detailed" >> weekly-report-$(date +%Y%m%d).log 2>&1
```

### Integration with Monitoring Systems
The scripts can be integrated with:
- **Azure Monitor**: Custom metrics and alerts
- **Log Analytics**: Centralized logging
- **Application Insights**: Performance monitoring
- **Teams/Slack**: Automated notifications
- **SIEM Systems**: Security event correlation

## 📚 Additional Resources

- **[Certificate Renewal Documentation](./complete-certificate-renewal.md)**
- **[Deployment Overview](./DEPLOYMENT_OVERVIEW.md)**
- **[Key Vault Diagnostics](./diagnose-keyvault.sh)**
- **[Azure Automation Documentation](https://docs.microsoft.com/azure/automation/)**

## 🎯 Best Practices

1. **Regular Monitoring**: Run `cert-quick-status.sh` daily
2. **Proactive Analysis**: Use comprehensive tools weekly
3. **Event Correlation**: Leverage PowerShell tools for deep analysis
4. **Documentation**: Keep monitoring logs for trend analysis
5. **Automation**: Integrate monitoring into CI/CD pipelines
6. **Alerting**: Set up automated notifications for critical issues