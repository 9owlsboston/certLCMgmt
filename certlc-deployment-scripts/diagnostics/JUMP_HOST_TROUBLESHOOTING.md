# Jump Host Troubleshooting Guide for Hybrid Runbook Worker

## Current Situation
- **CA01 is not directly accessible** - requires jump host
- **DC01 serves as jump host** - Domain Controller with network access to CA01
- **Hybrid Worker offline** since October 31, 2025 8:27 AM
- **All certificate jobs suspended** immediately upon submission

## Jump Host Architecture

```
Your Machine → DC01 (Jump Host) → CA01 (Hybrid Worker)
    |              |                    |
    |         Domain Controller    Certificate Authority
    |         (10.0.0.4)          (10.0.0.5)
    |              |                    |
PowerShell ────PowerShell─────PowerShell Remoting
Remoting       Remoting       + Service Management
```

## Quick Fix Steps (Jump Host Method)

### Step 1: Test Jump Host Connectivity
```powershell
# Test all connectivity through jump host
.\Test-HybridWorker-JumpHost.ps1 -TestType Quick

# Test just network connectivity
.\Test-HybridWorker-JumpHost.ps1 -TestType ConnectivityOnly

# Test only service status
.\Test-HybridWorker-JumpHost.ps1 -TestType ServiceCheck
```

### Step 2: Check Service Status via Jump Host
```powershell
# Check current Hybrid Worker service status on ca01 via dc01
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Check -Detailed

# Just get status without logs
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Status
```

### Step 3: Restart Services via Jump Host
```powershell
# Restart Hybrid Worker services on ca01 via dc01
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Restart

# Check status after restart
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Status
```

### Step 4: Verify Fix Worked
```powershell
# Test that services are working
.\Test-HybridWorker-JumpHost.ps1 -TestType ServiceCheck

# Test network connectivity from ca01 to Azure
.\Test-HybridWorker-JumpHost.ps1 -TestType ConnectivityOnly
```

## Jump Host Scripts Available

### Primary Scripts
1. **[Connect-ViaJumpHost.ps1](Connect-ViaJumpHost.ps1)** - General jump host connection and command execution
2. **[Manage-HybridWorkerService-JumpHost.ps1](Manage-HybridWorkerService-JumpHost.ps1)** - Service management via jump host
3. **[Test-HybridWorker-JumpHost.ps1](Test-HybridWorker-JumpHost.ps1)** - Verification and testing via jump host

### Script Functions

#### Connect-ViaJumpHost.ps1
- **Test connectivity** to both jump host and target
- **Interactive connection** for manual troubleshooting
- **Execute commands** remotely through jump host
- **Get server information** through the chain

#### Manage-HybridWorkerService-JumpHost.ps1
- **Check service status** on ca01 via dc01
- **Restart services** with proper sequence
- **View event logs** for troubleshooting
- **Monitor service health** post-restart

#### Test-HybridWorker-JumpHost.ps1
- **Azure worker status** verification
- **Service status** on target server
- **Network connectivity** testing
- **End-to-end validation**

## PowerShell Remoting Requirements

### On DC01 (Jump Host)
```powershell
# Ensure PowerShell remoting is enabled
Enable-PSRemoting -Force
```

### On CA01 (Target)
```powershell
# Enable PowerShell remoting (run this via RDP/console if needed)
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "dc01" -Force
```

### From Your Machine
```powershell
# Add both servers to trusted hosts if not domain-joined
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "dc01,ca01" -Force
```

## Troubleshooting Common Issues

### 1. Cannot Connect to Jump Host (DC01)
**Symptoms**: "Test-Connection" fails to dc01
**Solutions**:
- Verify dc01 IP address (should be 10.0.0.4)
- Check network connectivity to Azure VNet
- Ensure VM is running in Azure portal
- Try Azure Bastion if available

### 2. PowerShell Remoting Fails to Jump Host
**Symptoms**: New-PSSession fails to dc01
**Solutions**:
```powershell
# Test WinRM connectivity
Test-NetConnection -ComputerName dc01 -Port 5985

# Enable PowerShell remoting on dc01 (if you have console access)
.\Connect-ViaJumpHost.ps1 -Action Execute -Command "Enable-PSRemoting -Force"
```

### 3. Jump Host Cannot Reach CA01
**Symptoms**: dc01 can't ping ca01
**Solutions**:
- Check if ca01 VM is running
- Verify both VMs are in same subnet
- Check Network Security Group rules
- Verify internal DNS resolution

### 4. PowerShell Remoting Fails from Jump Host to Target
**Symptoms**: dc01 can ping ca01 but can't establish PS session
**Solutions**:
```powershell
# Test from jump host to target (manual)
.\Connect-ViaJumpHost.ps1 -Action Connect
# Then from jump host session:
Test-NetConnection -ComputerName ca01 -Port 5985
Enable-PSRemoting -Force  # run this on ca01 if needed
```

## Network Architecture Details

### Server Details
- **DC01**: 10.0.0.4 (Domain Controller, Jump Host)
- **CA01**: 10.0.0.5 (Certificate Authority, Hybrid Worker)
- **Subnet**: Both in same Azure Virtual Network
- **Domain**: Both domain-joined (AD authentication)

### Required Ports
- **5985/tcp**: PowerShell Remoting (WinRM HTTP)
- **5986/tcp**: PowerShell Remoting (WinRM HTTPS) - optional
- **3389/tcp**: RDP (if console access needed)

### Firewall Considerations
- Windows Firewall on both servers should allow WinRM
- Azure NSG should allow traffic between subnets
- No additional proxy/firewall between servers

## Alternative Access Methods

### If PowerShell Remoting Completely Fails
1. **RDP to DC01 first**:
   ```powershell
   # Connect via RDP to dc01, then RDP from dc01 to ca01
   mstsc /v:dc01
   # From dc01 desktop: mstsc /v:ca01
   ```

2. **Azure VM Run Command**:
   ```bash
   # If you have Azure CLI access, run commands directly on VMs
   az vm run-command invoke --resource-group rg-certlc-dev --name ca01 --command-id RunPowerShellScript --scripts "Get-Service | Where-Object {$_.Name -like '*Hybrid*'}"
   ```

3. **Azure Bastion** (if configured):
   - Connect via Azure portal VM blade
   - Use browser-based RDP/SSH

## Success Indicators

### After Service Restart
1. **Services Running**: HealthService and Microsoft Monitoring Agent both "Running"
2. **Azure Portal**: Worker shows as "Online" (may take 5-10 minutes)
3. **Job Execution**: Test jobs run instead of being suspended
4. **Event Logs**: No recent error events related to Hybrid Worker

### Verification Commands
```powershell
# Quick health check
.\Test-HybridWorker-JumpHost.ps1 -TestType Quick

# Detailed service status
.\Manage-HybridWorkerService-JumpHost.ps1 -Action Check -Detailed

# Test a simple automation job from Azure portal
# Job should show "Running" or "Completed", not "Suspended"
```

## Escalation Path

If jump host method doesn't work:
1. **Direct console access** via Azure portal
2. **VM restart** if services are completely hung
3. **Full re-registration** of Hybrid Worker
4. **Azure support** for infrastructure issues

---

**Created**: November 1, 2025  
**Scenario**: CA01 not directly accessible, using DC01 as jump host  
**Estimated Fix Time**: 20-45 minutes via jump host