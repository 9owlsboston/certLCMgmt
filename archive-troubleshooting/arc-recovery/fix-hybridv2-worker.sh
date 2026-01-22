#!/bin/bash

echo "🎯 HybridV2 Worker Troubleshooting (Azure Arc-based)"
echo "=================================================="
echo "Worker Type: HybridV2 (Azure Arc Connected Machine)"
echo "VM Resource: ca01 in rg-demo-certlc"
echo "Registration Date: 2025-10-31T00:01:38"
echo "Last Seen: 2025-10-31T08:27:23 (OFFLINE)"
echo ""

echo "🔍 Step 1: Check Azure Arc Agent Status on CA01"
echo "==============================================="

# Connect to ca01 via jump host and check Arc agent
ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 << 'OUTER_EOF'

echo "Connecting to CA01 to check Azure Arc agent..."
ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 "powershell.exe -Command \"
Write-Host 'Checking Azure Connected Machine Agent on CA01' -ForegroundColor Cyan;
Write-Host '=============================================' -ForegroundColor Cyan;

Write-Host '';
Write-Host '1. Azure Arc Agent Service Status:' -ForegroundColor Yellow;
Get-Service -Name 'himds' | Format-Table Name, Status, StartType;

Write-Host '';  
Write-Host '2. Hybrid Instance Metadata Service:' -ForegroundColor Yellow;
Get-Service -Name 'himds' | Select-Object Name, Status, StartType | Format-List;

Write-Host '';
Write-Host '3. Azure Arc Agent Configuration:' -ForegroundColor Yellow;
if (Test-Path 'C:\\\\Program Files\\\\AzureConnectedMachineAgent\\\\azcmagent.exe') {
    Write-Host '✅ Azure Arc agent executable found' -ForegroundColor Green;
    & 'C:\\\\Program Files\\\\AzureConnectedMachineAgent\\\\azcmagent.exe' show;
} else {
    Write-Host '❌ Azure Arc agent not found' -ForegroundColor Red;
}

Write-Host '';
Write-Host '4. Extension Manager Service:' -ForegroundColor Yellow;
Get-Service -Name 'ExtensionService' -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType;

Write-Host '';
Write-Host '5. Guest Configuration Service:' -ForegroundColor Yellow;  
Get-Service -Name 'GCArcService' -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType;

Write-Host '';
Write-Host '6. Network connectivity to Azure Arc endpoints:' -ForegroundColor Yellow;
Test-NetConnection -ComputerName 'gbl.his.arc.azure.com' -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded;
Test-NetConnection -ComputerName 'management.azure.com' -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded;

Write-Host '';
Write-Host '7. System Time (important for certificate validation):' -ForegroundColor Yellow;
Get-Date;

Write-Host '';
Write-Host '8. Recent Application Event Logs for Azure Arc:' -ForegroundColor Yellow;
Get-WinEvent -LogName Application -MaxEvents 10 | Where-Object {\\$_.ProviderName -like '*Azure*' -or \\$_.ProviderName -like '*Arc*' -or \\$_.ProviderName -like '*himds*'} | Format-Table TimeCreated, LevelDisplayName, ProviderName, Message -Wrap;
\""

OUTER_EOF

echo ""
echo "🎯 Step 2: Restart Azure Arc Services if needed"
echo "==============================================="

cat << 'RESTART_INSTRUCTIONS'

If services are stopped or having issues, restart them:

# Connect to ca01:
ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235
ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 "powershell.exe"

# In PowerShell on ca01:
Restart-Service himds -Force
Restart-Service ExtensionService -Force -ErrorAction SilentlyContinue
Restart-Service GCArcService -Force -ErrorAction SilentlyContinue

# Check Arc agent status
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show

# Reconnect Arc agent if needed
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect --resource-group "rg-demo-certlc" --tenant-id "b7e530b3-a1e1-465c-b820-dfddb9e77e7d" --location "westus3" --subscription-id "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"

RESTART_INSTRUCTIONS

echo ""
echo "🎯 Key Points for HybridV2 Workers:"
echo "- Uses Azure Connected Machine Agent (Arc), not traditional Automation services"
echo "- Primary service: himds (Hybrid Instance Metadata Service)"
echo "- Requires connectivity to Azure Arc endpoints"  
echo "- Registration tied to VM's Arc agent connection"
echo "- If Arc agent is disconnected, hybrid worker goes offline"