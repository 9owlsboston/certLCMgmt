#!/bin/bash

echo "🔍 Advanced Hybrid Worker Troubleshooting"
echo "========================================"
echo "The worker hasn't checked in after service restart."
echo "Let's investigate deeper..."
echo ""

# Load configuration
source certlc-deployment-scripts/.env

echo "🎯 Step 1: Check if services are actually running on ca01"
echo "======================================================="
echo "Connecting to ca01 via SSH to check service status..."

ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 << 'EOF'
echo "Checking Hybrid Worker services on ca01..."

# Check if services exist and their status
echo ""
echo "1. Checking if Hybrid Worker service exists:"
Get-Service -Name "*HybridWorker*" -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType

echo ""
echo "2. Checking Azure Automation services:"
Get-Service -Name "*Automation*" -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType

echo ""
echo "3. Checking all Azure-related services:"
Get-Service | Where-Object {$_.Name -like "*Azure*"} | Format-Table Name, Status, StartType

echo ""
echo "4. Checking Windows Event Logs for Hybrid Worker errors:"
Get-WinEvent -LogName "Microsoft-Windows-Desired State Configuration/Operational" -MaxEvents 5 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, LevelDisplayName, Message

echo ""
echo "5. Checking Application Event Log for Azure Automation:"
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='*Azure*'} -MaxEvents 5 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, LevelDisplayName, Message

echo ""
echo "6. Checking if Hybrid Worker registration files exist:"
if (Test-Path "C:\ProgramData\AzureConnectedMachineAgent") {
    echo "✅ Azure Connected Machine Agent directory exists"
    Get-ChildItem "C:\ProgramData\AzureConnectedMachineAgent" -Recurse | Select-Object Name, LastWriteTime
} else {
    echo "❌ Azure Connected Machine Agent directory not found"
}

echo ""
echo "7. Checking network connectivity to Azure:"
Test-NetConnection -ComputerName "management.azure.com" -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded

echo ""
echo "8. Checking DNS resolution:"
Resolve-DnsName "management.azure.com" | Select-Object Name, IPAddress
EOF

echo ""
echo "🎯 Step 2: Check Azure Automation Account Configuration"
echo "==================================================="

SUBSCRIPTION_ID=$(az account show --query id --output tsv)

echo "Checking if Automation Account has proper permissions..."

# Check automation account identity
echo "Automation Account Managed Identity:"
az rest \
    --method GET \
    --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT_NAME?api-version=2023-11-01" \
    --query "{Name:name, Identity:identity, State:properties.state}" \
    --output table

echo ""
echo "🎯 Step 3: Manual Hybrid Worker Re-registration"
echo "============================================="
echo "If services are running but not checking in, we may need to re-register the worker."

cat << 'MANUAL_STEPS'

📋 Manual Re-registration Steps (if needed):

1. Connect to ca01 via SSH:
   ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235

2. Download and run the latest Hybrid Worker setup:
   # In PowerShell on ca01:
   
   # Remove existing registration
   Import-Module AzureRM.Automation
   Remove-AzureRmAutomationHybridWorkerGroup -AutomationAccountName "DEMO-AA-1030164500" -ResourceGroupName "rg-demo-certlc" -Name "EnterpriseRootCA"
   
   # Re-register with new method
   $resourceGroup = "rg-demo-certlc"
   $automationAccount = "DEMO-AA-1030164500"
   $workerGroupName = "EnterpriseRootCA"
   
   # Install latest Az modules
   Install-Module -Name Az.Automation -Force -AllowClobber
   
   # Re-register the hybrid worker
   New-AzAutomationHybridWorkerGroup -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccount -Name $workerGroupName

MANUAL_STEPS

echo ""
echo "🎯 Immediate Next Steps:"
echo "1. Review the service status output above"
echo "2. If services aren't running, restart them manually"
echo "3. If services are running but not connecting, check network/firewall"
echo "4. Consider re-registration if all else fails"