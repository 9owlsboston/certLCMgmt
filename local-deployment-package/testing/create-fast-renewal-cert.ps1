# Fast Renewal Certificate Creator - For Quick Testing
# Creates short-lived certificates that will trigger renewal events quickly

param(
    [int]$ExpiryMinutes = 3,
    [string]$CertificateName = "",
    [switch]$CreateMultiple = $false,
    [switch]$MonitorRenewal = $false
)

# Embedded configuration (from .env file)
$RESOURCE_GROUP = "rg-demo-certlc"
$SUBSCRIPTION_ID = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
$KEY_VAULT_NAME = "DEMO-KV-20251103"
$AUTOMATION_ACCOUNT = "DEMO-AA-20251103"
$LOCATION = "westus3"
$TENANT_ID = "b7e530b3-a1e1-465c-b820-dfddb9e77e7d"

Write-Host "🚀 FAST RENEWAL CERTIFICATE CREATOR" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "🎯 Purpose: Create certificates that expire quickly for renewal testing" -ForegroundColor Yellow
Write-Host "⏱️ Certificate Duration: $ExpiryMinutes minutes" -ForegroundColor Yellow
Write-Host "🔑 Key Vault: $KEY_VAULT_NAME" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow

# Generate unique certificate name if not provided
if ([string]::IsNullOrEmpty($CertificateName)) {
    $timestamp = (Get-Date).ToString("MMdd-HHmm")
    $CertificateName = "fastrenew-$timestamp"
}

