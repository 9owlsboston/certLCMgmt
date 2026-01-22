#!/bin/bash

echo "🪟 Simple Windows Arc Recovery"
echo "============================="
echo "Direct approach using RDP for Arc agent reconnection"
echo ""

# Set the environment variables directly
RESOURCE_GROUP="rg-demo-certlc"
SUBSCRIPTION_ID="f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
LOCATION="westus3"

echo "📊 Step 1: Test DC01 Connection"
echo "==============================="

if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 demoadmin@4.227.115.235 "echo DC01_OK" 2>/dev/null | grep -q "DC01_OK"; then
    echo "✅ DC01 connection working"
else
    echo "❌ DC01 connection failed"
    exit 1
fi

echo ""
echo "🔧 Step 2: Create Simple Arc Recovery Script"
echo "============================================"

# Create a simple PowerShell script for Arc reconnection
cat > simple-arc-fix.ps1 << 'SIMPLESCRIPT'
# Simple Azure Arc Recovery Script
# Run this on CA01 (10.0.0.5) as Administrator

Write-Host "🔄 Azure Arc Agent Recovery on CA01" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

$resourceGroup = "rg-demo-certlc"
$subscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
$location = "westus3"

Write-Host "`n📋 Current Arc Agent Status:" -ForegroundColor Yellow
try {
    $status = & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show
    Write-Host $status -ForegroundColor White
} catch {
    Write-Host "Arc agent status check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🔄 Step 1: Stopping Arc Services" -ForegroundColor Yellow
try {
    Stop-Service -Name himds -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Stopped himds service" -ForegroundColor Green
    Start-Sleep 3
} catch {
    Write-Host "⚠️  Service stop warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n🔌 Step 2: Disconnecting from Azure Arc" -ForegroundColor Yellow
try {
    $disconnectResult = & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" disconnect --force-local-only
    Write-Host "✅ Disconnected from Azure Arc" -ForegroundColor Green
    Write-Host $disconnectResult -ForegroundColor White
} catch {
    Write-Host "⚠️  Disconnect warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Start-Sleep 5

Write-Host "`n🔗 Step 3: Reconnecting to Azure Arc" -ForegroundColor Yellow
Write-Host "This will use device authentication..." -ForegroundColor Cyan

try {
    # Use device authentication (interactive)
    $connectResult = & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --subscription-id $subscriptionId `
        --resource-group $resourceGroup `
        --location $location `
        --tenant-id "72f988bf-86f1-41af-91ab-2d7cd011db47"
    
    Write-Host "✅ Reconnection initiated" -ForegroundColor Green
    Write-Host $connectResult -ForegroundColor White
} catch {
    Write-Host "❌ Reconnection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "You may need to run: az login" -ForegroundColor Yellow
}

Write-Host "`n🚀 Step 4: Starting Arc Services" -ForegroundColor Yellow
try {
    Start-Service -Name himds
    Write-Host "✅ Started himds service" -ForegroundColor Green
} catch {
    Write-Host "❌ Service start failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📊 Step 5: Verifying Connection" -ForegroundColor Yellow
Start-Sleep 10
try {
    $finalStatus = & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" show
    Write-Host $finalStatus -ForegroundColor White
    
    if ($finalStatus -like "*Connected*") {
        Write-Host "`n🎉 SUCCESS! Arc agent is reconnected!" -ForegroundColor Green
        Write-Host "Check Azure portal for hybrid worker status in 2-3 minutes" -ForegroundColor Cyan
    } else {
        Write-Host "`n⚠️  Arc agent may still be connecting..." -ForegroundColor Yellow
        Write-Host "Wait 2-3 minutes and check portal" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Status check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📋 Recovery Complete!" -ForegroundColor Cyan
Write-Host "Monitor the hybrid worker in Azure Portal" -ForegroundColor White
SIMPLESCRIPT

echo "✅ Created: simple-arc-fix.ps1"

echo ""
echo "🚀 Step 3: Upload to DC01"
echo "========================="
scp -i ~/.ssh/id_ed25519 simple-arc-fix.ps1 demoadmin@4.227.115.235:C:/temp/arc-fix.ps1
echo "✅ Uploaded to DC01: C:/temp/arc-fix.ps1"

echo ""
echo "🎯 Step 4: Simple Execution Methods"
echo "=================================="

echo ""
echo "🖥️  METHOD A: Direct RDP (Recommended)"
echo "======================================="
echo "1. SSH to DC01:"
echo "   ssh demoadmin@4.227.115.235"
echo ""
echo "2. From DC01 command prompt, RDP to CA01:"
echo "   mstsc /v:10.0.0.5 /admin"
echo ""
echo "3. On CA01, open PowerShell as Administrator and run:"
echo "   C:/temp/arc-fix.ps1"
echo ""
echo "   Or copy/paste from DC01:"
echo "   copy C:\\temp\\arc-fix.ps1 \\\\10.0.0.5\\C$\\temp\\"

echo ""
echo "🔧 METHOD B: Network Copy + Remote Execution"
echo "============================================"
echo "From DC01 PowerShell:"

cat > dc01-commands.txt << 'DC01CMDS'
# Run these commands from DC01 PowerShell

# Copy script to CA01 via network share
copy C:\temp\arc-fix.ps1 \\10.0.0.5\C$\temp\

# Option 1: Use PsExec (if available)
# Download PsExec first if needed
# psexec \\10.0.0.5 -u demoadmin -p <password> powershell.exe -File C:\temp\arc-fix.ps1

# Option 2: Use WMI
$password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("demoadmin", $password)
Invoke-WmiMethod -ComputerName 10.0.0.5 -Credential $credential -Class Win32_Process -Name Create -ArgumentList "powershell.exe -File C:\temp\arc-fix.ps1"

# Option 3: Scheduled Task
schtasks /create /tn "ArcFix" /tr "powershell.exe -File C:\temp\arc-fix.ps1" /sc once /st 23:59 /s 10.0.0.5 /u demoadmin /p YourPassword
schtasks /run /tn "ArcFix" /s 10.0.0.5 /u demoadmin /p YourPassword
DC01CMDS

scp -i ~/.ssh/id_ed25519 dc01-commands.txt demoadmin@4.227.115.235:C:/temp/
echo "✅ Uploaded DC01 commands to: C:/temp/dc01-commands.txt"

echo ""
echo "📋 Quick Summary:"
echo "================"
echo "✅ SSH to DC01 working"
echo "✅ Simple PowerShell script created and uploaded"
echo "🎯 Use RDP from DC01 to CA01 for easiest execution"
echo "🔄 Script will use device authentication (interactive login)"
echo ""
echo "The RDP method is most reliable for Windows-to-Windows Arc recovery!"