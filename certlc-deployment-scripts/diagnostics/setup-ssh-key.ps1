# SSH Key Setup Script for Windows Server
# Run this on the Windows server to set up SSH key authentication

Write-Host "=== SSH Key Authentication Setup ===" -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "User: $env:USERNAME" -ForegroundColor Green

# Create .ssh directory
$sshDir = "C:\Users\$env:USERNAME\.ssh"
Write-Host "Creating .ssh directory: $sshDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $sshDir -Force

# The SSH public key to add
$publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007"
$authorizedKeysPath = Join-Path $sshDir "authorized_keys"

Write-Host "Adding SSH public key to authorized_keys..." -ForegroundColor Yellow
Set-Content -Path $authorizedKeysPath -Value $publicKey

# Set proper permissions
Write-Host "Setting proper permissions..." -ForegroundColor Yellow
icacls $authorizedKeysPath /inheritance:r /grant "$env:USERNAME:F" /grant "SYSTEM:F"

# Display the content to verify
Write-Host "Verifying authorized_keys content:" -ForegroundColor Cyan
Get-Content $authorizedKeysPath

# Check SSH service
Write-Host "Checking SSH service..." -ForegroundColor Yellow
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshdService) {
    Write-Host "SSH Service Status: $($sshdService.Status)" -ForegroundColor $(if($sshdService.Status -eq 'Running') { 'Green' } else { 'Red' })
    if ($sshdService.Status -eq 'Running') {
        Write-Host "Restarting SSH service to apply changes..." -ForegroundColor Yellow
        Restart-Service sshd
        Write-Host "✅ SSH service restarted" -ForegroundColor Green
    } else {
        Write-Host "Starting SSH service..." -ForegroundColor Yellow
        Start-Service sshd
        Write-Host "✅ SSH service started" -ForegroundColor Green
    }
} else {
    Write-Host "❌ SSH service not found" -ForegroundColor Red
}

Write-Host "✅ SSH key authentication setup completed!" -ForegroundColor Green
Write-Host "You should now be able to connect without a password using:" -ForegroundColor Cyan
Write-Host "ssh -i ~/.ssh/id_ed25519 demoadmin@<server-ip>" -ForegroundColor White