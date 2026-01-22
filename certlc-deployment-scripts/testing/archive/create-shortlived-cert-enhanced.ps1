# Enhanced Short-Lived Certificate Creation with Proper Error Handling
# This version includes better error handling and network connectivity checks

# Variables for your LAB environment
$KeyVaultName = "DEMO-KV-1030164500"
$ResourceGroupName = "rg-demo-certlc" 
$CertificateName = "democert-shortlived"

Write-Host "🎯 Creating Short-Lived Certificate for Immediate Expiry Testing (Enhanced)" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Gray

# Function to test network connectivity
function Test-KeyVaultConnectivity {
    param($KeyVaultName)
    
    $fqdn = "$KeyVaultName.vault.azure.net"
    
    Write-Host "🔍 Testing Key Vault connectivity..." -ForegroundColor Yellow
    
    # Test DNS Resolution
    try {
        $dnsResult = Resolve-DnsName -Name $fqdn -ErrorAction Stop
        Write-Host "   ✅ DNS Resolution: $($dnsResult.IPAddress)" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ DNS Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test TCP Connectivity
    try {
        $tcpTest = Test-NetConnection -ComputerName $fqdn -Port 443 -InformationLevel Quiet
        if ($tcpTest) {
            Write-Host "   ✅ TCP 443 connectivity successful" -ForegroundColor Green
        } else {
            Write-Host "   ❌ TCP 443 connectivity failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "   ❌ Network connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Step 0: Test connectivity before proceeding
if (-not (Test-KeyVaultConnectivity -KeyVaultName $KeyVaultName)) {
    Write-Host "`n❌ CONNECTIVITY ISSUE DETECTED" -ForegroundColor Red -BackgroundColor Black
    Write-Host "Please run the network troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. ipconfig /flushdns" -ForegroundColor White
    Write-Host "2. Check firewall/proxy settings" -ForegroundColor White
    Write-Host "3. Verify internet connectivity" -ForegroundColor White
    Write-Host "4. Try accessing Azure Portal in browser" -ForegroundColor White
    exit 1
}

# Step 1: Verify Key Vault access with enhanced error handling
Write-Host "`n1. Verifying Key Vault access..." -ForegroundColor Yellow
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "   ✅ Key Vault access confirmed: $($keyVault.VaultName)" -ForegroundColor Green
    Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor Gray
    Write-Host "   🔐 Vault URI: $($keyVault.VaultUri)" -ForegroundColor Gray
    Write-Host "   🏢 Resource Group: $($keyVault.ResourceGroupName)" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Key Vault access failed: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Forbidden*") {
        Write-Host "   💡 Permission issue - check Key Vault access policies" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*not found*") {
        Write-Host "   💡 Key Vault not found - check name '$KeyVaultName'" -ForegroundColor Yellow
    } else {
        Write-Host "   💡 Network or authentication issue" -ForegroundColor Yellow
    }
    exit 1
}

# Step 2: Create certificate (same as before)
Write-Host "`n2. Creating ultra-short-lived certificate..." -ForegroundColor Yellow

$certParams = @{
    Subject = "CN=$CertificateName"
    NotBefore = (Get-Date)
    NotAfter = (Get-Date).AddMinutes(2)
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

$cert = $null
$pfxPath = $null

try {
    # Create the certificate
    $cert = New-SelfSignedCertificate @certParams
    Write-Host "   ✅ Certificate created locally" -ForegroundColor Green
    Write-Host "   👆 Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    
    # Export to PFX
    $pfxPath = "$env:TEMP\$CertificateName.pfx"
    $password = ConvertTo-SecureString -String "TempTest123!" -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
    Write-Host "   📦 Certificate exported to PFX: $pfxPath" -ForegroundColor Green
    
    # Step 3: Import to Key Vault with retry logic
    Write-Host "`n3. Importing to Key Vault..." -ForegroundColor Yellow
    
    $maxRetries = 3
    $retryCount = 0
    $importSuccess = $false
    $importResult = $null
    
    while ($retryCount -lt $maxRetries -and -not $importSuccess) {
        try {
            if ($retryCount -gt 0) {
                Write-Host "   🔄 Retry attempt $retryCount of $maxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
            
            $importResult = Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -FilePath $pfxPath -Password $password -ErrorAction Stop
            $importSuccess = $true
            Write-Host "   ✅ Certificate imported to Key Vault!" -ForegroundColor Green
        }
        catch {
            $retryCount++
            Write-Host "   ⚠️ Import attempt $retryCount failed: $($_.Exception.Message)" -ForegroundColor Yellow
            
            if ($retryCount -eq $maxRetries) {
                Write-Host "   ❌ All import attempts failed" -ForegroundColor Red
                throw $_
            }
        }
    }
    
    if ($importSuccess -and $importResult) {
        # Step 4: Add recipient tag with enhanced error handling
        Write-Host "`n4. Adding recipient tag for renewal automation..." -ForegroundColor Yellow
        
        try {
            $currentUser = (Get-AzContext).Account.Id
            
            # Test connectivity again before setting attributes
            if (Test-KeyVaultConnectivity -KeyVaultName $KeyVaultName) {
                $tagResult = Set-AzKeyVaultCertificateAttribute -VaultName $KeyVaultName -Name $CertificateName -Tag @{"recipient" = $currentUser} -ErrorAction Stop
                
                Write-Host "   ✅ Recipient tag added: $currentUser" -ForegroundColor Green
                Write-Host "   🔑 Certificate ID: $($importResult.Id)" -ForegroundColor Gray
                Write-Host "   👆 Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
                Write-Host "   ⏰ Expires: $($importResult.Expires)" -ForegroundColor Red
                
                # Calculate time until expiry
                $timeUntilExpiry = $importResult.Expires - (Get-Date)
                Write-Host "   ⏳ Time until expiry: $([math]::Round($timeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Yellow
                
                Write-Host "`n🎉 SUCCESS: Short-lived certificate created with renewal tag!" -ForegroundColor Green -BackgroundColor Black
            } else {
                Write-Host "   ❌ Network connectivity issue - cannot add recipient tag" -ForegroundColor Red
                Write-Host "   💡 Certificate was imported but tags were not added" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "   ❌ Failed to add recipient tag: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($_.Exception.Message -like "*inProgress*") {
                Write-Host "   🔄 Certificate renewal already in progress!" -ForegroundColor Yellow
                Write-Host "   ✅ This means the automation system detected certificate expiry" -ForegroundColor Green
            } elseif ($_.Exception.Message -like "*could not be resolved*") {
                Write-Host "   🌐 Network connectivity issue - DNS resolution failed" -ForegroundColor Red
            }
        }
    }
    
    # Testing instructions
    Write-Host "`n📋 TESTING INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Gray
    Write-Host "Certificate created successfully. Next steps:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Wait 2-3 minutes for expiry" -ForegroundColor Gray
    Write-Host "2. Check certificate status:" -ForegroundColor Gray
    Write-Host "   az keyvault certificate show --vault-name $KeyVaultName --name $CertificateName" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Monitor automation in Azure Portal:" -ForegroundColor Gray
    Write-Host "   - Automation Account → Runbooks → CertLifeCycleMgmt" -ForegroundColor Gray
    Write-Host "   - Log Analytics → Query: CertificateLifecycleEvents_CL" -ForegroundColor Gray
    
}
catch {
    Write-Host "`n❌ CERTIFICATE CREATION FAILED" -ForegroundColor Red -BackgroundColor Black
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*could not be resolved*") {
        Write-Host "`n🔧 NETWORK TROUBLESHOOTING:" -ForegroundColor Yellow
        Write-Host "1. Run: ipconfig /flushdns" -ForegroundColor White
        Write-Host "2. Check internet connectivity" -ForegroundColor White
        Write-Host "3. Verify firewall/proxy settings" -ForegroundColor White
        Write-Host "4. Test: ping $KeyVaultName.vault.azure.net" -ForegroundColor White
    }
}
finally {
    # Enhanced cleanup
    Write-Host "`n🧹 Cleanup..." -ForegroundColor Gray
    
    if ($pfxPath -and (Test-Path $pfxPath)) {
        Remove-Item $pfxPath -Force
        Write-Host "   ✅ Cleaned up temporary PFX file" -ForegroundColor Gray
    }
    
    if ($cert) {
        Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $cert.Thumbprint } | Remove-Item
        Write-Host "   ✅ Cleaned up local certificate store" -ForegroundColor Gray
    }
}

Write-Host "`n⏰ TESTING TIMELINE:" -ForegroundColor Yellow
Write-Host "- Certificate expires in: 2 minutes" -ForegroundColor Red
Write-Host "- Automation should detect within: 5-10 minutes" -ForegroundColor Yellow  
Write-Host "- New certificate issued within: 15-20 minutes" -ForegroundColor Green