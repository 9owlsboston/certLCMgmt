# Certificate Runaway Issue - Analysis and Fix

## Problem Identified
The certificate lifecycle system is creating excessive certificate versions due to multiple concurrent triggers:

### Root Causes:
1. **Event Grid Retry Policy**: 30 max delivery attempts with 24-hour TTL
2. **No Idempotency Checks**: Script doesn't check if certificate was recently renewed
3. **Scheduled Task Overlap**: 6-hour schedule + webhook triggers
4. **No Job Locking**: Multiple concurrent executions possible

### Current State:
- Certificate `democert` has **10 versions** (should be 1-2 max)
- Jobs running every few minutes instead of only when needed
- Excessive Azure costs due to automation job executions

## Immediate Actions Taken:
1. ✅ **Disabled scheduled task**: `Check CertLC Queue` schedule disabled
2. 🔄 **Need to fix**: Event Grid retry policy
3. 🔄 **Need to add**: Idempotency checks in PowerShell script
4. 🔄 **Need to add**: Job locking mechanism

## Recommended Fixes:

### 1. Fix Event Grid Retry Policy
```bash
# Reduce retry attempts and TTL
az eventgrid system-topic event-subscription update \
  --system-topic-name "DEMO-EG-20251103" \
  --resource-group "rg-demo-certlc" \
  --name "CertLC-webhook" \
  --event-ttl 60 \
  --max-delivery-attempts 3
```

### 2. Add Idempotency Check to PowerShell Script
Add this check before certificate renewal:
```powershell
# Check if certificate was renewed in the last 6 hours
$cert = Get-AzKeyVaultCertificate -VaultName $VaultName -name $ObjectName
$lastModified = $cert.Attributes.Updated
$sixHoursAgo = (Get-Date).AddHours(-6)

if ($lastModified -gt $sixHoursAgo) {
    Write-Output "Certificate $ObjectName was recently updated at $lastModified. Skipping renewal."
    return
}
```

### 3. Implement Job Locking
```powershell
# Check for existing renewal lock
$lockVariable = "CertRenewal_$($ObjectName)_Lock"
try {
    $existingLock = Get-AutomationVariable -Name $lockVariable -ErrorAction Stop
    $lockTime = [DateTime]$existingLock
    if ((Get-Date) - $lockTime -lt [TimeSpan]::FromMinutes(30)) {
        Write-Output "Certificate renewal already in progress. Exiting."
        return
    }
} catch {
    # No lock exists, proceed
}

# Set renewal lock
Set-AutomationVariable -Name $lockVariable -Value (Get-Date).ToString()
```

### 4. Certificate Version Cleanup
```bash
# List all versions and disable old ones (keep latest 2-3)
az keyvault certificate list-versions --vault-name "DEMO-KV-20251103" --name "democert"
```

## Testing Plan:
1. Apply fixes one by one
2. Monitor automation jobs for 1 hour
3. Verify only 1 certificate renewal per actual near-expiry event
4. Clean up excessive certificate versions

## Prevention:
- Set up monitoring alerts for excessive job executions
- Implement certificate renewal logs review process
- Consider using managed certificates where possible