# Install SSH public key on CA01
param(
    [string]$PublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007"
)

Write-Host "Installing SSH public key on CA01..." -ForegroundColor Green

# Create .ssh directory
$sshDir = "C:\Users\demoadmin\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Host "Created directory: $sshDir" -ForegroundColor Yellow
}

# Write public key to authorized_keys
$authorizedKeysFile = "$sshDir\authorized_keys"
$PublicKey | Out-File -FilePath $authorizedKeysFile -Encoding ascii -NoNewline
Write-Host "Installed public key to: $authorizedKeysFile" -ForegroundColor Green

# Set proper permissions
icacls $authorizedKeysFile /inheritance:r /grant "demoadmin:F" /grant "SYSTEM:F"
Write-Host "Set permissions on authorized_keys file" -ForegroundColor Green

# Display the file content to verify
Write-Host "`nVerifying authorized_keys content:" -ForegroundColor Cyan
Get-Content $authorizedKeysFile

# Restart SSH service
Write-Host "`nRestarting SSH service..." -ForegroundColor Yellow
Restart-Service sshd

Write-Host "`nSSH key installation complete!" -ForegroundColor Green
