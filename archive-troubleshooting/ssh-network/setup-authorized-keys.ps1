# PowerShell script to run on Windows server after SSH login
# Copy and paste these commands one by one

Write-Host "Setting up SSH authorized_keys for passwordless authentication..." -ForegroundColor Green

# Create .ssh directory
$sshDir = "C:\Users\demoadmin\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Host "Created directory: $sshDir" -ForegroundColor Yellow
}

# Your public key (single line)
$publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007"

# Write public key to authorized_keys
$authorizedKeysFile = "$sshDir\authorized_keys"
$publicKey | Out-File -FilePath $authorizedKeysFile -Encoding ascii -NoNewline
Write-Host "Created authorized_keys file with your public key" -ForegroundColor Yellow

# Set proper permissions (critical for SSH to accept the key)
icacls $authorizedKeysFile /inheritance:r /grant "demoadmin:F" /grant "SYSTEM:F"
Write-Host "Set proper permissions on authorized_keys file" -ForegroundColor Yellow

# Display the file content to verify
Write-Host "`nVerifying authorized_keys content:" -ForegroundColor Cyan
Get-Content $authorizedKeysFile

# Restart SSH service to pick up changes
Write-Host "`nRestarting SSH service..." -ForegroundColor Green
Restart-Service sshd

Write-Host "`nSSH key setup complete! Exit this session and test passwordless login." -ForegroundColor Green