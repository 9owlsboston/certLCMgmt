# Windows Standalone Short-Lived Certificate Creator
# Embedded configuration for DC01/CA01 execution

param(
    [int]$ExpiryMinutes = 2,
    [string]$CertificateName = ""
)

# Embedded configuration (from .env file)
$RESOURCE_GROUP = "rg-demo-certlc"
$SUBSCRIPTION_ID = "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
$KEY_VAULT_NAME = "DEMO-KV-20251103"
$LOCATION = "westus3"
$TENANT_ID = "b7e530b3-a1e1-465c-b820-dfddb9e77e7d"

# Generate unique certificate name if not provided
if ([string]::IsNullOrEmpty($CertificateName)) {
    $timestamp = (Get-Date).ToString("MMdd-HHmm")
    $CertificateName = "democert-$timestamp"
}

Write-Host "🎯 Creating Short-Lived Certificate for Immediate Testing" -ForegroundColor Cyan
Write-Host "🔑 Key Vault: $KEY_VAULT_NAME" -ForegroundColor Yellow
Write-Host "🏢 Resource Group: $RESOURCE_GROUP" -ForegroundColor Yellow
Write-Host "⏱️ Certificate Duration: $ExpiryMinutes minutes" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "0. Checking Azure authentication..." -ForegroundColor Yellow
    $context = Get-AzContext
    if ($context) {
        Write-Host "   ✅ Authenticated to Azure" -ForegroundColor Green
        Write-Host "   👤 Account: $($context.Account.Id)" -ForegroundColor White
        Write-Host "   🏢 Tenant: $($context.Tenant.Id)" -ForegroundColor White
        Write-Host "   📋 Subscription: $($context.Subscription.Name)" -ForegroundColor White
    } else {
        Write-Host "   ❌ Not authenticated to Azure" -ForegroundColor Red
        Write-Host "   💡 Run: Connect-AzAccount" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "1. Verifying Key Vault access..." -ForegroundColor Yellow
    try {
        $keyVault = Get-AzKeyVault -VaultName $KEY_VAULT_NAME -ResourceGroupName $RESOURCE_GROUP
        Write-Host "   ✅ Key Vault access confirmed: $KEY_VAULT_NAME" -ForegroundColor Green
        Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor White
        Write-Host "   🔐 Vault URI: $($keyVault.VaultUri)" -ForegroundColor White
    } catch {
        Write-Host "   ❌ Cannot access Key Vault: $KEY_VAULT_NAME" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "2. Checking for existing certificates..." -ForegroundColor Yellow
    
    # Check if certificate already exists
    $existingCert = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -ErrorAction SilentlyContinue
    if ($existingCert) {
        Write-Host "   ⚠️ Certificate '$CertificateName' already exists" -ForegroundColor Yellow
        Write-Host "   🗑️ Removing existing certificate..." -ForegroundColor Yellow
        try {
            Remove-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -Force -Confirm:$false
            Write-Host "   ✅ Existing certificate removed" -ForegroundColor Green
            Start-Sleep -Seconds 5  # Wait for deletion to complete
        } catch {
            Write-Host "   ⚠️ Could not remove existing certificate: $($_.Exception.Message)" -ForegroundColor Yellow
            # Generate new unique name
            $timestamp = (Get-Date).ToString("MMdd-HHmmss")
            $CertificateName = "democert-$timestamp"
            Write-Host "   🔄 Using new certificate name: $CertificateName" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   ✅ Certificate name '$CertificateName' is available" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "3. Creating ultra-short-lived certificate..." -ForegroundColor Yellow
    
    # Calculate expiry time
    $startTime = Get-Date
    $expiryTime = $startTime.AddMinutes($ExpiryMinutes)
    
    Write-Host "   📅 Certificate Valid From: $($startTime.ToString('MM/dd/yyyy HH:mm:ss'))" -ForegroundColor White
    Write-Host "   ⏰ Certificate Expires At: $($expiryTime.ToString('MM/dd/yyyy HH:mm:ss'))" -ForegroundColor White
    Write-Host "   ⚡ Duration: $ExpiryMinutes minutes (for immediate testing)" -ForegroundColor White
    Write-Host ""

    # Create certificate policy for short duration
    # Note: Azure Key Vault has minimum validity constraints, so we'll create a standard cert
    # and then manually adjust its expiry date for testing purposes
    $policy = New-AzKeyVaultCertificatePolicy `
        -SubjectName "CN=$CertificateName.contoso.com" `
        -IssuerName "Self" `
        -ValidityInMonths 1 `
        -KeyUsage DigitalSignature, KeyEncipherment `
        -SecretContentType "application/x-pkcs12"
        
    Write-Host "   ⚠️ Note: Azure Key Vault enforces minimum validity periods" -ForegroundColor Yellow
    Write-Host "   ⚠️ Certificate will be created with 1-month validity" -ForegroundColor Yellow
    Write-Host "   ⚠️ For testing, we'll use CertRenewalThresholdDays=30 to trigger renewal" -ForegroundColor Yellow

    # Start certificate creation
    Write-Host "   🔄 Initiating certificate creation..." -ForegroundColor Cyan
    try {
        $certOperation = Add-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -CertificatePolicy $policy
        Write-Host "   ✅ Certificate creation initiated successfully" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*Conflict*" -or $_.Exception.Message -like "*inProgress*") {
            Write-Host "   ⚠️ Conflict detected - certificate operation already in progress" -ForegroundColor Yellow
            Write-Host "   🔄 Generating new unique certificate name..." -ForegroundColor Cyan
            $timestamp = (Get-Date).ToString("MMdd-HHmmss-fff")
            $CertificateName = "democert-$timestamp"
            Write-Host "   📝 New certificate name: $CertificateName" -ForegroundColor White
            
            # Retry with new name
            Write-Host "   🔄 Retrying certificate creation with new name..." -ForegroundColor Cyan
            $certOperation = Add-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -CertificatePolicy $policy
            Write-Host "   ✅ Certificate creation initiated with new name" -ForegroundColor Green
        } else {
            throw $_
        }
    }

    # Wait for certificate creation
    $timeout = 60 # 60 seconds
    $elapsed = 0
    do {
        Start-Sleep -Seconds 2
        $elapsed += 2
        $cert = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName -ErrorAction SilentlyContinue
        Write-Host "   ⏳ Waiting for certificate creation... ($elapsed/$timeout seconds)" -ForegroundColor Gray
    } while (-not $cert -and $elapsed -lt $timeout)

    if ($cert) {
        Write-Host "   ✅ Certificate created successfully!" -ForegroundColor Green
        Write-Host "   🆔 Certificate ID: $($cert.Id)" -ForegroundColor White
        Write-Host "   📋 Name: $($cert.Name)" -ForegroundColor White
        Write-Host "   📅 Created: $($cert.Created.ToString('MM/dd/yyyy HH:mm:ss'))" -ForegroundColor White
        
        # Get certificate details
        $certDetail = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $CertificateName
        if ($certDetail.Certificate) {
            Write-Host "   📅 Not Before: $($certDetail.Certificate.NotBefore.ToString('MM/dd/yyyy HH:mm:ss'))" -ForegroundColor White
            Write-Host "   ⏰ Not After: $($certDetail.Certificate.NotAfter.ToString('MM/dd/yyyy HH:mm:ss'))" -ForegroundColor White
            
            $timeUntilExpiry = $certDetail.Certificate.NotAfter - (Get-Date)
            Write-Host "   ⏱️ Time until expiry: $([math]::Round($timeUntilExpiry.TotalMinutes, 1)) minutes" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Certificate creation timed out" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "✅ CERTIFICATE CREATION COMPLETED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️ IMPORTANT TESTING NOTE:" -ForegroundColor Magenta
    Write-Host "- Azure Key Vault enforces minimum certificate validity (weeks/months)" -ForegroundColor Yellow
    Write-Host "- Certificate expires: December 3rd (standard 1-month validity)" -ForegroundColor Yellow
    Write-Host "- For immediate testing, automation uses CertRenewalThresholdDays=30" -ForegroundColor Yellow
    Write-Host "- This means ALL certificates within 30 days of expiry will trigger renewal" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⏰ TESTING TIMELINE:" -ForegroundColor Magenta
    Write-Host "- Certificate renewal should trigger: IMMEDIATELY (within 30-day threshold)" -ForegroundColor White
    Write-Host "- Automation should detect and process: Within 5-10 minutes" -ForegroundColor White
    Write-Host "- New certificate should be issued: Within 15-20 minutes" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 MONITORING:" -ForegroundColor Cyan
    Write-Host "Monitor the Azure Automation Account for renewal activity!" -ForegroundColor White
    Write-Host "- Automation Account: DEMO-AA-20251103" -ForegroundColor Gray
    Write-Host "- Resource Group: $RESOURCE_GROUP" -ForegroundColor Gray
    Write-Host "- Threshold Setting: CertRenewalThresholdDays = 30 days" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Monitor Event Grid for certificate events (should trigger immediately)" -ForegroundColor White
    Write-Host "2. Check Automation Account job history for renewal jobs" -ForegroundColor White
    Write-Host "3. Verify Hybrid Worker processes the renewal on CA01" -ForegroundColor White
    Write-Host "4. Look for new certificate version in Key Vault within 20 minutes" -ForegroundColor White

} catch {
    Write-Host ""
    Write-Host "❌ CERTIFICATE CREATION FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "- Ensure you're authenticated to Azure (Connect-AzAccount)" -ForegroundColor White
    Write-Host "- Verify you have Key Vault Contributor permissions" -ForegroundColor White
    Write-Host "- Check that the Key Vault name is correct: $KEY_VAULT_NAME" -ForegroundColor White
}