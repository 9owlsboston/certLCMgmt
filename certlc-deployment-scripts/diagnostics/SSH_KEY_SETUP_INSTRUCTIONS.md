# Manual SSH Key Setup Instructions

## Option 1: Copy-Paste Method (Recommended)

1. **Connect to the Windows server via SSH:**
   ```bash
   ssh demoadmin@4.227.115.235
   ```

2. **Once connected, run these PowerShell commands one by one:**
   ```powershell
   # Create .ssh directory
   New-Item -ItemType Directory -Path "C:\Users\demoadmin\.ssh" -Force
   
   # Create authorized_keys file with your public key
   Set-Content -Path "C:\Users\demoadmin\.ssh\authorized_keys" -Value "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007"
   
   # Set proper permissions
   icacls "C:\Users\demoadmin\.ssh\authorized_keys" /inheritance:r /grant "demoadmin:F" /grant "SYSTEM:F"
   
   # Restart SSH service
   Restart-Service sshd
   
   # Verify the setup
   Get-Content "C:\Users\demoadmin\.ssh\authorized_keys"
   ```

## Option 2: Using the Batch File

1. **Copy the setup-ssh-key.bat file to the Windows server**
2. **Run it as Administrator on the Windows server**

## Option 3: Single Command Method

If you want to try the single command approach again:

```bash
ssh demoadmin@4.227.115.235 'powershell.exe -Command "New-Item -ItemType Directory -Path \"C:\\Users\\demoadmin\\.ssh\" -Force; Set-Content -Path \"C:\\Users\\demoadmin\\.ssh\\authorized_keys\" -Value \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007\"; icacls \"C:\\Users\\demoadmin\\.ssh\\authorized_keys\" /inheritance:r /grant \"demoadmin:F\" /grant \"SYSTEM:F\"; Restart-Service sshd"'
```

## Testing After Setup

Once you've set up the SSH key, test it with:
```bash
ssh -i ~/.ssh/id_ed25519 demoadmin@4.227.115.235 'echo "SSH key authentication successful"'
```

## Your SSH Public Key (for reference):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMJvFQzmQf14DCydHzGzv5TLpqLPonSU7fs7++A44+q6 certlc-admin@MSSDPSLS007
```