# Create an Expired Certificate for Testing Certificate Renewal
# This script creates a certificate that expires immediately for testing purposes

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateName = "democert-expired-now",
    
    [Parameter(Mandatory=$false)]
    [int]$ExpiryDaysFromNow = -1  # Negative value = already expired
)

# Import required modules
Import-Module Az.KeyVault

# Create a self-signed certificate that's already expired
$certParams = @{
    Subject = "CN=$CertificateName"
    NotBefore = (Get-Date).AddDays(-10)  # Started 10 days ago
    NotAfter = (Get-Date).AddDays($ExpiryDaysFromNow)  # Expired yesterday
    KeyAlgorithm = "RSA"
    KeyLength = 2048
    KeyUsage = @("DigitalSignature", "KeyEncipherment")
    KeyExportPolicy = "Exportable"
    CertStoreLocation = "Cert:\CurrentUser\My"
}

Write-Host "Creating expired certificate: $CertificateName" -ForegroundColor Yellow
Write-Host "Certificate will be valid from: $($certParams.NotBefore)" -ForegroundColor Gray
Write-Host "Certificate will expire on: $($certParams.NotAfter)" -ForegroundColor Gray

# Create the certificate
$cert = New-SelfSignedCertificate @certParams

# Export the certificate to PFX format
$pfxPath = "$env:TEMP\$CertificateName.pfx"
$password = ConvertTo-SecureString -String "TempPassword123!" -Force -AsPlainText

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password

Write-Host "Certificate exported to: $pfxPath" -ForegroundColor Green

# Import to Key Vault
try {
    Write-Host "Importing expired certificate to Key Vault: $KeyVaultName" -ForegroundColor Yellow
    
    $importResult = Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -FilePath $pfxPath -Password $password
    
    Write-Host "Certificate imported successfully!" -ForegroundColor Green
    Write-Host "Certificate ID: $($importResult.Id)" -ForegroundColor Gray
    Write-Host "Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
    Write-Host "Expires: $($importResult.Expires)" -ForegroundColor Red
    
    # Verify it's expired
    if ($importResult.Expires -lt (Get-Date)) {
        Write-Host "✅ SUCCESS: Certificate is already EXPIRED!" -ForegroundColor Green -BackgroundColor Black
    } else {
        Write-Host "⚠️  WARNING: Certificate is not yet expired" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to import certificate: $($_.Exception.Message)"
}
finally {
    # Clean up temp file
    if (Test-Path $pfxPath) {
        Remove-Item $pfxPath -Force
        Write-Host "Cleaned up temporary file: $pfxPath" -ForegroundColor Gray
    }
}

# Clean up certificate from local store
Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=$CertificateName" } | Remove-Item

Write-Host "`n🎯 Test Instructions:" -ForegroundColor Cyan
Write-Host "1. Check certificate status: az keyvault certificate show --vault-name $KeyVaultName --name $CertificateName" -ForegroundColor White
Write-Host "2. Monitor renewal automation in Azure Automation Account" -ForegroundColor White
Write-Host "3. Check Log Analytics for certificate renewal events" -ForegroundColor White