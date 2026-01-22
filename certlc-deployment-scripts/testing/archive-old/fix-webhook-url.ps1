# Fix Automation Webhook URL Issue for Certificate Lifecycle Management
# The webhook exists but has null URL - need to recreate it

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config) {
    Write-Host "❌ Could not load configuration" -ForegroundColor Red
    exit 1
}

$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']
$WebhookName = "clc-webhook"
$RunbookName = "CertLifeCycleMgmt"

Write-Host "🔧 FIXING AUTOMATION WEBHOOK URL ISSUE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray
Write-Host "🤖 Automation Account: $AutomationAccountName" -ForegroundColor Yellow
Write-Host "🪝 Webhook: $WebhookName" -ForegroundColor Yellow
Write-Host "📋 Runbook: $RunbookName" -ForegroundColor Yellow
Write-Host ""

# Step 1: Check current webhook status
Write-Host "1. 🔍 Checking current webhook status..." -ForegroundColor Yellow
try {
    $existingWebhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $WebhookName -ErrorAction SilentlyContinue
    
    if ($existingWebhook) {
        Write-Host "   ✅ Webhook found: $WebhookName" -ForegroundColor Green
        Write-Host "   🔗 Runbook: $($existingWebhook.RunbookName)" -ForegroundColor Gray
        Write-Host "   ✅ Enabled: $($existingWebhook.IsEnabled)" -ForegroundColor Gray
        Write-Host "   📅 Expires: $($existingWebhook.ExpiryTime)" -ForegroundColor Gray
        
        if ($existingWebhook.Uri) {
            Write-Host "   ✅ URL exists: (hidden for security)" -ForegroundColor Green
            Write-Host "   💡 Webhook URL is not null - may be a PowerShell display issue" -ForegroundColor Yellow
            Write-Host "   🔧 Let's test if the webhook actually works..." -ForegroundColor Yellow
        } else {
            Write-Host "   ❌ URL is NULL - webhook is broken!" -ForegroundColor Red
            Write-Host "   🔧 Need to recreate the webhook" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Webhook not found!" -ForegroundColor Red
        Write-Host "   🔧 Need to create the webhook" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking webhook: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Remove existing webhook if URL is null
if ($existingWebhook -and -not $existingWebhook.Uri) {
    Write-Host "`n2. 🗑️  Removing broken webhook..." -ForegroundColor Yellow
    try {
        Remove-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $WebhookName
        Write-Host "   ✅ Broken webhook removed" -ForegroundColor Green
        $existingWebhook = $null
    }
    catch {
        Write-Host "   ❌ Error removing webhook: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n2. ✅ Webhook URL appears valid, keeping existing webhook" -ForegroundColor Green
}

# Step 3: Create new webhook if needed
if (-not $existingWebhook) {
    Write-Host "`n3. 🚀 Creating new webhook..." -ForegroundColor Yellow
    
    # Set expiry to 1 year from now
    $expiryTime = (Get-Date).AddYears(1)
    
    try {
        $newWebhook = New-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $WebhookName -RunbookName $RunbookName -IsEnabled $true -ExpiryTime $expiryTime -Force
        
        if ($newWebhook -and $newWebhook.Uri) {
            Write-Host "   ✅ New webhook created successfully!" -ForegroundColor Green
            Write-Host "   🔗 Runbook: $($newWebhook.RunbookName)" -ForegroundColor Gray
            Write-Host "   📅 Expires: $($newWebhook.ExpiryTime)" -ForegroundColor Gray
            Write-Host "   🔗 URL: (hidden for security)" -ForegroundColor Gray
            
            # Store webhook URL for Event Grid subscription
            $webhookUrl = $newWebhook.Uri
            Write-Host "   ✅ Webhook URL generated and ready for Event Grid" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Webhook creation failed - no URL generated!" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "   ❌ Error creating webhook: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n3. ✅ Using existing webhook (URL verified)" -ForegroundColor Green
    $webhookUrl = $existingWebhook.Uri
}

# Step 4: Verify webhook functionality
Write-Host "`n4. ✅ Testing webhook configuration..." -ForegroundColor Yellow

try {
    # Re-fetch to confirm
    $finalWebhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $WebhookName
    
    if ($finalWebhook -and $finalWebhook.Uri) {
        Write-Host "   ✅ Webhook URL confirmed: VALID" -ForegroundColor Green
        Write-Host "   ✅ Webhook enabled: $($finalWebhook.IsEnabled)" -ForegroundColor Green
        Write-Host "   ✅ Runbook linked: $($finalWebhook.RunbookName)" -ForegroundColor Green
        Write-Host "   📅 Valid until: $($finalWebhook.ExpiryTime)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Webhook still has no URL!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "   ❌ Error verifying webhook: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 WEBHOOK ISSUE RESOLVED!" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
Write-Host "✅ Webhook '$WebhookName' is now functional" -ForegroundColor Green
Write-Host "✅ URL is valid and ready to receive Event Grid calls" -ForegroundColor Green
Write-Host "✅ Linked to runbook '$RunbookName'" -ForegroundColor Green
Write-Host ""
Write-Host "🔄 NEXT STEP: Create Event Grid subscription" -ForegroundColor Cyan
Write-Host "Run: .\create-event-grid-subscription.ps1" -ForegroundColor White

# Export webhook URL to a secure location for Event Grid subscription
$secureFile = "$PSScriptRoot\.webhook-url.txt"
if ($webhookUrl) {
    $webhookUrl | Out-File -FilePath $secureFile -Encoding UTF8
    Write-Host "`n💾 Webhook URL saved to: $secureFile" -ForegroundColor Gray
    Write-Host "   (This file will be used by Event Grid subscription script)" -ForegroundColor Gray
}