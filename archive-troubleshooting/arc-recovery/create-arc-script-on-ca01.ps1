# Create the Arc recovery script directly on CA01
# Run this in PowerShell on CA01

$scriptContent = @'
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
'@

# Create temp directory if it doesn't exist
New-Item -ItemType Directory -Path "C:\temp" -Force -ErrorAction SilentlyContinue

# Save the script
$scriptContent | Out-File -FilePath "C:\temp\arc-fix.ps1" -Encoding UTF8

Write-Host "✅ Created C:\temp\arc-fix.ps1" -ForegroundColor Green
Write-Host "Now run: C:\temp\arc-fix.ps1" -ForegroundColor Cyan