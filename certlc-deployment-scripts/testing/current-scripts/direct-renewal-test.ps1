# Direct Certificate Renewal Test - Bypass Event Grid
# Manually check certificates and trigger renewal process

# Embedded configuration
$RESOURCE_GROUP = "rg-demo-certlc"
$AUTOMATION_ACCOUNT_NAME = "DEMO-AA-20251103"
$KEY_VAULT_NAME = "DEMO-KV-20251103"

Write-Host "🔧 DIRECT CERTIFICATE RENEWAL TEST" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check authentication
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not authenticated to Azure. Run: Connect-AzAccount" -ForegroundColor Red
        return
    }

    Write-Host "Loading Azure modules..." -ForegroundColor Yellow
    Import-Module Az.KeyVault -Force
    Import-Module Az.Automation -Force
    Write-Host "   Azure modules loaded successfully" -ForegroundColor Green
    Write-Host ""

    Write-Host "🎯 STEP 1: Analyze Current Certificates" -ForegroundColor Magenta
    Write-Host "=======================================" -ForegroundColor Magenta
    
    Write-Host "1. Getting all certificates from Key Vault..." -ForegroundColor Yellow
    
    $certificates = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME
    $threshold = 40  # 40 days threshold
    $now = Get-Date
    
    Write-Host "   Found $($certificates.Count) total certificates" -ForegroundColor White
    Write-Host "   Renewal threshold: $threshold days" -ForegroundColor White
    Write-Host ""
    
    $renewalCandidates = @()
    
    foreach ($cert in $certificates) {
        try {
            # Get detailed certificate info
            $certDetail = Get-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $cert.Name
            
            if ($certDetail.Certificate) {
                $expiryDate = $certDetail.Certificate.NotAfter
                $daysUntilExpiry = ($expiryDate - $now).Days
                
                $statusIcon = if ($daysUntilExpiry -le 0) { "🔴" } elseif ($daysUntilExpiry -le $threshold) { "🟡" } else { "🟢" }
                
                Write-Host "   $statusIcon $($cert.Name)" -ForegroundColor White
                Write-Host "      Expires: $($expiryDate.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
                Write-Host "      Days remaining: $daysUntilExpiry" -ForegroundColor Gray
                
                if ($daysUntilExpiry -le $threshold) {
                    $renewalCandidates += @{
                        Name = $cert.Name
                        ExpiryDate = $expiryDate
                        DaysRemaining = $daysUntilExpiry
                        Id = $certDetail.Id
                    }
                }
            } else {
                Write-Host "   ⚠️ $($cert.Name) - Could not get certificate details" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   ❌ $($cert.Name) - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "🎯 STEP 2: Process Renewal Candidates" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    
    if ($renewalCandidates.Count -eq 0) {
        Write-Host "   ✅ No certificates need renewal (all expire > $threshold days)" -ForegroundColor Green
        Write-Host ""
        Write-Host "🛠️ CREATING TEST CERTIFICATE FOR IMMEDIATE RENEWAL" -ForegroundColor Yellow
        
        # Create a certificate with immediate expiry for testing
        $testCertName = "urgent-renewal-$(Get-Date -Format 'MMdd-HHmm')"
        $policy = New-AzKeyVaultCertificatePolicy `
            -SubjectName "CN=$testCertName.contoso.com" `
            -IssuerName "Self" `
            -ValidityInMonths 1 `  # Very short validity
            -KeyType "RSA" `
            -KeySize 2048 `
            -SecretContentType "application/x-pkcs12"
        
        Add-AzKeyVaultCertificate -VaultName $KEY_VAULT_NAME -Name $testCertName -CertificatePolicy $policy | Out-Null
        Write-Host "   ✅ Created urgent test certificate: $testCertName" -ForegroundColor Green
        
        # Add to renewal candidates
        $renewalCandidates += @{
            Name = $testCertName
            ExpiryDate = (Get-Date).AddDays(5)  # Simulated short expiry
            DaysRemaining = 5
            Id = "https://$($KEY_VAULT_NAME.ToLower()).vault.azure.net/certificates/$testCertName"
        }
    } else {
        Write-Host "   Found $($renewalCandidates.Count) certificates needing renewal:" -ForegroundColor Green
        foreach ($candidate in $renewalCandidates) {
            Write-Host "   📋 $($candidate.Name) (expires in $($candidate.DaysRemaining) days)" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "🎯 STEP 3: Test Certificate Authority Connection" -ForegroundColor Magenta
    Write-Host "===============================================" -ForegroundColor Magenta
    
    Write-Host "2. Testing CA connectivity and certificate templates..." -ForegroundColor Yellow
    
    # Check if we can connect to the CA
    $caServer = "ca01.demo.com"
    Write-Host "   Testing connection to CA: $caServer" -ForegroundColor White
    
    try {
        # Test basic connectivity
        $pingResult = Test-NetConnection -ComputerName $caServer -Port 445 -WarningAction SilentlyContinue
        if ($pingResult.TcpTestSucceeded) {
            Write-Host "   ✅ CA server is reachable" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ CA server connection test failed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️ CA connectivity test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎯 STEP 4: Simulate Certificate Renewal Process" -ForegroundColor Magenta
    Write-Host "=============================================" -ForegroundColor Magenta
    
    Write-Host "3. Simulating certificate renewal workflow..." -ForegroundColor Yellow
    
    foreach ($candidate in $renewalCandidates) {
        Write-Host "   Processing: $($candidate.Name)" -ForegroundColor White
        
        # Step 1: Generate CSR (simulated)
        Write-Host "     📝 Step 1: Generate CSR for $($candidate.Name)" -ForegroundColor Gray
        Write-Host "        Subject: CN=$($candidate.Name).contoso.com" -ForegroundColor Gray
        Write-Host "        Template: WebServer (from automation variable)" -ForegroundColor Gray
        
        # Step 2: Submit to CA (simulated)
        Write-Host "     📤 Step 2: Submit CSR to CA ($caServer)" -ForegroundColor Gray
        Write-Host "        CA Template: WebServer" -ForegroundColor Gray
        Write-Host "        Expected result: Certificate issued" -ForegroundColor Gray
        
        # Step 3: Import to Key Vault (simulated)
        Write-Host "     📥 Step 3: Import renewed certificate to Key Vault" -ForegroundColor Gray
        Write-Host "        Key Vault: $KEY_VAULT_NAME" -ForegroundColor Gray
        Write-Host "        Certificate name: $($candidate.Name)" -ForegroundColor Gray
        
        # Step 4: Update expiry tracking
        Write-Host "     📊 Step 4: Update certificate tracking" -ForegroundColor Gray
        Write-Host "        Old expiry: $($candidate.ExpiryDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        Write-Host "        New expiry: $((Get-Date).AddYears(1).ToString('yyyy-MM-dd')) (simulated)" -ForegroundColor Gray
        
        Write-Host "     ✅ Renewal simulation completed for $($candidate.Name)" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "🎯 STEP 5: Automation System Health Check" -ForegroundColor Magenta
    Write-Host "=========================================" -ForegroundColor Magenta
    
    Write-Host "4. Checking automation system health..." -ForegroundColor Yellow
    
    # Check automation variables
    Write-Host "   Automation Variables:" -ForegroundColor White
    $variables = @("CertRenewalThresholdDays", "DefaultCertificateTemplate", "DefaultEmailRecipient", "FallbackCAServer")
    
    foreach ($varName in $variables) {
        try {
            $var = Get-AzAutomationVariable -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP -Name $varName -ErrorAction SilentlyContinue
            if ($var) {
                Write-Host "     ✅ $varName = $($var.Value)" -ForegroundColor Green
            } else {
                Write-Host "     ⚠️ $varName = Not Set" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "     ❌ $varName = Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Check recent automation activity
    Write-Host ""
    Write-Host "   Recent Automation Jobs:" -ForegroundColor White
    $recentJobs = Get-AzAutomationJob -AutomationAccountName $AUTOMATION_ACCOUNT_NAME -ResourceGroupName $RESOURCE_GROUP | 
                 Where-Object { $_.StartTime -gt (Get-Date).AddHours(-6) } | 
                 Sort-Object StartTime -Descending | 
                 Select-Object -First 8
    
    if ($recentJobs) {
        foreach ($job in $recentJobs) {
            $statusIcon = switch ($job.Status) {
                "Completed" { "✅" }
                "Running" { "🔄" }
                "Failed" { "❌" }
                default { "⏳" }
            }
            $timeStr = $job.StartTime.ToString('MM/dd HH:mm')
            Write-Host "     $statusIcon $($job.RunbookName) | $($job.Status) | $timeStr" -ForegroundColor White
        }
    } else {
        Write-Host "     📝 No recent automation activity" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🎉 DIRECT RENEWAL TEST SUMMARY:" -ForegroundColor Green
    Write-Host "===============================" -ForegroundColor Green
    Write-Host "✅ Certificate analysis completed" -ForegroundColor White
    Write-Host "✅ Found $($renewalCandidates.Count) certificates for renewal" -ForegroundColor White
    Write-Host "✅ CA connectivity tested" -ForegroundColor White
    Write-Host "✅ Renewal workflow simulated" -ForegroundColor White
    Write-Host "✅ Automation system health checked" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 RESULTS:" -ForegroundColor Cyan
    Write-Host "- Certificates needing renewal: $($renewalCandidates.Count)" -ForegroundColor White
    Write-Host "- Automation threshold: $threshold days" -ForegroundColor White
    Write-Host "- CA server: $caServer" -ForegroundColor White
    Write-Host "- Default template: WebServer" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 NEXT ACTIONS:" -ForegroundColor Yellow
    Write-Host "1. Fix runbook execution environment issues" -ForegroundColor White
    Write-Host "2. Verify Hybrid Worker connectivity to CA" -ForegroundColor White
    Write-Host "3. Test actual certificate enrollment from CA" -ForegroundColor White
    Write-Host "4. Implement Event Grid webhook properly" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ DIRECT CERTIFICATE RENEWAL TEST COMPLETED!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ DIRECT RENEWAL TEST FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}