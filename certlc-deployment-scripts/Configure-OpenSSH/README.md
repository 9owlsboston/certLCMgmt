# Configure SSH on an **Azure Windows Server**,

### ✅ **1. Install OpenSSH Server**

Run PowerShell as **Administrator**:

```powershell
# Check if OpenSSH is available
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

***

### ✅ **2. Start and Enable SSH Service**

```powershell
# Start the SSH service
Start-Service sshd

# Set it to start automatically
Set-Service -Name sshd -StartupType 'Automatic'
```

***

### ✅ **3. Allow SSH in Windows Firewall**

```powershell
# Add firewall rule for SSH
New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
    -DisplayName "OpenSSH Server (TCP-In)" `
    -Enabled True -Direction Inbound `
    -Protocol TCP -Action Allow -LocalPort 22
```

***

### ✅ **4. Verify SSH Service**

```powershell
Get-Service sshd
```

It should show **Status: Running**.

***

### ✅ **5. Add SSH Key (Optional for Key-based Auth)**

Place your public key in:

    C:\Users\<YourUsername>\.ssh\authorized_keys

***

### ✅ **6. Connect via SSH**

From your client:

```bash
ssh <username>@<public-ip>
```

***

#### ⚠ Common Issues:

*   If `Start-Service sshd` fails with **ObjectNotFound**, the OpenSSH Server feature wasn’t installed correctly.
*   Ensure the VM’s **NSG** allows inbound TCP on port 22.
*   For Azure Bastion alternative, you can use **Azure Bastion SSH** without exposing port 22.

***

Got it—here’s a **single, idempotent PowerShell script** that sets up **SSH key-based authentication** on a Windows Server (including Azure VMs). It:

*   Installs OpenSSH Server if missing
*   Adds your public key to the right place with correct ACLs
*   Updates `sshd_config` to enable Pubkey auth (and optionally disable passwords)
*   Handles the special case where the **“Match Group administrators”** block is active (uses `administrators_authorized_keys`)
*   Starts and enables the `sshd` service and opens the firewall

> **Usage examples (run as Administrator on the server):**
>
> *   Use a public key string you paste:
>     ```powershell
>     .\Configure-OpenSSHKeyAuth.ps1 -PublicKey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI.... user@machine" -TargetUser "AzureUser" -DisablePasswordAuth
>     ```
> *   Use a public key file (copied to server):
>     ```powershell
>     .\Configure-OpenSSHKeyAuth.ps1 -PublicKeyPath "C:\Temp\id_ed25519.pub" -TargetUser "AzureUser"
>     ```
> *   If neither parameter is provided, it will try reading your clipboard.

***

## `Configure-OpenSSHKeyAuth.ps1`

```powershell
<#
.SYNOPSIS
    Configure OpenSSH key-based login for a local/domain/AAD user on Windows Server.

.DESCRIPTION
    - Ensures OpenSSH Server is installed, service is running (Auto), and firewall allows TCP/22.
    - Places the provided public key into the correct authorized_keys file with strict ACLs.
    - Enables PubkeyAuthentication; optionally disables PasswordAuthentication.
    - If 'Match Group administrators' is active, ALWAYS creates/populates
      C:\ProgramData\ssh\administrators_authorized_keys with strict ACLs.

.PARAMETER PublicKey
    SSH public key string (e.g., 'ssh-ed25519 AAAA... user@host').

.PARAMETER PublicKeyPath
    Path to a .pub file containing the SSH public key.

.PARAMETER TargetUser
    Account to configure (accepts 'User', '.\User', 'COMPUTER\User', 'DOMAIN\User', 'AzureAD\User').
    Defaults to the current user if omitted.

.PARAMETER DisablePasswordAuth
    When set, enforces 'PasswordAuthentication no' in sshd_config.

.NOTES
    Run as Administrator.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$PublicKey,
    [Parameter(Mandatory=$false)][string]$PublicKeyPath,
    [Parameter(Mandatory=$false)][string]$TargetUser = $env:USERNAME,
    [switch]$DisablePasswordAuth
)

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg){ Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn($msg){ Write-Warning $msg }
function Write-Err($msg){ Write-Error $msg }

# --- Resolve/Load public key ---
if (-not $PublicKey -and $PublicKeyPath) {
    if (-not (Test-Path -LiteralPath $PublicKeyPath)) { throw "PublicKeyPath not found: $PublicKeyPath" }
    $PublicKey = (Get-Content -LiteralPath $PublicKeyPath -Raw).Trim()
}
if (-not $PublicKey) {
    if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
        $clip = (Get-Clipboard) -as [string]
        if ($clip -and $clip.Trim().Length -gt 0 -and $clip -match '^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp\d+) ') {
            $PublicKey = $clip.Trim()
            Write-Info "Loaded public key from clipboard."
        }
    }
}
if (-not $PublicKey) { throw "No public key provided. Use -PublicKey, -PublicKeyPath, or copy a key into the clipboard." }

# Non-blocking format check
if ($PublicKey -notmatch '^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp\d+)\s+[A-Za-z0-9+/=]+(\s+.*)?$') {
    Write-Warn "The provided key doesn't look like a standard SSH public key format. Proceeding anyway."
}

