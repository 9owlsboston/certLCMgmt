# 🚀 Fast Certificate Renewal Testing Guide

## 🎯 Quick Start

Create and test ultra-fast certificate renewal (2-5 minutes total cycle):

```bash
# Navigate to testing directory
cd /home/velen/cx/adobe/certLCMgmt/local-deployment-package/testing

# Run complete fast renewal test
pwsh ./fast-renewal-complete-test.ps1
```

## ⚡ Fast Renewal Scripts

### 1. Complete Test Suite
```bash
# Full automated test with monitoring
pwsh ./fast-renewal-complete-test.ps1 -ExpiryMinutes 2 -RunFullTest

# Quick certificate creation only  
pwsh ./fast-renewal-complete-test.ps1 -ExpiryMinutes 3 -RunFullTest:$false

# With continuous monitoring
pwsh ./fast-renewal-complete-test.ps1 -ContinuousMonitoring
```

### 2. Individual Components
```bash
# Create fast-expiry certificate
pwsh ./create-fast-renewal-cert.ps1 -ExpiryMinutes 2

# Create multiple test certificates
pwsh ./create-fast-renewal-cert.ps1 -CreateMultiple

# Configure Event Grid for fast response
pwsh ./configure-fast-event-grid.ps1 -CreateSubscription

# Monitor renewal process
pwsh ./monitor-simple.ps1
```

## 🔧 What Makes It Fast

### ⏱️ Optimized Timing
- **Certificate Expiry**: 2-5 minutes (configurable)
- **Event Grid Trigger**: ~1 minute before expiry
- **Renewal Processing**: 1-2 minutes
- **Total Cycle**: 3-7 minutes end-to-end

### ⚡ Enhanced Configuration
- **Event Grid**: Immediate trigger response
- **Automation Variables**: 40-day threshold (way above 2-5 minutes)
- **Enhanced Runbook**: 4-layer OID fallback system
- **Webhook Integration**: Direct automation trigger

### 📊 Fast Testing Features
- **Multiple Certificates**: 1, 3, 5 minute expiry tests
- **Real-time Monitoring**: Live renewal process tracking
- **Immediate Validation**: Quick success/failure feedback
- **Comprehensive Logging**: Detailed process visibility

## 🎯 Expected Timeline

```
Time    Event
-----   -----
00:00   Certificate created (expires in 2 minutes)
01:00   Event Grid near-expiry trigger
01:30   Enhanced runbook starts processing
02:00   Certificate officially expires
02:30   Renewal process completes
03:00   New certificate available in Key Vault
```

## 🔍 Monitoring Commands

### Real-time Monitoring
```powershell
# Continuous monitoring
pwsh ./monitor-simple.ps1

# Check certificates in Key Vault
Get-AzKeyVaultCertificate -VaultName DEMO-KV-20251103

# Check automation jobs
Get-AzAutomationJob -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc | Sort-Object StartTime -Descending | Select-Object -First 5
```

### Verification Commands
```powershell
# Verify fast-renewal certificates
Get-AzKeyVaultCertificate -VaultName DEMO-KV-20251103 | Where-Object { $_.Tags.Purpose -eq "FastRenewalTesting" }

# Check recent automation activity
Get-AzAutomationJob -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc -StartTime (Get-Date).AddHours(-1)

# Verify Event Grid subscriptions
Get-AzEventGridSubscription -ResourceGroupName rg-demo-certlc | Where-Object { $_.EventSubscriptionName -like "*Fast*" }
```

## 🎉 Success Indicators

### ✅ Certificate Created Successfully
- Certificate appears in Key Vault
- Tagged for fast renewal testing
- Expires in configured minutes

### ✅ Event Grid Triggered
- Event Grid subscription receives near-expiry event
- Webhook calls Enhanced runbook
- Automation job starts processing

### ✅ Renewal Processed
- Enhanced runbook executes without errors
- Certificate renewal attempt made
- New certificate version created

### ✅ Complete Success
- Original certificate shows as renewed
- New certificate has extended expiry
- Process completes within expected timeline

## 🔧 Troubleshooting

### Certificate Not Created
```bash
# Check Azure authentication
Get-AzContext

# Verify Key Vault access
Get-AzKeyVault -VaultName DEMO-KV-20251103

# Check permissions
Get-AzKeyVaultAccessPolicy -VaultName DEMO-KV-20251103
```

### Event Grid Not Triggering
```bash
# Verify Event Grid configuration
pwsh ./configure-fast-event-grid.ps1

# Check subscriptions
Get-AzEventGridSubscription -ResourceGroupName rg-demo-certlc

# Test webhook connectivity
Get-AzAutomationWebhook -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc
```

### Runbook Fails
```bash
# Check Enhanced runbook deployment
Get-AzAutomationRunbook -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc -Name "Enhanced-CertLifeCycleMgmt"

# Review automation variables
Get-AzAutomationVariable -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc

# Check Hybrid Worker status
Get-AzAutomationHybridWorkerGroup -AutomationAccountName DEMO-AA-20251103 -ResourceGroupName rg-demo-certlc
```

## 📈 Optimization Tips

### For Even Faster Testing
```bash
# 1-minute expiry (extreme fast testing)
pwsh ./create-fast-renewal-cert.ps1 -ExpiryMinutes 1

# Multiple rapid tests
pwsh ./create-fast-renewal-cert.ps1 -CreateMultiple
```

### For Production-like Testing
```bash
# 30-minute expiry (more realistic)
pwsh ./create-fast-renewal-cert.ps1 -ExpiryMinutes 30

# Standard threshold testing
pwsh ./fast-renewal-complete-test.ps1 -ExpiryMinutes 60
```

---

## 🚀 Quick Commands Summary

```bash
# ONE-COMMAND FAST TEST
pwsh ./fast-renewal-complete-test.ps1

# MONITOR ONLY
pwsh ./monitor-simple.ps1

# CREATE CERTIFICATE ONLY
pwsh ./create-fast-renewal-cert.ps1 -ExpiryMinutes 2

# EXTREME FAST (1 minute)
pwsh ./create-fast-renewal-cert.ps1 -ExpiryMinutes 1 -MonitorRenewal
```

**🎯 Your certificates will expire and renew automatically within 2-5 minutes!**