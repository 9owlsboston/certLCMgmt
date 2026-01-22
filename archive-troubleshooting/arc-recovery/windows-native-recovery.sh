#!/bin/bash

echo "🪟 Windows Native Recovery Script"
echo "================================="
echo "Using Windows-native methods for DC01 → CA01 communication"
echo ""

# Load environment variables
source .env

echo "📊 Step 1: Testing Windows Native Connectivity"
echo "=============================================="

echo "Testing SSH to DC01..."
if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 demoadmin@4.227.115.235 "echo DC01_CONNECTED" 2>/dev/null | grep -q "DC01_CONNECTED"; then
    echo "✅ DC01 SSH connection working"
else
    echo "❌ DC01 SSH connection failed"
    exit 1
fi

echo ""
echo "🔧 Step 2: Creating Windows PowerShell Remoting Script"
echo "====================================================="

# Create a comprehensive PowerShell script for Windows-native communication
cat > windows-arc-recovery.ps1 << 'WINSCRIPT'
# Windows Native Arc Recovery Script
# Uses PowerShell Remoting, WinRM, or direct network commands

param(
    [string]$TargetServer = "10.0.0.5",
    [string]$Username = "demoadmin",
    [string]$TenantId = "",
    [string]$SubscriptionId = "",
    [string]$ResourceGroup = "",
    [switch]$Force
)

