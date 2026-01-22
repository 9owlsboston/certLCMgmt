# DC01 Network Diagnostic Script
# Run this on DC01 to identify specific network connectivity issues

Write-Host "🔍 DC01 Network Connectivity Diagnostics" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Gray

# Load configuration from .env file
$configPath = "$PSScriptRoot/../.env"
if (Test-Path $configPath) {
    Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
    $config = Get-CertLCConfig -EnvFilePath $configPath
    
    if ($config -and $config['KEY_VAULT_NAME']) {
        $KeyVaultName = $config['KEY_VAULT_NAME']
        Write-Host "🔑 Testing Key Vault: $KeyVaultName" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Could not load Key Vault name from .env file, using default" -ForegroundColor Yellow
        $KeyVaultName = "DEMO-KV-20251103"
    }
} else {
    Write-Host "⚠️  .env file not found, using default Key Vault name" -ForegroundColor Yellow
    $KeyVaultName = "DEMO-KV-20251103"
}

$testResults = @()

# Test 1: Basic Internet Connectivity
Write-Host "`n1. Testing basic internet connectivity..." -ForegroundColor Yellow

$internetTargets = @(
    @{Name = "Google DNS"; Host = "8.8.8.8"; Port = 53},
    @{Name = "Microsoft"; Host = "microsoft.com"; Port = 443},
    @{Name = "Azure Login"; Host = "login.microsoftonline.com"; Port = 443}
)

foreach ($target in $internetTargets) {
    try {
        Write-Host "   🔍 Testing $($target.Name) ($($target.Host):$($target.Port))..." -ForegroundColor Gray
        $result = Test-NetConnection -ComputerName $target.Host -Port $target.Port -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($result) {
            Write-Host "      ✅ Accessible" -ForegroundColor Green
            $testResults += "✅ $($target.Name): Accessible"
        } else {
            Write-Host "      ❌ Not accessible" -ForegroundColor Red
            $testResults += "❌ $($target.Name): Not accessible"
        }
    }
    catch {
        Write-Host "      ❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "❌ $($target.Name): Test failed"
    }
}

# Test 2: DNS Resolution
Write-Host "`n2. Testing DNS resolution..." -ForegroundColor Yellow

$dnsTargets = @(
    "microsoft.com",
    "login.microsoftonline.com",
    "$KeyVaultName.vault.azure.net",
    "management.azure.com"
)

foreach ($dns in $dnsTargets) {
    try {
        Write-Host "   🔍 Resolving $dns..." -ForegroundColor Gray
        $resolved = Resolve-DnsName -Name $dns -ErrorAction Stop
        if ($resolved) {
            Write-Host "      ✅ Resolved to: $($resolved[0].IPAddress)" -ForegroundColor Green
            $testResults += "✅ DNS ${dns}: Resolved"
        }
    }
    catch {
        Write-Host "      ❌ Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "❌ DNS ${dns}: Resolution failed"
    }
}

# Test 3: Key Vault Specific Tests
Write-Host "`n3. Testing Key Vault connectivity..." -ForegroundColor Yellow

try {
    Write-Host "   🔍 Testing Key Vault endpoint..." -ForegroundColor Gray
    $kvEndpoint = "$KeyVaultName.vault.azure.net"
    
    # DNS test
    try {
        $kvDns = Resolve-DnsName -Name $kvEndpoint -ErrorAction Stop
        Write-Host "      ✅ DNS resolution successful: $($kvDns[0].IPAddress)" -ForegroundColor Green
        $testResults += "✅ Key Vault DNS: Resolved"
        
        # TCP connectivity test
        try {
            $kvTcp = Test-NetConnection -ComputerName $kvEndpoint -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($kvTcp) {
                Write-Host "      ✅ TCP 443 connection successful" -ForegroundColor Green
                $testResults += "✅ Key Vault TCP: Accessible"
            } else {
                Write-Host "      ❌ TCP 443 connection failed" -ForegroundColor Red
                $testResults += "❌ Key Vault TCP: Connection failed"
            }
        }
        catch {
            Write-Host "      ❌ TCP test failed: $($_.Exception.Message)" -ForegroundColor Red
            $testResults += "❌ Key Vault TCP: Test failed"
        }
    }
    catch {
        Write-Host "      ❌ DNS resolution failed: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "❌ Key Vault DNS: Resolution failed"
    }
}
catch {
    Write-Host "      ❌ Key Vault test failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "❌ Key Vault: Test failed"
}

# Test 4: Proxy Configuration
Write-Host "`n4. Checking proxy configuration..." -ForegroundColor Yellow

