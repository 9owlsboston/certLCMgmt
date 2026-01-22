# Azure Arc Agent Reconnection Script
# Run as Administrator on ca01

param(
    [string]$ResourceGroup = "rg-demo-certlc",
    [string]$TenantId = "b7e530b3-a1e1-465c-b820-dfddb9e77e7d",
    [string]$Location = "westus3", 
    [string]$SubscriptionId = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
)

Write-Host "Starting Azure Arc Agent Reconnection..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$arcAgent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"

# Check if Arc agent exists
if (!(Test-Path $arcAgent)) {
    Write-Host "ERROR: Azure Arc agent not found at $arcAgent" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 1: Current Arc Agent Status" -ForegroundColor Yellow
Write-Host "================================"
try {
    & $arcAgent show
} catch {
    Write-Host "Arc agent show failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 2: Stopping Azure Services" -ForegroundColor Yellow  
Write-Host "==============================="
$services = @("himds", "ExtensionService", "GCArcService")
foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Stop-Service -Name $service -Force
            Write-Host "Stopped service: $service" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning stopping $service : $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 3: Disconnecting Arc Agent" -ForegroundColor Yellow
Write-Host "==============================="
try {
    & $arcAgent disconnect --force-local-only
    Write-Host "Arc agent disconnected successfully" -ForegroundColor Green
} catch {
    Write-Host "Disconnect warning: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 4: Reconnecting Arc Agent" -ForegroundColor Yellow
Write-Host "=============================="
try {
    & $arcAgent connect --resource-group $ResourceGroup --tenant-id $TenantId --location $Location --subscription-id $SubscriptionId
    Write-Host "Arc agent reconnection initiated" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Arc reconnection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Waiting for stabilization..." -ForegroundColor Yellow
Write-Host "===================================="
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Step 6: Starting Azure Services" -ForegroundColor Yellow
Write-Host "==============================="
foreach ($service in $services) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Start-Service -Name $service
            Write-Host "Started service: $service" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning starting $service : $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 7: Final Verification" -ForegroundColor Yellow
Write-Host "========================="
Start-Sleep -Seconds 10
try {
    & $arcAgent show
    Write-Host ""
    Write-Host "SUCCESS: Arc agent reconnection completed!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Final verification failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Recovery process finished. Monitor hybrid worker in Azure portal." -ForegroundColor Cyan