Write-Host "🔄 Windows Native Azure Arc Recovery" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Method 1: PowerShell Remoting (WinRM)
Write-Host "`n🌐 Method 1: Testing PowerShell Remoting (WinRM)" -ForegroundColor Yellow
try {
    $session = New-PSSession -ComputerName $TargetServer -Credential (Get-Credential -UserName $Username -Message "Enter password for $Username")
    if ($session) {
        Write-Host "✅ PowerShell Remoting session established" -ForegroundColor Green
        
        # Execute Arc reconnection via PSRemoting
        Invoke-Command -Session $session -ScriptBlock {
            Write-Host "Executing Arc reconnection on CA01..." -ForegroundColor Green
            
            # Stop Azure Arc agent
            Stop-Service -Name himds -Force -ErrorAction SilentlyContinue
            Start-Sleep 5
            
            # Disconnect from Azure Arc
            & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" disconnect --force-local-only
            
            # Reconnect to Azure Arc
            & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect `
                --service-principal-id "your-service-principal-id" `
                --service-principal-secret "your-service-principal-secret" `
                --tenant-id $using:TenantId `
                --subscription-id $using:SubscriptionId `
                --resource-group $using:ResourceGroup `
                --location "East US"
            
            # Start service
            Start-Service -Name himds
            
            Write-Host "Arc reconnection completed" -ForegroundColor Green
        }
        
        Remove-PSSession $session
        Write-Host "✅ PowerShell Remoting method completed" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "❌ PowerShell Remoting failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 2: WMI/CIM Remote Execution
Write-Host "`n🔧 Method 2: Testing WMI/CIM Remote Execution" -ForegroundColor Yellow
try {
    $cimSession = New-CimSession -ComputerName $TargetServer -Credential (Get-Credential -UserName $Username -Message "Enter password for $Username")
    if ($cimSession) {
        Write-Host "✅ CIM session established" -ForegroundColor Green
        
        # Create a script file on the remote machine and execute it
        $scriptContent = @"
Stop-Service -Name himds -Force
Start-Sleep 5
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" disconnect --force-local-only
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$TenantId" --service-principal-secret "secret" --tenant-id "$TenantId" --subscription-id "$SubscriptionId" --resource-group "$ResourceGroup" --location "East US"
Start-Service -Name himds
"@
        
        # Use WMI to execute the script
        $result = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="powershell.exe -Command `"$scriptContent`""}
        
        Remove-CimSession $cimSession
        Write-Host "✅ WMI execution method completed" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "❌ WMI/CIM method failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 3: Direct Network Command via PsExec-style
Write-Host "`n⚡ Method 3: Network Command Execution" -ForegroundColor Yellow
try {
    # Download PsExec if not available
    if (!(Test-Path "C:\temp\PsExec.exe")) {
        Write-Host "Downloading PsExec..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "C:\temp" -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile "C:\temp\PSTools.zip"
        Expand-Archive -Path "C:\temp\PSTools.zip" -DestinationPath "C:\temp" -Force
    }
    
    # Use PsExec for remote execution
    $psexecCmd = "C:\temp\PsExec.exe \\$TargetServer -u $Username -p (password) -i powershell.exe -Command `"& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' disconnect --force-local-only; & 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect --tenant-id $TenantId --subscription-id $SubscriptionId --resource-group $ResourceGroup --location 'East US'`""
    Write-Host "PsExec command prepared (manual password entry required)" -ForegroundColor Yellow
    Write-Host $psexecCmd -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ PsExec method failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 4: Scheduled Task Remote Creation
Write-Host "`n⏰ Method 4: Remote Scheduled Task" -ForegroundColor Yellow
try {
    # Create a scheduled task on the remote machine
    $taskName = "ArcRecovery-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $scriptBlock = "Stop-Service himds -Force; Start-Sleep 5; & 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' disconnect --force-local-only; & 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect --tenant-id $TenantId --subscription-id $SubscriptionId --resource-group $ResourceGroup --location 'East US'; Start-Service himds"
    
    # Use schtasks to create remote scheduled task
    $schtaskCmd = "schtasks /create /tn `"$taskName`" /tr `"powershell.exe -Command `"$scriptBlock`"`" /sc once /st 00:00 /s $TargetServer /u $Username /p (password)"
    $runTaskCmd = "schtasks /run /tn `"$taskName`" /s $TargetServer /u $Username /p (password)"
    
    Write-Host "Scheduled task commands prepared:" -ForegroundColor Yellow
    Write-Host "Create: $schtaskCmd" -ForegroundColor Cyan
    Write-Host "Run: $runTaskCmd" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Scheduled task method failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📋 Summary: Multiple Windows-native methods attempted" -ForegroundColor Cyan
Write-Host "If all automated methods failed, use manual RDP connection:" -ForegroundColor Yellow
Write-Host "mstsc /v:$TargetServer" -ForegroundColor Cyan
WINSCRIPT

echo "✅ Created: windows-arc-recovery.ps1"

echo ""
echo "🚀 Step 3: Execute Windows Native Recovery"
echo "=========================================="

# Upload the script to DC01
echo "Uploading PowerShell script to DC01..."
scp -i ~/.ssh/id_ed25519 windows-arc-recovery.ps1 demoadmin@4.227.115.235:C:/temp/windows-recovery.ps1

echo ""
echo "🎯 Option A: PowerShell Remoting (Recommended)"
echo "============================================="
echo "Executing Windows-native Arc recovery..."

if ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "powershell.exe -ExecutionPolicy Bypass -File C:/temp/windows-recovery.ps1 -TenantId '$AZURE_TENANT_ID' -SubscriptionId '$AZURE_SUBSCRIPTION_ID' -ResourceGroup '$AZURE_RESOURCE_GROUP'" 2>/dev/null; then
    echo "✅ Windows native recovery executed"
else
    echo "❌ Automated execution failed"
fi

echo ""
echo "🎯 Option B: Direct RDP Access"
echo "============================"
echo "If PowerShell Remoting doesn't work, use RDP:"
echo ""
echo "1. SSH to DC01:"
echo "   ssh demoadmin@4.227.115.235"
echo ""
echo "2. From DC01, RDP to CA01:"
echo "   mstsc /v:10.0.0.5"
echo ""
echo "3. On CA01, run PowerShell as Administrator:"
echo "   PowerShell -ExecutionPolicy Bypass -File C:\temp\windows-recovery.ps1"

echo ""
echo "🎯 Option C: WinRM/PowerShell Direct"
echo "==================================="
echo "Enable WinRM on CA01 if not already enabled:"

cat > enable-winrm-ca01.ps1 << 'WINRM_SCRIPT'
# Enable WinRM on CA01 for PowerShell Remoting
Write-Host "Enabling WinRM on CA01..." -ForegroundColor Green

# Enable WinRM
Enable-PSRemoting -Force

# Configure trusted hosts (for same domain)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.0.0.4" -Force

# Start WinRM service
Start-Service WinRM
Set-Service WinRM -StartupType Automatic

# Configure firewall
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

Write-Host "WinRM enabled successfully!" -ForegroundColor Green
Write-Host "You can now use PowerShell Remoting from DC01 to CA01" -ForegroundColor Yellow
WINRM_SCRIPT

scp -i ~/.ssh/id_ed25519 enable-winrm-ca01.ps1 demoadmin@4.227.115.235:C:/temp/enable-winrm.ps1

echo "✅ Created: enable-winrm-ca01.ps1 (uploaded to DC01)"
echo ""
echo "📋 Windows Communication Methods Available:"
echo "=========================================="
echo "🔄 PowerShell Remoting (WinRM) - Most reliable for Windows"
echo "🔧 WMI/CIM Remote Execution - Alternative automation"
echo "⚡ PsExec - Sysinternals remote execution"
echo "⏰ Scheduled Tasks - Remote task creation and execution"
echo "🖥️  RDP - Direct graphical access"
echo ""
echo "All methods avoid SSH key complexity and use native Windows protocols!"