# --- Ensure OpenSSH Server installed and running ---
Write-Info "Ensuring OpenSSH Server is installed..."
$cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if (-not $cap -or $cap.State -ne 'Installed') {
    Write-Info "Installing OpenSSH.Server capability..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
}
Write-Ok "OpenSSH Server present."

if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
    throw "OpenSSH Server service (sshd) not found after installation."
}
if ((Get-Service sshd).Status -ne 'Running') {
    Write-Info "Starting sshd service..."
    Start-Service sshd
}
Set-Service -Name sshd -StartupType Automatic
Write-Ok "sshd is running and set to Automatic."

# --- Firewall: idempotent rule handling ---
Write-Info "Ensuring firewall allows inbound TCP/22..."
$fwName = "OpenSSH-Server-In-TCP"
$fw = Get-NetFirewallRule -Name $fwName -ErrorAction SilentlyContinue
if (-not $fw) {
    $fw = Get-NetFirewallRule -DisplayName "OpenSSH Server (TCP-In)" -ErrorAction SilentlyContinue
}
if (-not $fw) {
    try {
        New-NetFirewallRule -Name $fwName `
            -DisplayName "OpenSSH Server (TCP-In)" `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Write-Ok "Firewall rule created."
    } catch {
        if ($_.Exception.Message -match 'already exists') {
            Write-Info "Firewall rule already exists; continuing."
        } else {
            throw
        }
    }
} else {
    Enable-NetFirewallRule -Name $fw.Name -ErrorAction SilentlyContinue | Out-Null
    Write-Ok "Firewall rule present/enabled."
}

# --- Resolve Target User -> SID & Profile path (robust) ---
function Resolve-Account {
    param([string]$Account)

    $original = $Account
    if (-not $Account) { $Account = $env:USERNAME }

    # Expand .\User
    if ($Account -match '^[.]\\') {
        $Account = "$env:COMPUTERNAME\" + ($Account -split '\\')[-1]
    }

    # If no slash or @, try local first, then USERDOMAIN
    if ($Account -notmatch '[\\@]') {
        $local = Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True and Name='$Account'" -ErrorAction SilentlyContinue
        if ($local) {
            $Account = "$env:COMPUTERNAME\$Account"
        } elseif ($env:USERDOMAIN -and $env:USERDOMAIN -ne $env:COMPUTERNAME) {
            $Account = "$env:USERDOMAIN\$Account"
        }
    }

    # If target equals current user name, use current token and profile
    if ($original -and ($original.ToLower() -eq $env:USERNAME.ToLower()) -and ($Account -notmatch '[\\@]')) {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $profile = $env:USERPROFILE
        return [PSCustomObject]@{ Account = "$env:COMPUTERNAME\$original"; SID = $sid; ProfilePath = $profile }
    }

    try {
        $nt = New-Object System.Security.Principal.NTAccount($Account)
        $sid = $nt.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        throw "Cannot resolve account: $original (tried: $Account)"
    }

    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $profilePath = (Get-ChildItem $regPath | Where-Object {
        $_.PSChildName -eq $sid
    } | ForEach-Object {
        (Get-ItemProperty $_.PSPath).ProfileImagePath
    })

    if (-not $profilePath) {
        if ($original -and ($original.ToLower() -eq $env:USERNAME.ToLower())) { $profilePath = $env:USERPROFILE }
        if (-not $profilePath) {
            throw "Cannot find profile path for $original (SID: $sid). Has the user logged on at least once?"
        }
    }

    [PSCustomObject]@{ Account = $Account; SID = $sid; ProfilePath = $profilePath }
}

$userInfo = Resolve-Account -Account $TargetUser
$acctForAcl = $userInfo.Account

Write-Ok "Target user: $($userInfo.Account)"
Write-Ok "Profile path: $($userInfo.ProfilePath)"

# --- Prepare user .ssh\authorized_keys ---
$sshDir = Join-Path $userInfo.ProfilePath '.ssh'
$authKeys = Join-Path $sshDir 'authorized_keys'

if (-not (Test-Path -LiteralPath $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $authKeys)) { New-Item -ItemType File -Path $authKeys -Force | Out-Null }

# Append key if not present
$existing = (Get-Content -LiteralPath $authKeys -Raw) 2>$null
if (-not $existing -or ($existing -notmatch [regex]::Escape($PublicKey))) {
    Add-Content -LiteralPath $authKeys -Value $PublicKey -Encoding Ascii
    Write-Ok "Public key added to $authKeys"
} else {
    Write-Info "Public key already present in $authKeys"
}

# --- Strict ACLs for .ssh and authorized_keys ---
Write-Info "Setting strict ACLs on $sshDir and $authKeys ..."
& icacls.exe $sshDir /inheritance:r | Out-Null
& icacls.exe $sshDir /grant "${acctForAcl}:(M)" "SYSTEM:(F)" "Administrators:(F)" | Out-Null

