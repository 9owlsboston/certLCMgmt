# SSH PowerShell Remoting Setup Guide

## Overview
This guide helps you set up PowerShell remoting over SSH to connect from Linux to Windows servers (dc01 and ca01) in your certificate lifecycle management environment.

## Why SSH Instead of WSMan?
- SSH remoting is fully supported cross-platform (Linux ↔ Windows) in PowerShell 7+
- WSMan on non-Windows platforms has limitations
- SSH provides better security and flexibility

## Prerequisites
- PowerShell 7+ installed on both Linux and Windows
- Admin access to Windows servers (dc01 and ca01)
- Network connectivity between systems

## Part 1: Windows Server Configuration

### Step 1: Install OpenSSH Server
Run on each Windows server (dc01 and ca01):

```powershell
# Check if OpenSSH Server is available
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and enable SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm SSH is running
Get-Service sshd
```

### Step 2: Configure PowerShell Subsystem
Edit `C:\ProgramData\ssh\sshd_config` and add:

```
Subsystem powershell C:/Program Files/PowerShell/7/pwsh.exe -sshs -NoLogo
```

### Step 3: Restart SSH Service
```powershell
Restart-Service sshd
```

### Step 4: Configure Firewall
```powershell
# Allow SSH through Windows Firewall
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

## Part 2: Linux Client Configuration

### Step 1: Generate SSH Key (if not exists)
```bash
ssh-keygen -t ed25519 -C "certlc-admin@$(hostname)"
```

### Step 2: Copy Public Key to Windows Servers
```bash
# For each server, copy your public key
ssh-copy-id administrator@dc01
ssh-copy-id administrator@ca01
```

### Step 3: Test SSH Connectivity
```bash
ssh administrator@dc01
ssh administrator@ca01
```

## Part 3: PowerShell SSH Remoting

### From PowerShell on Linux:
```powershell
# Interactive session
Enter-PSSession -HostName dc01 -UserName administrator

# Run remote commands
Invoke-Command -HostName dc01 -UserName administrator -ScriptBlock { Get-Service }

# With key authentication
Enter-PSSession -HostName dc01 -UserName administrator -KeyFilePath ~/.ssh/id_ed25519
```

## Server Information
Based on your environment configuration:

- **Domain Controller (Jump Host)**: dc01 (IP: likely 10.0.0.4)
- **Certificate Authority**: ca01 (IP: 10.0.0.5)
- **Resource Group**: rg-demo-certlc
- **Subscription**: f8c6ec45-4437-4670-80b1-cc3cb09c3ce0

## Next Steps
1. Configure SSH on Windows servers
2. Test SSH connectivity
3. Update jump host scripts to use SSH remoting
4. Test hybrid worker service management

## Troubleshooting
- Ensure PowerShell 7+ is installed on Windows
- Check Windows Firewall settings
- Verify SSH service is running
- Test network connectivity: `Test-NetConnection dc01 -Port 22`