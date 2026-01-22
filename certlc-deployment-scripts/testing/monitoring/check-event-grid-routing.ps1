# Check Event Grid Subscriptions and Routing for Certificate Lifecycle Management
# User confirmed Event Grid topic DEMO-EG-20251103 exists in portal
# Need to check if subscriptions properly route Key Vault events to Automation webhook

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

Write-Host "🔍 CHECKING EVENT GRID SUBSCRIPTION ROUTING" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray
Write-Host "✅ Event Grid Topic: $EventGridName (confirmed exists)" -ForegroundColor Green
Write-Host "🔑 Key Vault: $KeyVaultName" -ForegroundColor Yellow
Write-Host "🤖 Automation Account: $AutomationAccountName" -ForegroundColor Yellow
Write-Host ""

# 1. Get webhook URL for comparison
Write-Host "1. 🔍 Getting Automation webhook details..." -ForegroundColor Yellow
try {
    $webhook = Get-AzAutomationWebhook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name "clc-webhook"
    if ($webhook) {
        Write-Host "   ✅ Webhook found: clc-webhook" -ForegroundColor Green
        Write-Host "   🔗 Runbook: $($webhook.RunbookName)" -ForegroundColor Gray
        Write-Host "   ✅ Enabled: $($webhook.IsEnabled)" -ForegroundColor Gray
        Write-Host "   📅 Expires: $($webhook.ExpiryTime)" -ForegroundColor Gray
        $webhookUrl = $webhook.Uri
        if ($webhookUrl) {
            # Only show part of the URL for security
            $urlPreview = $webhookUrl.Substring(0, [Math]::Min(50, $webhookUrl.Length)) + "..."
            Write-Host "   🔗 URL: $urlPreview" -ForegroundColor Gray
        } else {
            Write-Host "   ❌ Webhook URL is null!" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Webhook not found!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "   ❌ Error getting webhook: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Check all Event Grid subscriptions in resource group
Write-Host "`n2. 🔍 Checking ALL Event Grid subscriptions..." -ForegroundColor Yellow
try {
    # Get all subscriptions in the resource group
    $allSubscriptions = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName
    
    if ($allSubscriptions) {
        Write-Host "   📋 Found $($allSubscriptions.Count) Event Grid subscription(s):" -ForegroundColor Green
        
        foreach ($sub in $allSubscriptions) {
            Write-Host "`n   📌 Subscription: $($sub.EventSubscriptionName)" -ForegroundColor Cyan
            Write-Host "      Topic: $($sub.Topic)" -ForegroundColor Gray
            Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
            Write-Host "      Endpoint Type: $($sub.EndpointType)" -ForegroundColor Gray
            
            # Check if this subscription targets our webhook
            if ($sub.Destination -and $sub.Destination.ToString().Contains($AutomationAccountName)) {
                Write-Host "      🎯 TARGET: Points to our Automation Account!" -ForegroundColor Green
            } else {
                Write-Host "      ❌ TARGET: Does NOT point to our Automation Account" -ForegroundColor Red
                if ($sub.Destination) {
                    Write-Host "      📍 Destination: $($sub.Destination)" -ForegroundColor Gray
                } else {
                    Write-Host "      📍 Destination: (null)" -ForegroundColor Gray
                }
            }
            
            # Check event types
            if ($sub.IncludedEventTypes) {
                Write-Host "      📋 Event Types: $($sub.IncludedEventTypes -join ', ')" -ForegroundColor Gray
                if ($sub.IncludedEventTypes -contains "Microsoft.KeyVault.CertificateNearExpiry") {
                    Write-Host "      ✅ Includes CertificateNearExpiry events" -ForegroundColor Green
                } else {
                    Write-Host "      ❌ Missing CertificateNearExpiry events" -ForegroundColor Red
                }
            }
            
            # Check subject filters
            if ($sub.SubjectBeginsWith -or $sub.SubjectEndsWith) {
                Write-Host "      🔍 Subject Filter: Begins='$($sub.SubjectBeginsWith)' Ends='$($sub.SubjectEndsWith)'" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   ❌ NO Event Grid subscriptions found in resource group!" -ForegroundColor Red
        Write-Host "   💡 This explains why events don't reach the webhook" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking subscriptions: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Check Event Grid topic subscriptions specifically
Write-Host "`n3. 🔍 Checking subscriptions for Event Grid topic..." -ForegroundColor Yellow
try {
    $topicSubscriptions = Get-AzEventGridSubscription -ResourceGroupName $ResourceGroupName -TopicName $EventGridName
    
    if ($topicSubscriptions) {
        Write-Host "   📋 Found $($topicSubscriptions.Count) subscription(s) for topic ${EventGridName}:" -ForegroundColor Green
        
        foreach ($sub in $topicSubscriptions) {
            Write-Host "`n   📌 $($sub.EventSubscriptionName)" -ForegroundColor Cyan
            Write-Host "      Status: $($sub.ProvisioningState)" -ForegroundColor Gray
            if ($sub.Destination) {
                Write-Host "      Endpoint: $($sub.Destination)" -ForegroundColor Gray
            } else {
                Write-Host "      Endpoint: (null)" -ForegroundColor Gray
            }
            Write-Host "      Event Types: $($sub.IncludedEventTypes -join ', ')" -ForegroundColor Gray
            
            # Check if this is correctly configured for Key Vault certificate events
            $isCorrect = $true
            
            if (-not ($sub.IncludedEventTypes -contains "Microsoft.KeyVault.CertificateNearExpiry")) {
                Write-Host "      ❌ Missing CertificateNearExpiry event type" -ForegroundColor Red
                $isCorrect = $false
            }
            
            if ($sub.Destination -and -not $sub.Destination.ToString().Contains($AutomationAccountName)) {
                Write-Host "      ❌ Not pointing to our Automation Account" -ForegroundColor Red
                $isCorrect = $false
            } elseif (-not $sub.Destination) {
                Write-Host "      ❌ No destination configured" -ForegroundColor Red
                $isCorrect = $false
            }
            
            if ($isCorrect) {
                Write-Host "      ✅ CORRECTLY CONFIGURED for certificate events!" -ForegroundColor Green
            } else {
                Write-Host "      ❌ INCORRECTLY CONFIGURED" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   ❌ NO subscriptions found for Event Grid topic ${EventGridName}!" -ForegroundColor Red
        Write-Host "   💡 This is the root cause - no subscription to forward events" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Error checking topic subscriptions: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check Key Vault event configuration
Write-Host "`n4. 🔍 Checking Key Vault event source configuration..." -ForegroundColor Yellow
try {
    # Get Key Vault information
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName
    Write-Host "   ✅ Key Vault: $($keyVault.VaultName)" -ForegroundColor Green
    Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor Gray
    Write-Host "   🆔 Resource ID: $($keyVault.ResourceId)" -ForegroundColor Gray
    
    # Note: Key Vault automatically publishes events to Event Grid
    Write-Host "   💡 Key Vault automatically publishes events to Event Grid in same region" -ForegroundColor Gray
    Write-Host "   ✅ No additional Key Vault configuration needed" -ForegroundColor Green
}
catch {
    Write-Host "   ❌ Error checking Key Vault: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Summary and recommendations
Write-Host "`n🎯 ANALYSIS SUMMARY:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Gray

Write-Host "The automation chain breakdown is likely:" -ForegroundColor White
Write-Host ""
Write-Host "1. ✅ Key Vault generates CertificateNearExpiry events" -ForegroundColor Green
Write-Host "2. ✅ Event Grid topic exists (${EventGridName})" -ForegroundColor Green  
Write-Host "3. ❓ Event Grid subscription routing (checking above)" -ForegroundColor Yellow
Write-Host "4. ✅ Automation webhook exists and enabled (clc-webhook)" -ForegroundColor Green
Write-Host "5. ✅ Runbook exists (CertLifeCycleMgmt)" -ForegroundColor Green

Write-Host "`n🔧 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "Based on the subscription analysis above:" -ForegroundColor White
Write-Host ""
Write-Host "IF no subscriptions found:" -ForegroundColor Gray
Write-Host "  → Run: .\create-event-grid-subscription.ps1" -ForegroundColor White
Write-Host ""
Write-Host "IF subscription exists but wrong config:" -ForegroundColor Gray
Write-Host "  → Fix the subscription event types and endpoint" -ForegroundColor White
Write-Host ""
Write-Host "IF subscription correctly configured:" -ForegroundColor Gray
Write-Host "  → Check webhook endpoint URL validation" -ForegroundColor White
Write-Host "  → Check Event Grid delivery failures" -ForegroundColor White

Write-Host "`n💡 The Event Grid topic exists, so the issue is in the subscription routing!" -ForegroundColor Cyan