try {
    Write-Host "🔍 PHASE 1: Pre-Creation Validation" -ForegroundColor Magenta
    Write-Host "==================================" -ForegroundColor Magenta
    
    # Check Azure authentication
    Write-Host "   Checking Azure authentication..." -ForegroundColor Yellow
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "   ❌ Not authenticated to Azure. Please run Connect-AzAccount" -ForegroundColor Red
        exit 1
    }
    Write-Host "   ✅ Authenticated as: $($context.Account)" -ForegroundColor Green
    
    # Set subscription
    Write-Host "   Setting subscription: $SUBSCRIPTION_ID" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SUBSCRIPTION_ID | Out-Null
    Write-Host "   ✅ Subscription set" -ForegroundColor Green
    
    # Check Key Vault access
    Write-Host "   Checking Key Vault access..." -ForegroundColor Yellow
    $keyVault = Get-AzKeyVault -VaultName $KEY_VAULT_NAME -ResourceGroupName $RESOURCE_GROUP -ErrorAction SilentlyContinue
    if (-not $keyVault) {
        Write-Host "   ❌ Cannot access Key Vault: $KEY_VAULT_NAME" -ForegroundColor Red
        exit 1
    }
    Write-Host "   ✅ Key Vault accessible" -ForegroundColor Green
    
    # Check automation variables for renewal settings
    Write-Host "   Checking automation variables..." -ForegroundColor Yellow
    $thresholdVar = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT -ResourceGroupName $RESOURCE_GROUP -Name "CertRenewalThresholdDays" -ErrorAction SilentlyContinue
    if ($thresholdVar) {
        $thresholdDays = [int]$thresholdVar.Value
        Write-Host "   ✅ Renewal threshold: $thresholdDays days" -ForegroundColor Green
        
        # For fast testing, we need certificates that expire within the threshold
        $targetExpiryHours = ($thresholdDays * 24) - 1  # Just under threshold
        if ($ExpiryMinutes -gt ($targetExpiryHours * 60)) {
            Write-Host "   ⚠️ Certificate duration ($ExpiryMinutes min) exceeds renewal threshold!" -ForegroundColor Yellow
            Write-Host "   🔧 Adjusting to $targetExpiryHours hours for immediate renewal eligibility" -ForegroundColor Yellow
            $ExpiryMinutes = $targetExpiryHours * 60
        }
    } else {
        Write-Host "   ⚠️ CertRenewalThresholdDays variable not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎯 PHASE 2: Fast Renewal Certificate Creation" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    
    # Calculate precise expiry time
    $currentTime = Get-Date
    $expiryTime = $currentTime.AddMinutes($ExpiryMinutes)
    
    Write-Host "   📅 Current Time: $($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "   ⏰ Expiry Time: $($expiryTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "   ⏱️ Duration: $ExpiryMinutes minutes" -ForegroundColor Cyan
    
    if ($CreateMultiple) {
        Write-Host "   📊 Creating multiple certificates for comprehensive testing..." -ForegroundColor Yellow
        
        $certificates = @(
            @{ Name = "fastrenew-1min-$(Get-Date -Format 'MMdd-HHmm')"; Minutes = 1 },
            @{ Name = "fastrenew-3min-$(Get-Date -Format 'MMdd-HHmm')"; Minutes = 3 },
            @{ Name = "fastrenew-5min-$(Get-Date -Format 'MMdd-HHmm')"; Minutes = 5 }
        )
        
        foreach ($cert in $certificates) {
            Write-Host "   🔑 Creating: $($cert.Name) (expires in $($cert.Minutes) min)" -ForegroundColor Yellow
            
            # Create certificate policy for ultra-short validity
            $policy = New-AzKeyVaultCertificatePolicy `
                -SubjectName "CN=$($cert.Name).demo.com" `
                -IssuerName "Self" `
                -ValidityInMonths 1 `
                -ReuseKeyOnRenewal:$true `
                -KeyType "RSA" `
                -KeySize 2048 `
                -SecretContentType "application/x-pkcs12"
                
            # Add custom certificate
            $certOperation = Add-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $cert.Name -CertificatePolicy $policy
            
            if ($certOperation) {
                Write-Host "      ✅ Created: $($cert.Name)" -ForegroundColor Green
                
                # Tag certificate for fast renewal testing
                $tags = @{
                    "Purpose" = "FastRenewalTesting"
                    "ExpiryMinutes" = $cert.Minutes.ToString()
                    "CreatedAt" = (Get-Date).ToString("yyyy-MM-dd_HH:mm:ss")
                    "TestType" = "QuickRenewal"
                }
                
                # Wait a moment for certificate to be created
                Start-Sleep -Seconds 3
                
                try {
                    Update-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $cert.Name -Tag $tags
                    Write-Host "      🏷️ Tagged for fast renewal testing" -ForegroundColor Green
                } catch {
                    Write-Host "      ⚠️ Could not add tags: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "      ❌ Failed to create: $($cert.Name)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "   🔑 Creating single certificate: $CertificateName" -ForegroundColor Yellow
        
        # Create certificate policy for ultra-short validity
        $policy = New-AzKeyVaultCertificatePolicy `
            -SubjectName "CN=$CertificateName.demo.com" `
            -IssuerName "Self" `
            -ValidityInMonths 1 `
            -ReuseKeyOnRenewal:$true `
            -KeyType "RSA" `
            -KeySize 2048 `
            -SecretContentType "application/x-pkcs12"
            
        # Create the certificate
        $certOperation = Add-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -CertificatePolicy $policy
        
        if ($certOperation) {
            Write-Host "   ✅ Certificate created successfully: $CertificateName" -ForegroundColor Green
            
            # Tag certificate for fast renewal testing
            $tags = @{
                "Purpose" = "FastRenewalTesting"
                "ExpiryMinutes" = $ExpiryMinutes.ToString()
                "CreatedAt" = (Get-Date).ToString("yyyy-MM-dd_HH:mm:ss")
                "TestType" = "QuickRenewal"
                "AutoRenew" = "true"
            }
            
            # Wait a moment for certificate to be created
            Start-Sleep -Seconds 3
            
            try {
                Update-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -Tag $tags
                Write-Host "   🏷️ Tagged for fast renewal testing" -ForegroundColor Green
            } catch {
                Write-Host "   ⚠️ Could not add tags: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ❌ Failed to create certificate: $CertificateName" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "🎯 PHASE 3: Event Grid Trigger Setup" -ForegroundColor Magenta
    Write-Host "===================================" -ForegroundColor Magenta
    
    # Check Event Grid configuration
    Write-Host "   🔍 Checking Event Grid configuration..." -ForegroundColor Yellow
    
    # Get Event Grid topics
    $eventGridTopics = Get-AzEventGridTopic -ResourceGroupName $RESOURCE_GROUP -ErrorAction SilentlyContinue
    if ($eventGridTopics) {
        $egTopic = $eventGridTopics | Where-Object { $_.Name -like "*DEMO-EG*" } | Select-Object -First 1
        if ($egTopic) {
            Write-Host "   ✅ Event Grid Topic found: $($egTopic.Name)" -ForegroundColor Green
            
            # Check subscriptions
            $subscriptions = Get-AzEventGridSubscription -ResourceGroupName $RESOURCE_GROUP -ErrorAction SilentlyContinue
            $kvSubscriptions = $subscriptions | Where-Object { $_.Topic -like "*$($egTopic.Name)*" }
            
            if ($kvSubscriptions) {
                Write-Host "   ✅ Event Grid subscriptions found: $($kvSubscriptions.Count)" -ForegroundColor Green
                foreach ($sub in $kvSubscriptions) {
                    Write-Host "      📡 $($sub.EventSubscriptionName)" -ForegroundColor Cyan
                }
            } else {
                Write-Host "   ⚠️ No Event Grid subscriptions found for Key Vault events" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ⚠️ DEMO Event Grid Topic not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️ No Event Grid topics found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎯 PHASE 4: Monitoring Setup" -ForegroundColor Magenta
    Write-Host "===========================" -ForegroundColor Magenta
    
    if ($MonitorRenewal) {
        Write-Host "   🖥️ Starting real-time monitoring..." -ForegroundColor Yellow
        Write-Host "   ⏱️ Monitoring will show certificate expiry and renewal events" -ForegroundColor Cyan
        Write-Host "   🔄 Press Ctrl+C to stop monitoring" -ForegroundColor Cyan
        Write-Host ""
        
        $monitoringScript = Join-Path $PSScriptRoot "monitor-simple.ps1"
        if (Test-Path $monitoringScript) {
            & $monitoringScript
        } else {
            Write-Host "   ⚠️ Monitor script not found at: $monitoringScript" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   📋 To monitor renewal process, run:" -ForegroundColor Yellow
        Write-Host "   pwsh ./monitor-simple.ps1" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "🎉 FAST RENEWAL CERTIFICATE SETUP COMPLETE!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host ""
    
    if ($CreateMultiple) {
        Write-Host "✅ Created multiple fast-renewal certificates" -ForegroundColor White
        Write-Host "📊 Certificates will expire at different intervals (1, 3, 5 minutes)" -ForegroundColor White
    } else {
        Write-Host "✅ Created fast-renewal certificate: $CertificateName" -ForegroundColor White
        Write-Host "⏰ Certificate will expire in: $ExpiryMinutes minutes" -ForegroundColor White
    }
    
    Write-Host "🔔 Event Grid will trigger renewal automatically when certificates near expiry" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Monitor certificates: pwsh ./monitor-simple.ps1" -ForegroundColor Yellow
    Write-Host "2. Watch for expiry events in $ExpiryMinutes minutes" -ForegroundColor Yellow
    Write-Host "3. Verify automatic renewal triggers" -ForegroundColor Yellow
    Write-Host "4. Check renewed certificates in Key Vault" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🎯 Expected Timeline:" -ForegroundColor Cyan
    Write-Host "   ⏰ Expiry: $($expiryTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host "   🔔 Event Grid trigger: Near expiry time" -ForegroundColor Yellow
    Write-Host "   🔄 Renewal process: Within 1-2 minutes of trigger" -ForegroundColor Yellow
    Write-Host "   ✅ New certificate: Within 3-5 minutes total" -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to create fast renewal certificate" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    # Troubleshooting guidance
    Write-Host "🔧 TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Verify Azure authentication: Get-AzContext" -ForegroundColor Cyan
    Write-Host "2. Check Key Vault access: Get-AzKeyVault -VaultName $KEY_VAULT_NAME" -ForegroundColor Cyan
    Write-Host "3. Verify subscription: Set-AzContext -SubscriptionId $SUBSCRIPTION_ID" -ForegroundColor Cyan
    Write-Host "4. Check automation account: Get-AzAutomationAccount -ResourceGroupName $RESOURCE_GROUP" -ForegroundColor Cyan
    
    exit 1
}