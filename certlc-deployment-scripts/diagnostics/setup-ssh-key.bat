@echo off
REM SSH Key Setup Batch File for Windows Server
REM Copy this file to the Windows server and run it as Administrator

echo === SSH Key Authentication Setup ===
echo Server: %COMPUTERNAME%
echo User: %USERNAME%

REM Create .ssh directory
echo Creating .ssh directory...
mkdir "C:\Users\%USERNAME%\.ssh" 2>nul

REM Create authorized_keys file with the SSH public key
echo Adding SSH public key to authorized_keys...
echo ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007 > "C:\Users\%USERNAME%\.ssh\authorized_keys"

REM Set proper permissions using icacls
echo Setting proper permissions...
icacls "C:\Users\%USERNAME%\.ssh\authorized_keys" /inheritance:r /grant "%USERNAME%:F" /grant "SYSTEM:F"

REM Restart SSH service
echo Restarting SSH service...
net stop sshd
net start sshd

echo.
echo === Setup Completed ===
echo SSH key authentication should now be working
echo Test with: ssh -i ~/.ssh/id_ed25519 demoadmin@server-ip
echo.
pause