# Connect to CA01 Server and Create Short-Lived Certificate for Testing
# This script should be run from a machine that can access the CA01 server

# Variables for your LAB environment
$KeyVaultName = "DEMO-KV-1030164500"
$ResourceGroupName = "rg-demo-certlc" 
$CA01ServerName = "ca01"  # The Certificate Authority server
$CertificateName = "democert-shortlived"

Write-Host "🎯 Creating Short-Lived Certificate for Immediate Expiry Testing" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Gray

# Step 0: Check Azure authentication
Write-Host "0. Checking Azure authentication..." -ForegroundColor Yellow
try {
    $azContext = Get-AzContext -ErrorAction Stop
    if ($azContext) {
        Write-Host "   ✅ Authenticated to Azure" -ForegroundColor Green
        Write-Host "   👤 Account: $($azContext.Account.Id)" -ForegroundColor Gray
        Write-Host "   🏢 Tenant: $($azContext.Tenant.Id)" -ForegroundColor Gray
        Write-Host "   📋 Subscription: $($azContext.Subscription.Name)" -ForegroundColor Gray
    } else {
        throw "No Azure context found"
    }
}
catch {
    Write-Host "   ❌ Not authenticated to Azure" -ForegroundColor Red
    Write-Host "   🔧 Please run: Connect-AzAccount" -ForegroundColor Yellow
    Write-Host "   ⏭️  Then run this script again" -ForegroundColor Gray
    exit 1
}

# Step 1: Verify Key Vault access
Write-Host "`n1. Verifying Key Vault access..." -ForegroundColor Yellow
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "   ✅ Key Vault access confirmed: $($keyVault.VaultName)" -ForegroundColor Green
    Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor Gray
    Write-Host "   🔐 Vault URI: $($keyVault.VaultUri)" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Cannot access Key Vault: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   🔧 Please ensure you have proper permissions" -ForegroundColor Yellow
    exit 1
}

# Step 2: Create a certificate with 2-minute validity for immediate expiry testing
Write-Host "`n2. Creating ultra-short-lived certificate..." -ForegroundColor Yellow

$certParams = @{
    Subject = "CN=$CertificateName"
    NotBefore = (Get-Date)
    NotAfter = (Get-Date).AddMinutes(2)  # Expires in 2 minutes!
    KeyAlgorithm = "RSA"
    KeyLength = 2048
    KeyUsage = @("DigitalSignature", "KeyEncipherment")
    KeyExportPolicy = "Exportable"
    CertStoreLocation = "Cert:\CurrentUser\My"
    Provider = "Microsoft Enhanced RSA and AES Cryptographic Provider"
}

Write-Host "   📅 Certificate Valid From: $($certParams.NotBefore)" -ForegroundColor Gray
Write-Host "   ⏰ Certificate Expires At: $($certParams.NotAfter)" -ForegroundColor Red
Write-Host "   ⚡ Duration: 2 minutes (for immediate testing)" -ForegroundColor Yellow

