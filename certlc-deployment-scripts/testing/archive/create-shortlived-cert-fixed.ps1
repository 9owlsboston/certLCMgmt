# Fixed Script - Run from Internet-Connected Machine (NOT from CA01)
# This script creates certificates and manages them remotely

# Variables for your LAB environment
$KeyVaultName = "DEMO-KV-1030164500"
$ResourceGroupName = "rg-demo-certlc" 
$CA01ServerName = "ca01"  # Referenced but not used for execution
$CertificateName = "democert-shortlived"

Write-Host "🎯 Creating Short-Lived Certificate (Remote Execution)" -ForegroundColor Cyan
Write-Host "⚠️  NOTE: Run this from an internet-connected machine, NOT from CA01" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Gray

# Check if running from CA01 (warn user)
$computerName = $env:COMPUTERNAME
if ($computerName -eq "CA01") {
    Write-Host "❌ WARNING: You're running this from CA01 server!" -ForegroundColor Red
    Write-Host "   CA01 likely doesn't have internet access" -ForegroundColor Yellow
    Write-Host "   Please run this script from your workstation or jump box" -ForegroundColor Yellow
    Write-Host "   Press Ctrl+C to cancel, or Enter to continue anyway..." -ForegroundColor Gray
    Read-Host
}

# Test internet connectivity first
Write-Host "`n0. Testing internet connectivity..." -ForegroundColor Yellow
try {
    $testResult = Test-NetConnection -ComputerName "login.microsoftonline.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($testResult) {
        Write-Host "   ✅ Internet connectivity confirmed" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No internet connectivity detected" -ForegroundColor Red
        Write-Host "   💡 This machine cannot reach Azure services" -ForegroundColor Yellow
        Write-Host "   🔧 Please run from an internet-connected machine" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "   ❌ Network connectivity test failed" -ForegroundColor Red
    Write-Host "   💡 Please check internet connection and try again" -ForegroundColor Yellow
    exit 1
}

# Test Azure Key Vault connectivity
Write-Host "`n0.1. Testing Azure Key Vault connectivity..." -ForegroundColor Yellow
try {
    $kvTest = Test-NetConnection -ComputerName "$KeyVaultName.vault.azure.net" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($kvTest) {
        Write-Host "   ✅ Key Vault endpoint accessible" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Cannot reach Key Vault endpoint" -ForegroundColor Red
        Write-Host "   🌐 Endpoint: $KeyVaultName.vault.azure.net" -ForegroundColor Gray
        exit 1
    }
}
catch {
    Write-Host "   ❌ Key Vault connectivity test failed" -ForegroundColor Red
    exit 1
}

# Rest of the script continues as before...
# Step 1: Verify Key Vault access
Write-Host "`n1. Verifying Key Vault access..." -ForegroundColor Yellow
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName
    Write-Host "   ✅ Key Vault access confirmed: $($keyVault.VaultName)" -ForegroundColor Green
    Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor Gray
    Write-Host "   🔐 Vault URI: $($keyVault.VaultUri)" -ForegroundColor Gray
}
catch {
    Write-Error "Cannot access Key Vault. Please ensure you have proper permissions."
    Write-Host "💡 Make sure you're authenticated: Connect-AzAccount" -ForegroundColor Yellow
    exit 1
}

# Step 2: Create certificate (same as original)
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
Write-Host "   💻 Created on: $($env:COMPUTERNAME)" -ForegroundColor Gray

try {
    # Create the certificate
    $cert = New-SelfSignedCertificate @certParams
    Write-Host "   ✅ Certificate created locally" -ForegroundColor Green
    
    # Export to PFX
    $pfxPath = "$env:TEMP\$CertificateName.pfx"
    $password = ConvertTo-SecureString -String "TempTest123!" -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
    
    Write-Host "   📦 Certificate exported to PFX" -ForegroundColor Green
    
    # Step 3: Import to Key Vault (this requires internet access)
    Write-Host "`n3. Importing to Key Vault..." -ForegroundColor Yellow
    
    try {
        $importResult = Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -FilePath $pfxPath -Password $password
        Write-Host "   ✅ Certificate imported to Key Vault!" -ForegroundColor Green
        
        # Step 4: Add recipient tag for renewal automation
        Write-Host "`n4. Adding recipient tag for renewal automation..." -ForegroundColor Yellow
        
        # Get current user email for recipient tag
        $currentUser = (Get-AzContext).Account.Id
        
        # Add the recipient tag that's required for certificate renewal
        $tagResult = Set-AzKeyVaultCertificateAttribute -VaultName $KeyVaultName -Name $CertificateName -Tag @{"recipient" = $currentUser}
        
        Write-Host "   ✅ Recipient tag added: $currentUser" -ForegroundColor Green
        Write-Host "   🔑 Certificate ID: $($importResult.Id)" -ForegroundColor Gray
        Write-Host "   👆 Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
        Write-Host "   ⏰ Expires: $($importResult.Expires)" -ForegroundColor Red
        
        # Step 5: Calculate time until expiry
        $timeUntilExpiry = $importResult.Expires - (Get-Date)
        Write-Host "   ⏳ Time until expiry: $([math]::Round($timeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Yellow
        
        Write-Host "`n🎉 SUCCESS: Short-lived certificate created with renewal tag!" -ForegroundColor Green -BackgroundColor Black
        
        # Connection info
        Write-Host "`n🌐 CONNECTIVITY INFO:" -ForegroundColor Cyan
        Write-Host "   📡 Executed from: $($env:COMPUTERNAME)" -ForegroundColor Gray
        Write-Host "   🌍 Internet access: Required and confirmed" -ForegroundColor Green
        Write-Host "   🔐 Key Vault: Accessible from this machine" -ForegroundColor Green
        Write-Host "   ⚠️  CA01 server: Isolated (no internet access)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "`n❌ AZURE OPERATIONS FAILED" -ForegroundColor Red -BackgroundColor Black
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Message -like "*could not be resolved*") {
            Write-Host "`n🔧 NETWORK ISSUE DETECTED:" -ForegroundColor Yellow
            Write-Host "   - DNS resolution failed for Key Vault" -ForegroundColor White
            Write-Host "   - This machine may not have internet access" -ForegroundColor White
            Write-Host "   - Try running from your workstation instead" -ForegroundColor White
        }
        throw
    }
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

Write-Host "`n📋 ARCHITECTURE NOTES:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Gray
Write-Host "CA01 Server (Isolated):" -ForegroundColor Yellow
Write-Host "- No internet access (security best practice)" -ForegroundColor Gray
Write-Host "- Generates certificates locally" -ForegroundColor Gray
Write-Host "- Cannot directly access Azure services" -ForegroundColor Gray
Write-Host ""
Write-Host "Internet-Connected Machine (This script):" -ForegroundColor Yellow
Write-Host "- Can access Azure Key Vault" -ForegroundColor Gray
Write-Host "- Manages certificate storage and lifecycle" -ForegroundColor Gray
Write-Host "- Triggers automation workflows" -ForegroundColor Gray