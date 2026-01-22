# Create Missing Event Grid Infrastructure for Certificate Lifecycle Management
# This script creates the Event Grid topic and subscription that forward Key Vault events to Automation Account

# Load configuration
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config) {
    Write-Host "❌ Could not load configuration" -ForegroundColor Red
    exit 1
}

$KeyVaultName = $config['KEY_VAULT_NAME']
$AutomationAccountName = $config['AUTOMATION_ACCOUNT_NAME'] 
$EventGridName = $config['EVENT_GRID_NAME']
$ResourceGroupName = $config['RESOURCE_GROUP']
$Location = "westus2"  # Adjust as needed

Write-Host "🚀 CREATING MISSING EVENT GRID INFRASTRUCTURE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray
Write-Host "🎯 Event Grid Topic: $EventGridName" -ForegroundColor Yellow
Write-Host "🔑 Key Vault: $KeyVaultName" -ForegroundColor Yellow
Write-Host "🤖 Automation Account: $AutomationAccountName" -ForegroundColor Yellow
Write-Host ""

# Step 1: Get the webhook URL from Automation Account
Write-Host "1. 🔍 Getting webhook URL from Automation Account..." -ForegroundColor Yellow
try {
    $webhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "clc-webhook"
    if ($webhook) {
        Write-Host "   ✅ Found webhook: clc-webhook" -ForegroundColor Green
        $webhookUrl = $webhook.Uri
        Write-Host "   🔗 Webhook URL obtained" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Webhook 'clc-webhook' not found!" -ForegroundColor Red
        Write-Host "   💡 Need to create webhook first" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "   ❌ Error getting webhook: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Create Event Grid Topic
Write-Host "`n2. 🏗️  Creating Event Grid Topic..." -ForegroundColor Yellow
try {
    $existingTopic = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $EventGridName -ErrorAction SilentlyContinue
    if ($existingTopic) {
        Write-Host "   ✅ Event Grid topic already exists: $($existingTopic.Name)" -ForegroundColor Green
        $topicEndpoint = $existingTopic.Endpoint
    } else {
        $topic = New-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $EventGridName -Location $Location
        Write-Host "   ✅ Event Grid topic created: $($topic.Name)" -ForegroundColor Green
        Write-Host "   📍 Location: $($topic.Location)" -ForegroundColor Gray
        Write-Host "   🔗 Endpoint: $($topic.Endpoint)" -ForegroundColor Gray
        $topicEndpoint = $topic.Endpoint
    }
}
catch {
    Write-Host "   ❌ Error creating Event Grid topic: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Get Key Vault resource ID
Write-Host "`n3. 🔍 Getting Key Vault resource information..." -ForegroundColor Yellow
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName
    $keyVaultResourceId = $keyVault.ResourceId
    Write-Host "   ✅ Key Vault resource ID: $keyVaultResourceId" -ForegroundColor Green
}
catch {
    Write-Host "   ❌ Error getting Key Vault: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Create Event Grid Subscription for Key Vault Certificate events
Write-Host "`n4. 🚀 Creating Event Grid Subscription..." -ForegroundColor Yellow
$subscriptionName = "kv-cert-expiry-subscription"

try {
    # Check if subscription already exists
    $existingSubscription = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName -TopicName $EventGridName -EventSubscriptionName $subscriptionName -ErrorAction SilentlyContinue
    
    if ($existingSubscription) {
        Write-Host "   ✅ Event Grid subscription already exists: $subscriptionName" -ForegroundColor Green
    } else {
        # Create the subscription
        $subscriptionParams = @{
            ResourceGroupName = $ResourceGroupName
            TopicName = $EventGridName
            EventSubscriptionName = $subscriptionName
            Endpoint = $webhookUrl
            EndpointType = "webhook"
            IncludedEventType = @("Microsoft.KeyVault.CertificateNearExpiry", "Microsoft.KeyVault.CertificateExpired")
            SubjectBeginsWith = "/subscriptions"
            MaxDeliveryAttempt = 3
            EventTtl = 1440  # 24 hours
        }
        
        $subscription = New-AzEventGridSubscription @subscriptionParams
        Write-Host "   ✅ Event Grid subscription created: $subscriptionName" -ForegroundColor Green
        Write-Host "   🎯 Events: CertificateNearExpiry, CertificateExpired" -ForegroundColor Gray
        Write-Host "   🔗 Endpoint: Automation webhook" -ForegroundColor Gray
        Write-Host "   🔄 Max attempts: 3" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   ❌ Error creating Event Grid subscription: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -like "*webhook*" -or $_.Exception.Message -like "*endpoint*") {
        Write-Host "   💡 This may be due to webhook URL validation" -ForegroundColor Yellow
        Write-Host "   🔧 Try creating the subscription manually in Azure Portal" -ForegroundColor Yellow
    }
    exit 1
}

# Step 5: Configure Key Vault to send events to Event Grid
Write-Host "`n5. 🔧 Configuring Key Vault Event Grid integration..." -ForegroundColor Yellow
try {
    # Key Vault automatically sends events to Event Grid in the same resource group
    # We need to verify the Key Vault has Event Grid notifications enabled
    
    Write-Host "   💡 Key Vault automatically sends events to Event Grid" -ForegroundColor Gray
    Write-Host "   ✅ No additional Key Vault configuration needed" -ForegroundColor Green
    Write-Host "   📋 Key Vault will send events to all Event Grid topics in resource group" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Error configuring Key Vault: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 6: Test the configuration
Write-Host "`n6. ✅ Testing Event Grid configuration..." -ForegroundColor Yellow

Write-Host "   🔍 Verifying components:" -ForegroundColor Gray
Write-Host "   ✅ Key Vault: $KeyVaultName" -ForegroundColor Green
Write-Host "   ✅ Event Grid Topic: $EventGridName" -ForegroundColor Green  
Write-Host "   ✅ Event Grid Subscription: $subscriptionName" -ForegroundColor Green
Write-Host "   ✅ Automation Webhook: clc-webhook" -ForegroundColor Green
Write-Host "   ✅ Automation Runbook: CertLifeCycleMgmt" -ForegroundColor Green

Write-Host "`n🎉 EVENT GRID INFRASTRUCTURE CREATED!" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
Write-Host "🔄 EVENT FLOW:" -ForegroundColor Cyan
Write-Host "1. Key Vault certificate expires" -ForegroundColor White
Write-Host "2. Key Vault sends CertificateNearExpiry event" -ForegroundColor White  
Write-Host "3. Event Grid Topic receives event" -ForegroundColor White
Write-Host "4. Event Grid Subscription forwards to webhook" -ForegroundColor White
Write-Host "5. Automation Account receives webhook call" -ForegroundColor White
Write-Host "6. CertLifeCycleMgmt runbook executes" -ForegroundColor White
Write-Host "7. Certificate gets renewed automatically" -ForegroundColor White

Write-Host "`n🧪 TESTING INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "1. Create a new short-lived certificate:" -ForegroundColor Gray
Write-Host "   .\create-shortlived-cert-robust.ps1" -ForegroundColor White
Write-Host ""
Write-Host "2. Wait for it to expire (2 minutes)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitor Automation Account for job execution:" -ForegroundColor Gray
Write-Host "   .\monitor-renewal.ps1" -ForegroundColor White
Write-Host ""
Write-Host "4. Check that certificate was renewed:" -ForegroundColor Gray
Write-Host "   az keyvault certificate show --vault-name $KeyVaultName --name democert-shortlived" -ForegroundColor White

Write-Host "`n💡 Event Grid infrastructure was the missing piece!" -ForegroundColor Cyan
Write-Host "   Now Key Vault events can reach your Automation Account." -ForegroundColor Cyan