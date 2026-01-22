#!/bin/bash

echo "🎯 Direct CA01 Connection & Azure Arc Service Restart"
echo "==================================================="
echo "Issue: SSH key chain not working properly"
echo "Solution: Manual password connection to fix services"
echo ""

echo "📋 Manual Steps to Fix HybridV2 Worker:"
echo "======================================="

cat << 'MANUAL_STEPS'

The hybrid worker is HybridV2 type, which uses Azure Arc. Here's how to fix it:

🔗 Step 1: Connect directly to CA01
===================================
1. SSH to dc01 first:
   ssh demoadmin@4.227.115.235

2. From dc01, RDP or direct connect to ca01:
   - Internal IP: 10.0.0.5
   - Use: mstsc /v:10.0.0.5
   - Login as: demo\demoadmin

🔧 Step 2: Restart Azure Arc Services on CA01
============================================
Once connected to ca01, open PowerShell as Administrator and run:

# Check current service status
Get-Service himds, ExtensionService, GCArcService | Format-Table Name, Status, StartType

# Restart Azure Arc services
Restart-Service himds -Force
Restart-Service ExtensionService -Force -ErrorAction SilentlyContinue  
Restart-Service GCArcService -Force -ErrorAction SilentlyContinue

# Verify services are running
Get-Service himds, ExtensionService, GCArcService | Format-Table Name, Status, StartType

# Check Arc agent status
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show

🔍 Step 3: Verify Network Connectivity
====================================
# Test connectivity to Azure Arc endpoints
Test-NetConnection -ComputerName "gbl.his.arc.azure.com" -Port 443
Test-NetConnection -ComputerName "management.azure.com" -Port 443

# Check system time (important for SSL certificates)
Get-Date

🔄 Step 4: If Arc Agent is Disconnected, Reconnect
================================================
If azcmagent show indicates the agent is disconnected:

& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --resource-group "rg-demo-certlc" `
  --tenant-id "b7e530b3-a1e1-465c-b820-dfddb9e77e7d" `
  --location "westus3" `
  --subscription-id "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"

MANUAL_STEPS

echo ""
echo "⚡ Quick Alternative - Use our monitoring script:"
echo "================================================"
echo "./monitor-hybrid-worker.sh"
echo ""
echo "This will check every 30 seconds if the worker comes online"
echo "after you manually restart the services above."
echo ""

echo "🎯 Why Manual Connection is Needed:"
echo "- SSH key authentication failed between dc01 → ca01"  
echo "- HybridV2 workers depend on Azure Arc agent (himds service)"
echo "- Arc agent likely stopped and needs manual restart"
echo "- Once services restart, worker should check in within 5 minutes"

echo ""
echo "✅ Success Indicators:"
echo "- himds service Status: Running"
echo "- azcmagent show: Connected state"
echo "- Network tests: TcpTestSucceeded = True"
echo "- Azure portal: Worker shows 'Connected' status"