# Hybrid Runbook Worker Troubleshooting Guide

## Quick Start - Fix the Current Issue

**Problem**: Hybrid Worker on ca01 hasn't checked in since October 31, 2025 8:27 AM  
**Impact**: All certificate lifecycle jobs are suspended immediately  
**Solution**: Follow these steps in order

### Step 1: Connect to ca01
```powershell
# Test connectivity and get server info
.\Connect-CA01.ps1 -ConnectionType Test

# If test passes, connect via PowerShell
.\Connect-CA01.ps1 -ConnectionType PowerShell

# If PowerShell remoting fails, try RDP
.\Connect-CA01.ps1 -ConnectionType RDP
```

### Step 2: Restart Hybrid Worker Services
```powershell
# Check current service status
.\Manage-HybridWorkerService.ps1 -Action Check -Detailed

# Restart the services
.\Manage-HybridWorkerService.ps1 -Action Restart

# Verify services are running
.\Manage-HybridWorkerService.ps1 -Action Status
```

### Step 3: Test if Fix Worked
```powershell
# Quick test to see if worker is back online
.\Test-HybridWorker.ps1 -TestType Quick -WaitForCompletion

# If successful, test certificate operations
.\Test-HybridWorker.ps1 -TestType CertTest
```

### Step 4: If Restart Doesn't Work - Re-register
```powershell
# Full re-registration (removes and re-adds worker)
.\Reregister-HybridWorker.ps1 -Action Full

# Test again after re-registration
.\Test-HybridWorker.ps1 -TestType Full -WaitForCompletion
```

## Files Created

### Documentation
- **[HYBRID_WORKER_TROUBLESHOOTING.md](../docs/HYBRID_WORKER_TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide with detailed procedures and common solutions

### Scripts
- **[Connect-CA01.ps1](Connect-CA01.ps1)** - Connect to ca01 server via RDP or PowerShell
- **[Manage-HybridWorkerService.ps1](Manage-HybridWorkerService.ps1)** - Check, restart, and manage Hybrid Worker services
- **[Reregister-HybridWorker.ps1](Reregister-HybridWorker.ps1)** - Remove and re-register Hybrid Worker if service restart doesn't work
- **[Test-HybridWorker.ps1](Test-HybridWorker.ps1)** - Verify Hybrid Worker is working after fixes

## Current Environment Details

- **Subscription**: f8c6ec45-4437-4670-80b1-cc3cb09c3ce0
- **Resource Group**: rg-certlc-dev
- **Automation Account**: certlc-automation-dev
- **Hybrid Worker Group**: EnterpriseRootCA
- **CA Server**: ca01 (IP: 10.0.0.5)
- **Domain Controller**: dc01 (IP: 10.0.0.4)
- **Worker ID**: f47ceb57-e588-5f42-8431-78e508a58d3d
- **Last Check-in**: October 31, 2025 8:27:29 AM

## Troubleshooting Workflow

```
1. CONNECT TO CA01
   ├── Test connectivity (ping, RDP port, WinRM)
   ├── Connect via PowerShell remoting (preferred)
   └── If remoting fails, use RDP

2. CHECK SERVICE STATUS
   ├── Verify Hybrid Worker services are running
   ├── Check recent event logs for errors
   └── Test network connectivity to Azure

3. RESTART SERVICES
   ├── Stop Microsoft Monitoring Agent
   ├── Stop HealthService
   ├── Start HealthService
   └── Start Microsoft Monitoring Agent

4. VERIFY FIX
   ├── Check Azure portal for worker status
   ├── Submit test automation job
   └── Verify job runs (not suspended)

5. IF RESTART FAILS - RE-REGISTER
   ├── Remove existing worker registration
   ├── Clean local files and registry
   ├── Re-register with current credentials
   └── Test end-to-end functionality
```

## Common Issues & Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Service Stopped | Service not running, no recent logs | Restart services |
| Network Issues | Timeout errors, DNS failures | Check firewall, proxy, DNS |
| Auth Expired | 401/403 errors in logs | Re-register worker |
| System Resources | Out of memory, disk space | Clean temp files, restart |
| Azure Outage | Multiple workers offline | Wait for Azure resolution |

## Prevention

1. **Set up monitoring** for Hybrid Worker connectivity
2. **Regular health checks** - run weekly status checks
3. **Credential rotation** - automate credential renewal
4. **Resource monitoring** - monitor ca01 system resources
5. **Backup worker** - consider secondary hybrid worker

## Emergency Procedures

### If ca01 is completely inaccessible:
1. Check VM status in Azure portal
2. Restart VM if needed
3. Connect via Azure Bastion if available
4. Use Azure VM Run Command for emergency access

### If Azure Automation is having issues:
1. Check Azure status page
2. Verify subscription and resource group access
3. Test with different automation account if available

## Test Commands

```powershell
# Test everything is working
.\Test-HybridWorker.ps1 -TestType Full -WaitForCompletion

# Quick connectivity test
.\Test-HybridWorker.ps1 -TestType ConnectivityOnly

# Test certificate operations specifically
.\Test-HybridWorker.ps1 -TestType CertTest

# Just check worker status
.\Test-HybridWorker.ps1 -TestType Quick
```

## Next Steps After Fix

1. **Verify certificate operations** - Run a full certificate lifecycle test
2. **Check queue processing** - Verify storage queue is being processed
3. **Monitor for 24 hours** - Ensure worker stays online
4. **Update monitoring** - Add alerts for future worker offline conditions
5. **Document lessons learned** - Update procedures based on root cause

---

**Created**: November 1, 2025  
**Issue Date**: October 31, 2025 (Worker offline since 8:27 AM)  
**Estimated Fix Time**: 15-30 minutes for service restart, 1-2 hours for full re-registration