try {
    # Check IE proxy settings (used by PowerShell)
    $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    
    if ($proxySettings.ProxyEnable -eq 1) {
        Write-Host "   ⚠️  Proxy enabled: $($proxySettings.ProxyServer)" -ForegroundColor Yellow
        $testResults += "⚠️ Proxy: Enabled - $($proxySettings.ProxyServer)"
        
        if ($proxySettings.ProxyOverride) {
            Write-Host "   📝 Proxy bypass list: $($proxySettings.ProxyOverride)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ℹ️  No proxy configured" -ForegroundColor Gray
        $testResults += "ℹ️ Proxy: Not configured"
    }
}
catch {
    Write-Host "   ❌ Cannot check proxy settings: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "❌ Proxy: Cannot check settings"
}

# Test 5: Windows Firewall
Write-Host "`n5. Checking Windows Firewall..." -ForegroundColor Yellow

try {
    $firewallProfiles = Get-NetFirewallProfile
    foreach ($profile in $firewallProfiles) {
        $status = if ($profile.Enabled) { "Enabled" } else { "Disabled" }
        $color = if ($profile.Enabled) { "Yellow" } else { "Green" }
        Write-Host "   🔥 $($profile.Name) Profile: $status" -ForegroundColor $color
        $testResults += "🔥 Firewall $($profile.Name): $status"
    }
}
catch {
    Write-Host "   ❌ Cannot check firewall status: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += "❌ Firewall: Cannot check status"
}

# Test 6: Computer Role and Network Location
Write-Host "`n6. System information..." -ForegroundColor Yellow

try {
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    
    Write-Host "   💻 Computer: $($env:COMPUTERNAME)" -ForegroundColor Gray
    Write-Host "   🏢 Domain: $($computerSystem.Domain)" -ForegroundColor Gray
    Write-Host "   🖥️  OS: $($osInfo.Caption)" -ForegroundColor Gray
    Write-Host "   👤 User: $($env:USERDOMAIN)\$($env:USERNAME)" -ForegroundColor Gray
    
    if ($computerSystem.DomainRole -ge 4) {
        Write-Host "   🏛️  Role: Domain Controller" -ForegroundColor Yellow
        $testResults += "🏛️ Role: Domain Controller (restrictive network policies likely)"
    } else {
        Write-Host "   💼 Role: Domain Member" -ForegroundColor Gray
        $testResults += "💼 Role: Domain Member"
    }
}
catch {
    Write-Host "   ❌ Cannot get system info: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary Report
Write-Host "`n📋 DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Gray

$accessibleCount = ($testResults | Where-Object { $_ -like "✅*" }).Count
$failedCount = ($testResults | Where-Object { $_ -like "❌*" }).Count
$warningCount = ($testResults | Where-Object { $_ -like "⚠️*" }).Count

Write-Host "✅ Successful: $accessibleCount" -ForegroundColor Green
Write-Host "❌ Failed: $failedCount" -ForegroundColor Red
Write-Host "⚠️  Warnings: $warningCount" -ForegroundColor Yellow

Write-Host "`n📝 Detailed Results:" -ForegroundColor Gray
foreach ($result in $testResults) {
    if ($result -like "✅*") {
        Write-Host "   $result" -ForegroundColor Green
    } elseif ($result -like "❌*") {
        Write-Host "   $result" -ForegroundColor Red
    } elseif ($result -like "⚠️*") {
        Write-Host "   $result" -ForegroundColor Yellow
    } else {
        Write-Host "   $result" -ForegroundColor Gray
    }
}

# Recommendations
Write-Host "`n🔧 RECOMMENDATIONS:" -ForegroundColor Cyan

if ($failedCount -gt 0) {
    Write-Host "❌ Network connectivity issues detected!" -ForegroundColor Red
    Write-Host ""
    
    if ($testResults -like "*DNS*Resolution failed*") {
        Write-Host "🔧 DNS Issues:" -ForegroundColor Yellow
        Write-Host "   1. Check DNS server configuration" -ForegroundColor White
        Write-Host "   2. Verify firewall allows DNS (port 53)" -ForegroundColor White
        Write-Host "   3. Try alternative DNS: 8.8.8.8 or 1.1.1.1" -ForegroundColor White
    }
    
    if ($testResults -like "*TCP*Connection failed*") {
        Write-Host "🔧 TCP Connection Issues:" -ForegroundColor Yellow
        Write-Host "   1. Check firewall rules for outbound HTTPS (port 443)" -ForegroundColor White
        Write-Host "   2. Verify proxy configuration if applicable" -ForegroundColor White
        Write-Host "   3. Check corporate network policies" -ForegroundColor White
    }
    
    if ($testResults -like "*Domain Controller*") {
        Write-Host "🔧 Domain Controller Restrictions:" -ForegroundColor Yellow
        Write-Host "   1. DC01 may have restrictive Group Policy settings" -ForegroundColor White
        Write-Host "   2. Consider running scripts from a member server or workstation" -ForegroundColor White
        Write-Host "   3. Check with network administrators for Azure access policies" -ForegroundColor White
    }
    
    Write-Host "💡 Alternative Solutions:" -ForegroundColor Cyan
    Write-Host "   1. Run certificate script from your local machine" -ForegroundColor White
    Write-Host "   2. Use a different server with internet access" -ForegroundColor White
    Write-Host "   3. Configure proxy settings if required" -ForegroundColor White
    Write-Host "   4. Request firewall exceptions for Azure endpoints" -ForegroundColor White
} else {
    Write-Host "✅ All network tests passed!" -ForegroundColor Green
    Write-Host "   The certificate script should work from DC01" -ForegroundColor Green
}

Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
if ($failedCount -eq 0) {
    Write-Host "   Try running: .\create-shortlived-cert-robust.ps1" -ForegroundColor Green
} else {
    Write-Host "   1. Address the network connectivity issues above" -ForegroundColor White
    Write-Host "   2. Or run the certificate script from your local machine" -ForegroundColor White
    Write-Host "   3. Or use the Linux/Python implementation (no network restrictions)" -ForegroundColor Green
}