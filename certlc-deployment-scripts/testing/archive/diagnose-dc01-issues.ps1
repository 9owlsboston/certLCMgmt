# Comprehensive Diagnostic Script for DC01 Certificate Issues
# Run this first to identify the specific problem

Write-Host "🔍 DC01 Certificate Creation Diagnostics" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Gray

$KeyVaultName = "DEMO-KV-1030164500"
$diagnostics = @()

# Test 1: Environment Check
Write-Host "`n1. Environment Information" -ForegroundColor Yellow
$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$domain = $env:USERDOMAIN
Write-Host "   💻 Computer: $computerName" -ForegroundColor Gray
Write-Host "   👤 User: $domain\$userName" -ForegroundColor Gray
Write-Host "   🏠 Working Directory: $(Get-Location)" -ForegroundColor Gray

if ($computerName -eq "DC01") {
    Write-Host "   ✅ Running from DC01 (Domain Controller)" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Running from: $computerName" -ForegroundColor Gray
}

# Test 2: Internet Connectivity
Write-Host "`n2. Internet Connectivity Test" -ForegroundColor Yellow
try {
    $internetTest = Test-NetConnection -ComputerName "login.microsoftonline.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($internetTest) {
        Write-Host "   ✅ Internet connectivity confirmed" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No internet connectivity" -ForegroundColor Red
        $diagnostics += "CRITICAL: No internet access from DC01"
    }
}
catch {
    Write-Host "   ❌ Internet connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
    $diagnostics += "ERROR: Internet test failed - $($_.Exception.Message)"
}

# Test 3: Azure PowerShell Module Check
Write-Host "`n3. Azure PowerShell Module Status" -ForegroundColor Yellow
$azModules = @('Az.Accounts', 'Az.KeyVault', 'Az.Profile')

