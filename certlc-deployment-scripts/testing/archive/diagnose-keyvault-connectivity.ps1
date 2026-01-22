# Network Troubleshooting Script for Key Vault Connectivity
# Run this to diagnose and fix connectivity issues

Write-Host "🔍 Diagnosing Key Vault Connectivity Issues" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Gray

$KeyVaultName = "DEMO-KV-1030164500"
$KeyVaultFQDN = "$KeyVaultName.vault.azure.net"

# Test 1: DNS Resolution
Write-Host "`n1. Testing DNS Resolution..." -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName -Name $KeyVaultFQDN -ErrorAction Stop
    Write-Host "   ✅ DNS Resolution successful" -ForegroundColor Green
    Write-Host "   📍 IP Address: $($dnsResult.IPAddress)" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ DNS Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   💡 Possible fixes:" -ForegroundColor Yellow
    Write-Host "      - Check network connectivity" -ForegroundColor Gray
    Write-Host "      - Verify DNS server configuration" -ForegroundColor Gray
    Write-Host "      - Try running: ipconfig /flushdns" -ForegroundColor Gray
}

# Test 2: Network Connectivity
Write-Host "`n2. Testing Network Connectivity..." -ForegroundColor Yellow
try {
    $tcpTest = Test-NetConnection -ComputerName $KeyVaultFQDN -Port 443 -InformationLevel Quiet
    if ($tcpTest) {
        Write-Host "   ✅ TCP 443 connectivity successful" -ForegroundColor Green
    } else {
        Write-Host "   ❌ TCP 443 connectivity failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "   ❌ Network test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Azure Context
Write-Host "`n3. Checking Azure Context..." -ForegroundColor Yellow
try {
    $context = Get-AzContext
    if ($context) {
        Write-Host "   ✅ Azure context available" -ForegroundColor Green
        Write-Host "   👤 Account: $($context.Account.Id)" -ForegroundColor Gray
        Write-Host "   🏢 Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ No Azure context found" -ForegroundColor Red
        Write-Host "   💡 Run: Connect-AzAccount" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "   ❌ Azure context check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Key Vault Access
Write-Host "`n4. Testing Key Vault Access..." -ForegroundColor Yellow
try {
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "   ✅ Key Vault access successful" -ForegroundColor Green
    Write-Host "   🏢 Resource Group: $($keyVault.ResourceGroupName)" -ForegroundColor Gray
    Write-Host "   📍 Location: $($keyVault.Location)" -ForegroundColor Gray
}
catch {
    Write-Host "   ❌ Key Vault access failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -like "*Forbidden*") {
        Write-Host "   💡 Permissions issue - check Key Vault access policies" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*not found*") {
        Write-Host "   💡 Key Vault not found - check name and subscription" -ForegroundColor Yellow
    } else {
        Write-Host "   💡 Network connectivity issue" -ForegroundColor Yellow
    }
}

Write-Host "`n🔧 RECOMMENDED FIXES:" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Gray
Write-Host "1. Flush DNS cache: ipconfig /flushdns" -ForegroundColor White
Write-Host "2. Reset network adapter: netsh winsock reset" -ForegroundColor White
Write-Host "3. Check firewall/proxy settings" -ForegroundColor White
Write-Host "4. Verify Azure subscription and permissions" -ForegroundColor White
Write-Host "5. Try connecting to Azure Portal to verify network" -ForegroundColor White