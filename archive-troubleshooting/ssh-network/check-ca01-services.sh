#!/bin/bash

echo "🔍 Connecting to CA01 Directly for Hybrid Worker Check"
echo "====================================================="
echo "Issue identified: Previous script connected to DC01 instead of CA01"
echo "Solution: Connect directly to CA01 via PowerShell SSH"
echo ""

echo "🎯 Step 1: Check ca01 services directly"
echo "======================================="

# Connect directly to ca01 and run PowerShell commands
ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 'powershell.exe'" << 'EOF'

Write-Host "🔍 Checking Hybrid Worker Services on CA01" -ForegroundColor Cyan
Write-Host "============================================"

Write-Host "`n1. Checking if Hybrid Worker services exist:" -ForegroundColor Yellow
Get-Service -Name "*HybridWorker*" -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType

Write-Host "`n2. Checking Azure Automation services:" -ForegroundColor Yellow  
Get-Service -Name "*Automation*" -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType

Write-Host "`n3. Checking all Azure-related services:" -ForegroundColor Yellow
Get-Service | Where-Object {$_.Name -like "*Azure*"} | Format-Table Name, Status, StartType

Write-Host "`n4. Checking HybridWorker process:" -ForegroundColor Yellow
Get-Process -Name "*HybridWorker*" -ErrorAction SilentlyContinue | Format-Table Name, Id, CPU, WorkingSet

Write-Host "`n5. Checking network connectivity to Azure:" -ForegroundColor Yellow
Test-NetConnection -ComputerName "management.azure.com" -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded

Write-Host "`n6. Checking if Hybrid Worker directory exists:" -ForegroundColor Yellow
if (Test-Path "C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation") {
    Write-Host "✅ Hybrid Worker directory exists" -ForegroundColor Green
    Get-ChildItem "C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation" -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
} else {
    Write-Host "❌ Traditional Hybrid Worker directory not found" -ForegroundColor Red
}

Write-Host "`n7. Checking Azure Connected Machine Agent:" -ForegroundColor Yellow
if (Test-Path "C:\ProgramData\AzureConnectedMachineAgent") {
    Write-Host "✅ Azure Connected Machine Agent exists" -ForegroundColor Green
    Get-ChildItem "C:\ProgramData\AzureConnectedMachineAgent" -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime
} else {
    Write-Host "❌ Azure Connected Machine Agent not found" -ForegroundColor Red
}

Write-Host "`n8. Checking Windows Event Logs for errors:" -ForegroundColor Yellow
Get-WinEvent -LogName Application -MaxEvents 10 | Where-Object {$_.ProviderName -like "*Azure*" -or $_.Message -like "*HybridWorker*"} | Format-Table TimeCreated, LevelDisplayName, ProviderName, Message -Wrap

Write-Host "`n9. Checking system date/time:" -ForegroundColor Yellow
Get-Date

EOF

echo ""
echo "🎯 Step 2: If services aren't running, let's restart them properly"
echo "================================================================="

cat << 'RESTART_STEPS'

If the above shows services are stopped or missing, run these commands:

# Connect to ca01:
ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 "ssh -i C:\Users\demoadmin\.ssh\id_ed25519 demoadmin@10.0.0.5 'powershell.exe'"

# Then in PowerShell on ca01:
# Restart all Azure/Automation related services
Get-Service | Where-Object {$_.Name -like "*Azure*" -or $_.Name -like "*Automation*" -or $_.Name -like "*HybridWorker*"} | Restart-Service -Force

# Check if Arc agent needs restart
Restart-Service himds -Force

RESTART_STEPS