# Verify PowerShell Configuration Loading
# Run this to confirm PowerShell scripts can read the .env file correctly

Write-Host "🔍 PowerShell Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Gray

try {
    # Load configuration from .env file
    Import-Module "$PSScriptRoot/../diagnostics/Config-Loader.psm1" -Force
    $config = Get-CertLCConfig -EnvFilePath "$PSScriptRoot/../.env"
    
    if ($config) {
        Write-Host "`n✅ Configuration loaded successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Show key configuration values
        Write-Host "📋 Key Configuration Values:" -ForegroundColor Yellow
        Write-Host "   🔑 KEY_VAULT_NAME: $($config['KEY_VAULT_NAME'])" -ForegroundColor White
        Write-Host "   🏢 RESOURCE_GROUP: $($config['RESOURCE_GROUP'])" -ForegroundColor White
        Write-Host "   📧 RECIPIENT_EMAIL: $($config['RECIPIENT_EMAIL'])" -ForegroundColor White
        Write-Host "   🌐 LOCATION: $($config['LOCATION'])" -ForegroundColor White
        Write-Host "   📅 UNIQUE_STRING: $($config['UNIQUE_STRING'])" -ForegroundColor White
        
        # Test DNS resolution with correct name
        $KeyVaultName = $config['KEY_VAULT_NAME']
        $kvEndpoint = "$KeyVaultName.vault.azure.net"
        
        Write-Host "`n🔍 Testing DNS resolution with correct Key Vault name..." -ForegroundColor Yellow
        try {
            $dnsResult = Resolve-DnsName -Name $kvEndpoint -ErrorAction Stop
            Write-Host "   ✅ DNS Resolution: SUCCESS" -ForegroundColor Green
            Write-Host "   📍 Resolved to: $($dnsResult[0].IPAddress)" -ForegroundColor Gray
        } catch {
            Write-Host "   ❌ DNS Resolution: FAILED" -ForegroundColor Red
            Write-Host "   💡 Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host "`n🎯 Summary:" -ForegroundColor Cyan
        Write-Host "   • Configuration file loading: ✅ Working" -ForegroundColor Green
        Write-Host "   • Key Vault name: $KeyVaultName" -ForegroundColor White
        Write-Host "   • Endpoint: $kvEndpoint" -ForegroundColor White
        
    } else {
        Write-Host "❌ Failed to load configuration!" -ForegroundColor Red
        Write-Host "   Check that .env file exists and is readable" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Check PowerShell module path and .env file location" -ForegroundColor Yellow
}

Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
if ($config -and $config['KEY_VAULT_NAME']) {
    Write-Host "   1. Run: .\diagnose-dc01-network.ps1" -ForegroundColor White
    Write-Host "   2. Run: .\test-keyvault-dns.ps1" -ForegroundColor White
    Write-Host "   3. Run: .\create-shortlived-cert-robust.ps1" -ForegroundColor White
} else {
    Write-Host "   1. Check .env file exists in parent directory" -ForegroundColor White
    Write-Host "   2. Verify Config-Loader.psm1 is accessible" -ForegroundColor White
    Write-Host "   3. Run this script again to verify" -ForegroundColor White
}