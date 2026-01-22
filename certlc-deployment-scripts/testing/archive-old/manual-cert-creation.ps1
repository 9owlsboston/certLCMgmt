# Manual Certificate Creation Script for LAB Environment
# Run this on CA01 server if democert was not created automatically

param(
    [Parameter(Mandatory)]
    [String]$keyVaultName,
    
    [Parameter(Mandatory)]
    [String]$Recipient = "your-email@domain.com"
)

# Set variables
$demoCertDNSName = "democert.demo.com"
$certificateName = "democert"
$pfxFilePath = "C:\Temp\Script\democert.pfx"
$pfxPassword = ConvertTo-SecureString -String "PFXPasswordDEMO" -Force -AsPlainText

# Create temp directory if it doesn't exist
New-Item -Path "C:\Temp\Script" -ItemType Directory -Force

Write-Host "Creating certificate request..."
try {
    # Request certificate from CA using the webservershort template
    $cert = Get-Certificate -Template webservershort -DnsName $demoCertDNSName -SubjectName "CN=democert" -CertStoreLocation cert:\LocalMachine\My
    
    if ($cert.Certificate) {
        Write-Host "Certificate created successfully. Thumbprint: $($cert.Certificate.Thumbprint)"
        
        # Export certificate to PFX
        Write-Host "Exporting certificate to PFX..."
        Get-ChildItem -Path "cert:\localMachine\my\$($cert.Certificate.Thumbprint)" | Export-PfxCertificate -FilePath $pfxFilePath -Password $pfxPassword
        
        # Connect to Azure using managed identity
        Write-Host "Connecting to Azure..."
        Connect-AzAccount -Identity
        
        # Import certificate to Key Vault
        Write-Host "Importing certificate to Key Vault: $keyVaultName"
        $newCert = Import-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName -FilePath $pfxFilePath -Password $pfxPassword
        
        # Set recipient tag
        Write-Host "Setting recipient tag: $Recipient"
        $tag = @{"recipient" = $Recipient}
        $newCert | Update-AzKeyVaultCertificate -Tag $tag
        
        Write-Host "Certificate successfully created and imported to Key Vault!"
        Write-Host "Certificate Name: $certificateName"
        Write-Host "Key Vault: $keyVaultName"
        Write-Host "Recipient: $Recipient"
        
    } else {
        Write-Error "Failed to create certificate. Check CA templates and permissions."
    }
    
} catch {
    Write-Error "Error during certificate creation: $($_.Exception.Message)"
    Write-Host "Checking prerequisites..."
    
    # Check if CA is running
    $caService = Get-Service -Name "CertSvc" -ErrorAction SilentlyContinue
    if ($caService -and $caService.Status -eq "Running") {
        Write-Host "✓ Certificate Authority service is running"
    } else {
        Write-Warning "✗ Certificate Authority service is not running"
    }
    
    # Check if template exists
    try {
        $template = Get-CATemplate -Name "webservershort" -ErrorAction SilentlyContinue
        if ($template) {
            Write-Host "✓ Certificate template 'webservershort' exists"
        } else {
            Write-Warning "✗ Certificate template 'webservershort' not found"
        }
    } catch {
        Write-Warning "Could not check certificate templates"
    }
    
    # Check Azure connectivity
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-Host "✓ Azure context available"
        } else {
            Write-Warning "✗ No Azure context. Try running Connect-AzAccount -Identity"
        }
    } catch {
        Write-Warning "Could not check Azure context"
    }
}