& icacls.exe $authKeys /inheritance:r | Out-Null
& icacls.exe $authKeys /grant "${acctForAcl}:(M)" "SYSTEM:(F)" "Administrators:(F)" | Out-Null
Write-Ok "ACLs set."

# --- Inspect sshd_config for admin-match ---
$sshdConfig = Join-Path $env:ProgramData 'ssh\sshd_config'
if (-not (Test-Path -LiteralPath $sshdConfig)) { throw "sshd_config not found at $sshdConfig" }
$configText = Get-Content -LiteralPath $sshdConfig -Raw
$configNorm = $configText -replace "`r`n", "`n"

$adminMatchActive = $false
if ($configNorm -match '(?ms)^[ \t]*Match[ \t]+Group[ \t]+administrators\s*(?:\n.+?)*^\s*AuthorizedKeysFile\s+__PROGRAMDATA__/ssh/administrators_authorized_keys') {
    $adminMatchActive = $true
    Write-Info "'Match Group administrators' with administrators_authorized_keys is ACTIVE."
} else {
    Write-Info "'Match Group administrators' not active (or not using administrators_authorized_keys)."
}

# --- If admin-match active, ALWAYS manage ProgramData\ssh\administrators_authorized_keys ---
if ($adminMatchActive) {
    $adminAuthKeys = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
    if (-not (Test-Path -LiteralPath $adminAuthKeys)) { New-Item -ItemType File -Path $adminAuthKeys -Force | Out-Null }

    $existingAdmin = (Get-Content -LiteralPath $adminAuthKeys -Raw) 2>$null
    if (-not $existingAdmin -or ($existingAdmin -notmatch [regex]::Escape($PublicKey))) {
        Add-Content -LiteralPath $adminAuthKeys -Value $PublicKey -Encoding Ascii
        Write-Ok "Public key added to $adminAuthKeys (admin-match active)."
    } else {
        Write-Info "Public key already present in $adminAuthKeys"
    }

    # ACLs for administrators_authorized_keys: ONLY Administrators and SYSTEM
    & icacls.exe $adminAuthKeys /inheritance:r | Out-Null
    & icacls.exe $adminAuthKeys /grant "Administrators:(F)" "SYSTEM:(F)" | Out-Null
}

# --- Ensure PubkeyAuthentication; optionally disable passwords ---
function Ensure-ConfigLine {
    param([string]$Content, [string]$Key, [string]$DesiredValue)
    $pattern = "(?m)^[ \t]*#?[ \t]*$([regex]::Escape($Key))[ \t]+(yes|no)\s*$"
    if ($Content -match $pattern) {
        return ([regex]::Replace($Content, $pattern, "$Key $DesiredValue"))
    } else {
        return ($Content.TrimEnd() + "`n$Key $DesiredValue`n")
    }
}
Write-Info "Updating $sshdConfig ..."
$configUpdated = Ensure-ConfigLine -Content $configNorm -Key 'PubkeyAuthentication' -DesiredValue 'yes'
if ($DisablePasswordAuth) {
    $configUpdated = Ensure-ConfigLine -Content $configUpdated -Key 'PasswordAuthentication' -DesiredValue 'no'
}

if ($configUpdated -ne $configNorm) {
    Set-Content -LiteralPath $sshdConfig -Value $configUpdated -Encoding Ascii
    Write-Ok "sshd_config updated."
} else {
    Write-Info "sshd_config already configured."
}

# --- Restart sshd to apply changes ---
Write-Info "Restarting sshd ..."
Restart-Service sshd -Force
Write-Ok "sshd restarted."

Write-Host ""
Write-Ok "Key-based SSH configured for $($userInfo.Account)."
Write-Host "Authorized keys file: $authKeys"
if ($adminMatchActive) { Write-Host "Admin match active; also used: C:\ProgramData\ssh\administrators_authorized_keys" }
Write-Host ""
Write-Host "Test from your client:" -ForegroundColor Yellow
Write-Host "  ssh $($TargetUser.Split('\')[-1])@<vm-public-ip-or-dns> -i <path-to-your-private-key>"
if (-not $DisablePasswordAuth) {
    Write-Host "PasswordAuthentication is still enabled. Re-run with -DisablePasswordAuth to force key-only login." -ForegroundColor DarkYellow
}
Write-Host ""
Write-Host "If this is an Azure VM, verify the NSG/NVA allows inbound TCP/22 in addition to Windows Firewall." -ForegroundColor DarkCyan
```

***

### Notes & Tips

*   **Run as Administrator.** The script needs to modify system files and ACLs.
*   **Public key format:** Should start with `ssh-ed25519`, `ssh-rsa`, or `ecdsa-sha2-*`.
*   **Admin users and `administrators_authorized_keys`:**  
    If your `sshd_config` has an active:
    ```text
    Match Group administrators
        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
    ```
    then keys for local administrators must be placed in that **ProgramData** file. The script detects and handles this.
*   **Disable password logins:** Add `-DisablePasswordAuth` after validating key sign-in works, to avoid lockouts.
*   **Azure NSG:** Even if the Windows Firewall is open, Azure **NSGs** (and any NVA/Firewall) must allow inbound TCP/22.

