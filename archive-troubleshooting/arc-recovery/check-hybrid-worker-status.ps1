# Azure PowerShell script to check Hybrid Worker status
# Run this in PowerShell: pwsh check-hybrid-worker-status.ps1

# Load environment variables from .env file
function Load-EnvFile {
    param([string]$Path)
    
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim('"'), 'Process')
            }
        }
        Write-Host "✅ Loaded environment from: $Path" -ForegroundColor Green
    } else {
        Write-Host "❌ Environment file not found: $Path" -ForegroundColor Red
        exit 1
    }
}

# Load configuration
Load-EnvFile "certlc-deployment-scripts/.env"

$resourceGroup = $env:RESOURCE_GROUP
$automationAccount = $env:AUTOMATION_ACCOUNT_NAME

Write-Host "🔍 Checking Hybrid Worker Status" -ForegroundColor Cyan
Write-Host "================================"
Write-Host "Resource Group: $resourceGroup"
Write-Host "Automation Account: $automationAccount"
Write-Host ""

# Check if connected to Azure
try {
    $context = Get-AzContext -ErrorAction Stop
    Write-Host "✅ Connected to Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
} catch {
    Write-Host "❌ Not connected to Azure. Please run: Connect-AzAccount" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 Checking Hybrid Runbook Worker Groups:" -ForegroundColor Yellow
Write-Host "----------------------------------------"

try {
    # Get hybrid worker groups
    $workerGroups = Get-AzAutomationHybridWorkerGroup -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccount
    
    if ($workerGroups.Count -eq 0) {
        Write-Host "❌ No hybrid worker groups found" -ForegroundColor Red
    } else {
        foreach ($group in $workerGroups) {
            Write-Host ""
            Write-Host "Group: $($group.Name)" -ForegroundColor Cyan
            Write-Host "Type: $($group.GroupType)" -ForegroundColor Gray
            
            # Get workers in this group
            $workers = Get-AzAutomationHybridWorker -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccount -HybridWorkerGroupName $group.Name
            
            if ($workers.Count -eq 0) {
                Write-Host "  No workers registered in this group" -ForegroundColor Yellow
            } else {
                Write-Host "  Workers:" -ForegroundColor White
                foreach ($worker in $workers) {
                    $status = if ($worker.LastSeenDateTime -gt (Get-Date).AddMinutes(-10)) { "🟢 ONLINE" } else { "🔴 OFFLINE" }
                    Write-Host "    - Name: $($worker.Name)" -ForegroundColor White
                    Write-Host "      IP: $($worker.Ip)" -ForegroundColor Gray
                    Write-Host "      Last Seen: $($worker.LastSeenDateTime)" -ForegroundColor Gray
                    Write-Host "      Status: $status" -ForegroundColor $(if ($status -match "ONLINE") { "Green" } else { "Red" })
                    Write-Host ""
                }
            }
        }
    }
} catch {
    Write-Host "❌ Error retrieving hybrid worker information: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Alternative: Check manually in Azure Portal:" -ForegroundColor Yellow
    Write-Host "   1. Navigate to: https://portal.azure.com" -ForegroundColor Gray
    Write-Host "   2. Go to: Resource Groups → $resourceGroup → $automationAccount" -ForegroundColor Gray
    Write-Host "   3. Select: Process Automation → Hybrid worker groups" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🕐 Current Time: $(Get-Date)" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ What to look for:" -ForegroundColor Green
Write-Host "   - Worker name containing 'ca01' or your machine name" -ForegroundColor Gray
Write-Host "   - Recent 'Last Seen' time (within last 5-10 minutes)" -ForegroundColor Gray
Write-Host "   - Status showing as ONLINE (green)" -ForegroundColor Gray
Write-Host "   - Correct IP address (10.0.0.5 for ca01)" -ForegroundColor Gray