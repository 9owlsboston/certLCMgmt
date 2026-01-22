# Jump Host Scripts Usage Guide

## Configuration Status ✅
All scripts have been updated to dynamically load configuration from `.env` file:
- Resource Group: `rg-demo-certlc`
- Automation Account: `DEMO-AA-1030164500`
- Configuration loading confirmed working

## WSMan Requirement
These scripts require WSMan (Windows Remote Management) which is not available in Linux environments. 

## Usage Instructions

### From Windows PowerShell Environment:
```powershell
# Navigate to diagnostics folder
cd certlc-deployment-scripts/diagnostics

# Test connectivity (loads config automatically)
.\Connect-ViaJumpHost.ps1 -Action Test

# Check hybrid worker status
.\Test-HybridWorker-JumpHost.ps1

# Manage hybrid worker service
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Status
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Restart
```

### From Azure Cloud Shell (PowerShell):
```powershell
# Upload scripts to Cloud Shell
# Run with proper Azure context
```

## Scripts Overview

1. **Connect-ViaJumpHost.ps1**
   - General purpose jump host connection
   - Actions: Test, Connect, Execute, Info
   - Auto-loads configuration from .env

2. **Test-HybridWorker-JumpHost.ps1** 
   - Specifically tests hybrid worker status
   - Checks Azure registration and local service
   - Uses configuration for correct resource group

3. **Manage-HybridWorkerService-JumpHost.ps1**
   - Service management on ca01 via dc01
   - Actions: Status, Start, Stop, Restart
   - Service log analysis included

## Next Steps
1. Run scripts from Windows PowerShell environment
2. Verify hybrid worker service status
3. Restart service if needed
4. Re-register worker if connectivity fails