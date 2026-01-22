# Key Vault DNS Specific Diagnostic
# Test different Key Vault DNS patterns and Azure service endpoints

Write-Host "🔍 Key Vault DNS Diagnostic" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Gray

# Load configuration from .env file
Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
$config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"

if (-not $config -or -not $config['KEY_VAULT_NAME']) {
    Write-Host "❌ Could not load Key Vault name from .env file" -ForegroundColor Red
    Write-Host "   Please ensure .env file exists and contains KEY_VAULT_NAME" -ForegroundColor Yellow
    exit 1
}

$KeyVaultName = $config['KEY_VAULT_NAME']
Write-Host "🔑 Testing Key Vault: $KeyVaultName" -ForegroundColor Cyan

# Test 1: Verify the Key Vault exists and get its actual endpoint
Write-Host "`n1. Testing Key Vault existence..." -ForegroundColor Yellow

try {
    # Try to get Key Vault info using Azure PowerShell
    $kvInfo = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    if ($kvInfo) {
        Write-Host "   ✅ Key Vault exists: $($kvInfo.VaultUri)" -ForegroundColor Green
        $actualEndpoint = $kvInfo.VaultUri -replace "https://", "" -replace "/", ""
        Write-Host "   📍 Actual endpoint: $actualEndpoint" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  Cannot retrieve Key Vault info (may be authentication issue)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Azure PowerShell not connected or Key Vault not accessible" -ForegroundColor Yellow
}

# Test 2: Try different DNS servers
Write-Host "`n2. Testing with different DNS servers..." -ForegroundColor Yellow

$dnsServers = @(
    @{Name = "Default"; Server = $null},
    @{Name = "Cloudflare"; Server = "1.1.1.1"},
    @{Name = "Google"; Server = "8.8.8.8"},
    @{Name = "OpenDNS"; Server = "208.67.222.222"}
)

$kvEndpoint = "$KeyVaultName.vault.azure.net"

foreach ($dns in $dnsServers) {
    try {
        Write-Host "   🔍 Testing with $($dns.Name) DNS..." -ForegroundColor Gray
        
        if ($dns.Server) {
            $result = Resolve-DnsName -Name $kvEndpoint -Server $dns.Server -ErrorAction Stop
        } else {
            $result = Resolve-DnsName -Name $kvEndpoint -ErrorAction Stop
        }
        
        if ($result) {
            Write-Host "      ✅ Resolved: $($result[0].IPAddress)" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 3: Test other Azure Key Vault endpoints
Write-Host "`n3. Testing other Key Vault patterns..." -ForegroundColor Yellow

$testEndpoints = @(
    "vault.azure.net",  # Base domain
    "kv.vault.azure.net",  # Alternative pattern
    "test.vault.azure.net"  # Test pattern
)

foreach ($endpoint in $testEndpoints) {
    try {
        Write-Host "   🔍 Testing $endpoint..." -ForegroundColor Gray
        $result = Resolve-DnsName -Name $endpoint -ErrorAction Stop
        if ($result) {
            Write-Host "      ✅ Resolved: $($result[0].IPAddress)" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 4: Check if it's a corporate DNS filtering issue
Write-Host "`n4. Testing Azure service domains..." -ForegroundColor Yellow

$azureEndpoints = @(
    "storage.azure.com",
    "database.windows.net",
    "servicebus.windows.net",
    "vault.azure.net"
)

foreach ($endpoint in $azureEndpoints) {
    try {
        Write-Host "   🔍 Testing $endpoint..." -ForegroundColor Gray
        $result = Resolve-DnsName -Name $endpoint -ErrorAction Stop
        if ($result) {
            Write-Host "      ✅ Resolved: $($result[0].IPAddress)" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 5: Try nslookup command as alternative
Write-Host "`n5. Testing with nslookup..." -ForegroundColor Yellow

try {
    Write-Host "   🔍 Running nslookup for $kvEndpoint..." -ForegroundColor Gray
    $nslookup = nslookup $kvEndpoint 2>&1
    if ($nslookup -like "*Address:*") {
        Write-Host "      ✅ nslookup successful" -ForegroundColor Green
        Write-Host "      $($nslookup -join "`n      ")" -ForegroundColor Gray
    } else {
        Write-Host "      ❌ nslookup failed" -ForegroundColor Red
        Write-Host "      $($nslookup -join "`n      ")" -ForegroundColor Gray
    }
} catch {
    Write-Host "      ❌ nslookup error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n💡 Analysis:" -ForegroundColor Cyan
Write-Host "If other *.vault.azure.net domains also fail, this indicates:" -ForegroundColor White
Write-Host "   1. Corporate DNS filtering of Azure Key Vault services" -ForegroundColor Yellow
Write-Host "   2. Group Policy restrictions on Domain Controllers" -ForegroundColor Yellow
Write-Host "   3. Firewall blocking specific Azure service categories" -ForegroundColor Yellow
Write-Host ""
Write-Host "If only your specific Key Vault fails:" -ForegroundColor White
Write-Host "   1. Key Vault name might be incorrect" -ForegroundColor Yellow
Write-Host "   2. Key Vault might be in different region/tenant" -ForegroundColor Yellow
Write-Host "   3. Key Vault might have been deleted" -ForegroundColor Yellow