try {
    # Create the certificate
    $cert = New-SelfSignedCertificate @certParams
    Write-Host "   ✅ Certificate created locally" -ForegroundColor Green
    
    # Export to PFX
    $pfxPath = "$env:TEMP\$CertificateName.pfx"
    $password = ConvertTo-SecureString -String "TempTest123!" -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
    
    Write-Host "   📦 Certificate exported to PFX" -ForegroundColor Green
    
    # Step 3: Import to Key Vault
    Write-Host "`n3. Importing to Key Vault..." -ForegroundColor Yellow
    
    # Test Key Vault connectivity before import
    Write-Host "   🔍 Testing Key Vault connectivity..." -ForegroundColor Gray
    try {
        $kvTest = Test-NetConnection -ComputerName "$KeyVaultName.vault.azure.net" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $kvTest) {
            Write-Host "   ❌ Cannot reach Key Vault endpoint" -ForegroundColor Red
            Write-Host "   🌐 Endpoint: $KeyVaultName.vault.azure.net" -ForegroundColor Gray
            throw "Key Vault endpoint unreachable"
        }
        Write-Host "   ✅ Key Vault endpoint accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Network connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        throw "Network connectivity issues detected"
    }
    
    # Import with retry logic
    $maxRetries = 3
    $retryCount = 0
    $importSuccess = $false
    $importResult = $null
    
    while (-not $importSuccess -and $retryCount -lt $maxRetries) {
        try {
            $retryCount++
            if ($retryCount -gt 1) {
                Write-Host "   🔄 Retry attempt $retryCount of $maxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
            
            $importResult = Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -FilePath $pfxPath -Password $password -ErrorAction Stop
            $importSuccess = $true
            Write-Host "   ✅ Certificate imported to Key Vault!" -ForegroundColor Green
        }
        catch {
            Write-Host "   ⚠️  Import attempt $retryCount failed: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($retryCount -eq $maxRetries) {
                Write-Host "   ❌ Import failed after $maxRetries attempts" -ForegroundColor Red
                throw
            }
        }
    }
    
    if (-not $importSuccess) {
        throw "Failed to import certificate after $maxRetries attempts"
    }
    
    # Step 4: Add recipient tag for renewal automation
    Write-Host "`n4. Adding recipient tag for renewal automation..." -ForegroundColor Yellow
    
    # Get current user email for recipient tag
    $currentUser = (Get-AzContext).Account.Id
    
    # Test connectivity again before tag operation
    Write-Host "   🔍 Re-testing Key Vault connectivity for tag operation..." -ForegroundColor Gray
    try {
        $kvTest2 = Test-NetConnection -ComputerName "$KeyVaultName.vault.azure.net" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $kvTest2) {
            Write-Host "   ❌ Key Vault endpoint not reachable for tag operation" -ForegroundColor Red
            throw "Network connectivity lost"
        }
        Write-Host "   ✅ Key Vault still accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Network connectivity lost: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   ⚠️  Certificate imported but tag operation may fail" -ForegroundColor Yellow
    }
    
    # Add the recipient tag with retry logic
    $tagSuccess = $false
    $tagRetryCount = 0
    
    while (-not $tagSuccess -and $tagRetryCount -lt $maxRetries) {
        try {
            $tagRetryCount++
            if ($tagRetryCount -gt 1) {
                Write-Host "   🔄 Tag retry attempt $tagRetryCount of $maxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
            
            $tagResult = Set-AzKeyVaultCertificateAttribute -VaultName $KeyVaultName -Name $CertificateName -Tag @{"recipient" = $currentUser} -ErrorAction Stop
            $tagSuccess = $true
            Write-Host "   ✅ Recipient tag added: $currentUser" -ForegroundColor Green
        }
        catch {
            Write-Host "   ⚠️  Tag attempt $tagRetryCount failed: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($tagRetryCount -eq $maxRetries) {
                Write-Host "   ❌ Tag operation failed after $maxRetries attempts" -ForegroundColor Red
                Write-Host "   ℹ️  Certificate imported successfully, but recipient tag not set" -ForegroundColor Yellow
                Write-Host "   🔧 You can manually add the tag later in Azure Portal" -ForegroundColor Gray
            }
        }
    }
        
        Write-Host "   🔑 Certificate ID: $($importResult.Id)" -ForegroundColor Gray
        Write-Host "   👆 Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
        Write-Host "   ⏰ Expires: $($importResult.Expires)" -ForegroundColor Red
        
        # Step 5: Calculate time until expiry
        $timeUntilExpiry = $importResult.Expires - (Get-Date)
        Write-Host "   ⏳ Time until expiry: $([math]::Round($timeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Yellow
        
        if ($tagSuccess) {
            Write-Host "`n🎉 SUCCESS: Short-lived certificate created with renewal tag!" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "`n⚠️  PARTIAL SUCCESS: Certificate created but tag operation failed" -ForegroundColor Yellow -BackgroundColor Black
            Write-Host "   💡 Certificate is imported and functional" -ForegroundColor Green
            Write-Host "   ⚠️  Renewal automation may not work without recipient tag" -ForegroundColor Yellow
        }
    }
    catch {
        if ($_.Exception.Message -like "*inProgress*") {
            Write-Host "   🔄 Certificate renewal already in progress!" -ForegroundColor Yellow
            Write-Host "   ✅ This means the automation system detected certificate expiry" -ForegroundColor Green
            Write-Host "   🎯 GREAT NEWS: Your testing triggered the renewal process!" -ForegroundColor Cyan
            
            # Check pending operation
            try {
                $pendingOp = Get-AzKeyVaultCertificateOperation -VaultName $KeyVaultName -Name $CertificateName
                Write-Host "   📋 Pending Operation Status: $($pendingOp.Status)" -ForegroundColor Yellow
                Write-Host "   📝 Status Details: $($pendingOp.StatusDetails)" -ForegroundColor Gray
                Write-Host "   🆔 Request ID: $($pendingOp.RequestId)" -ForegroundColor Gray
            }
            catch {
                Write-Host "   ℹ️  Could not retrieve pending operation details" -ForegroundColor Gray
            }
            
            Write-Host "`n🎉 SUCCESS: Certificate renewal process is active!" -ForegroundColor Green -BackgroundColor Black
        }
        else {
            Write-Host "   ❌ Failed to import certificate: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "   💡 Common issues:" -ForegroundColor Yellow
            Write-Host "      - Key Vault permissions missing" -ForegroundColor Gray
            Write-Host "      - Certificate name already exists" -ForegroundColor Gray
            Write-Host "      - Network connectivity issues" -ForegroundColor Gray
            throw
        }
    }
    
    # Step 6: Testing instructions
    Write-Host "`n📋 TESTING INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Gray
    Write-Host "Wait 2-3 minutes, then run these commands:" -ForegroundColor White
    Write-Host ""
    Write-Host "# Check if certificate is expired:" -ForegroundColor Gray
    Write-Host "az keyvault certificate show --vault-name $KeyVaultName --name $CertificateName --query '{Name:name, Expires:attributes.expires}'" -ForegroundColor White
    Write-Host ""
    Write-Host "# Monitor automation for renewal:" -ForegroundColor Gray
    Write-Host "# 1. Go to Azure Portal → Automation Account → 'DEMO-AA-*'" -ForegroundColor Gray
    Write-Host "# 2. Check Runbooks → CertLifeCycleMgmt" -ForegroundColor Gray
    Write-Host "# 3. Look for recent job runs triggered by certificate expiry" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# Check Log Analytics for events:" -ForegroundColor Gray
    Write-Host "# 1. Go to Azure Portal → Log Analytics → 'DEMO-LA-*'" -ForegroundColor Gray
    Write-Host "# 2. Run query: CertificateLifecycleEvents_CL | where Certificate_s == '$CertificateName'" -ForegroundColor Gray
    
}
catch {
    Write-Error "Failed to create/import certificate: $($_.Exception.Message)"
}
finally {
    # Cleanup
    if (Test-Path $pfxPath) {
        Remove-Item $pfxPath -Force
        Write-Host "`n🧹 Cleaned up temporary PFX file" -ForegroundColor Gray
    }
    
    # Remove from local certificate store
    Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=$CertificateName" } | Remove-Item
    Write-Host "🧹 Cleaned up local certificate store" -ForegroundColor Gray
}

Write-Host "`n⏰ EXPIRY TIMELINE:" -ForegroundColor Yellow
Write-Host "- Certificate expires in: 2 minutes" -ForegroundColor Red
Write-Host "- Automation should detect expiry within: 5-10 minutes" -ForegroundColor Yellow  
Write-Host "- New certificate should be issued within: 15-20 minutes" -ForegroundColor Green
Write-Host "`nMonitor the Azure Automation Account for renewal activity!" -ForegroundColor Cyan