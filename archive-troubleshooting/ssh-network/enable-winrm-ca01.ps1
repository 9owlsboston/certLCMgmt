# Enable WinRM on CA01 for PowerShell Remoting
Write-Host "Enabling WinRM on CA01..." -ForegroundColor Green

# Enable WinRM
Enable-PSRemoting -Force

# Configure trusted hosts (for same domain)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.0.0.4" -Force

# Start WinRM service
Start-Service WinRM
Set-Service WinRM -StartupType Automatic

# Configure firewall
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

Write-Host "WinRM enabled successfully!" -ForegroundColor Green
Write-Host "You can now use PowerShell Remoting from DC01 to CA01" -ForegroundColor Yellow