foreach ($module in $azModules) {
    try {
        $installedModule = Get-Module -Name $module -ListAvailable | Select-Object -First 1
        if ($installedModule) {
            Write-Host "   ✅ $module - Version: $($installedModule.Version)" -ForegroundColor Green
            
            # Check if loaded
            $loadedModule = Get-Module -Name $module
            if ($loadedModule) {
                Write-Host "      🔄 Loaded in current session" -ForegroundColor Gray
            } else {
                Write-Host "      ⚠️  Available but not loaded" -ForegroundColor Yellow
                try {
                    Import-Module $module -Force
                    Write-Host "      ✅ Successfully imported" -ForegroundColor Green
                }
                catch {
                    Write-Host "      ❌ Failed to import: $($_.Exception.Message)" -ForegroundColor Red
                    $diagnostics += "ERROR: Cannot import $module - $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "   ❌ $module - Not installed" -ForegroundColor Red
            $diagnostics += "CRITICAL: $module not installed"
        }
    }
    catch {
        Write-Host "   ❌ $module - Check failed: $($_.Exception.Message)" -ForegroundColor Red
        $diagnostics += "ERROR: Module check failed for $module - $($_.Exception.Message)"
    }
}

# Test 4: Azure Authentication Status
Write-Host "`n4. Azure Authentication Status" -ForegroundColor Yellow
try {
    $azContext = Get-AzContext
    if ($azContext) {
        Write-Host "   ✅ Authenticated to Azure" -ForegroundColor Green
        Write-Host "      👤 Account: $($azContext.Account.Id)" -ForegroundColor Gray
        Write-Host "      🏢 Tenant: $($azContext.Tenant.Id)" -ForegroundColor Gray
        Write-Host "      📋 Subscription: $($azContext.Subscription.Name)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Not authenticated to Azure" -ForegroundColor Red
        $diagnostics += "CRITICAL: Not authenticated to Azure - Run Connect-AzAccount"
    }
}
catch {
    Write-Host "   ❌ Authentication check failed: $($_.Exception.Message)" -ForegroundColor Red
    $diagnostics += "ERROR: Authentication check failed - $($_.Exception.Message)"
}

# Test 5: Key Vault Connectivity
Write-Host "`n5. Key Vault Connectivity Test" -ForegroundColor Yellow
if ($azContext) {
    try {
        Write-Host "   🔍 Testing Key Vault DNS resolution..." -ForegroundColor Gray
        $kvDnsTest = Test-NetConnection -ComputerName "$KeyVaultName.vault.azure.net" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($kvDnsTest) {
            Write-Host "   ✅ Key Vault DNS resolution successful" -ForegroundColor Green
            
            Write-Host "   🔍 Testing Key Vault access..." -ForegroundColor Gray
            $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
            Write-Host "   ✅ Key Vault access confirmed" -ForegroundColor Green
            Write-Host "      📍 Location: $($keyVault.Location)" -ForegroundColor Gray
            Write-Host "      🔐 Vault URI: $($keyVault.VaultUri)" -ForegroundColor Gray
            
            # Test permissions
            Write-Host "   🔍 Testing Key Vault permissions..." -ForegroundColor Gray
            try {
                $certs = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -ErrorAction Stop
                Write-Host "   ✅ Can list certificates ($($certs.Count) found)" -ForegroundColor Green
            }
            catch {
                Write-Host "   ❌ Cannot list certificates: $($_.Exception.Message)" -ForegroundColor Red
                $diagnostics += "ERROR: Insufficient Key Vault permissions - $($_.Exception.Message)"
            }
        } else {
            Write-Host "   ❌ Cannot connect to Key Vault endpoint" -ForegroundColor Red
            $diagnostics += "ERROR: Key Vault endpoint unreachable"
        }
    }
    catch {
        Write-Host "   ❌ Key Vault access failed: $($_.Exception.Message)" -ForegroundColor Red
        $diagnostics += "ERROR: Key Vault access failed - $($_.Exception.Message)"
    }
} else {
    Write-Host "   ⏭️  Skipped - Not authenticated to Azure" -ForegroundColor Gray
}

# Test 6: Certificate Provider Test
Write-Host "`n6. Certificate Provider Test" -ForegroundColor Yellow
try {
    Write-Host "   🔍 Testing certificate creation capabilities..." -ForegroundColor Gray
    
    # Test basic certificate creation
    $testCertParams = @{
        Subject = "CN=DiagnosticTest"
        NotBefore = (Get-Date)
        NotAfter = (Get-Date).AddMinutes(1)
        KeyAlgorithm = "RSA"
        KeyLength = 2048
        KeyUsage = @("DigitalSignature")
        KeyExportPolicy = "Exportable"
        CertStoreLocation = "Cert:\CurrentUser\My"
    }
    
    $testCert = New-SelfSignedCertificate @testCertParams
    Write-Host "   ✅ Certificate creation successful" -ForegroundColor Green
    
    # Test PFX export
    $testPfxPath = "$env:TEMP\DiagnosticTest.pfx"
    $testPassword = ConvertTo-SecureString -String "Test123!" -Force -AsPlainText
    Export-PfxCertificate -Cert $testCert -FilePath $testPfxPath -Password $testPassword | Out-Null
    Write-Host "   ✅ PFX export successful" -ForegroundColor Green
    
    # Cleanup
    Remove-Item $testPfxPath -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=DiagnosticTest" } | Remove-Item
    Write-Host "   🧹 Test certificate cleaned up" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Certificate creation failed: $($_.Exception.Message)" -ForegroundColor Red
    $diagnostics += "ERROR: Certificate creation failed - $($_.Exception.Message)"
}

# Test 7: Windows Features Check (if running on Server)
Write-Host "`n7. Windows Server Features Check" -ForegroundColor Yellow
try {
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    if ($osInfo.ProductType -ne 1) {  # Not a workstation (Server OS)
        Write-Host "   🖥️  Running on Windows Server" -ForegroundColor Gray
        
        # Check if ADCS is installed (since this is a DC)
        try {
            $adcsFeature = Get-WindowsFeature -Name "ADCS-Cert-Authority" -ErrorAction SilentlyContinue
            if ($adcsFeature -and $adcsFeature.InstallState -eq "Installed") {
                Write-Host "   ✅ ADCS Certificate Authority is installed" -ForegroundColor Green
            } else {
                Write-Host "   ℹ️  ADCS Certificate Authority not installed" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "   ℹ️  Could not check ADCS status" -ForegroundColor Gray
        }
    } else {
        Write-Host "   💻 Running on Windows workstation" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   ℹ️  Could not determine OS type" -ForegroundColor Gray
}

# Summary Report
Write-Host "`n📋 DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Gray

if ($diagnostics.Count -eq 0) {
    Write-Host "✅ ALL CHECKS PASSED - No issues detected!" -ForegroundColor Green -BackgroundColor Black
    Write-Host "   The certificate creation script should work successfully" -ForegroundColor Green
} else {
    Write-Host "❌ ISSUES DETECTED:" -ForegroundColor Red -BackgroundColor Black
    foreach ($issue in $diagnostics) {
        Write-Host "   • $issue" -ForegroundColor Red
    }
    
    Write-Host "`n🔧 RECOMMENDED ACTIONS:" -ForegroundColor Yellow
    
    if ($diagnostics -like "*Not authenticated to Azure*") {
        Write-Host "   1. Authenticate to Azure:" -ForegroundColor White
        Write-Host "      Connect-AzAccount" -ForegroundColor Gray
    }
    
    if ($diagnostics -like "*not installed*") {
        Write-Host "   2. Install missing Azure PowerShell modules:" -ForegroundColor White
        Write-Host "      Install-Module -Name Az -AllowClobber -Force" -ForegroundColor Gray
    }
    
    if ($diagnostics -like "*Key Vault permissions*") {
        Write-Host "   3. Check Key Vault access policy in Azure Portal" -ForegroundColor White
        Write-Host "      Ensure your account has Certificate permissions" -ForegroundColor Gray
    }
    
    if ($diagnostics -like "*Internet*") {
        Write-Host "   4. Check internet connectivity and firewall settings" -ForegroundColor White
    }
}

Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Cyan
if ($diagnostics.Count -eq 0) {
    Write-Host "   Run the certificate creation script: .\create-shortlived-cert.ps1" -ForegroundColor Green
} else {
    Write-Host "   Fix the issues above, then run this diagnostic again" -ForegroundColor Yellow
    Write-Host "   Once all checks pass, run: .\create-shortlived-cert.ps1" -ForegroundColor Green
}

Write-Host "`n" # Extra spacing