# Certificate Lifetime Configuration & 47-Day Transition Plan

## 🚨 **Critical Industry Change: Certificate Lifetimes Reducing to 47 Days**

Based on the DigiCert article, here's the official timeline:

### **CA/Browser Forum Timeline:**
- **Today - March 15, 2026**: Max 398 days (current)
- **March 15, 2026**: Max 200 days
- **March 15, 2027**: Max 100 days  
- **March 15, 2029**: Max **47 days** (final target)

## 🔍 **Current Configuration Analysis**

### **Your Current Setup:**
- **Certificate Validity**: 12 months (365 days) ✅ *Currently compliant*
- **Renewal Trigger**: 80% of lifetime = ~72 days before expiry
- **Certificate Policy**: Uses default Key Vault settings

### **Where Validity is Set:**

#### **1. Key Vault Certificate Policy (Primary)**
```bash
# Current setting
az keyvault certificate show --vault-name "DEMO-KV-20251103" --name "democert" --query "policy.x509CertificateProperties.validityInMonths"
# Result: 12 months
```

#### **2. PowerShell Certificate Policy Creation (Secondary)**
```powershell
# Current code (line 158):
$Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName $SubjectName -IssuerName "Unknown" -ReuseKeyOnRenewal

# ❌ Missing: -ValidityInMonths parameter
```

#### **3. Internal CA Certificate Template (Final Authority)**
- Your certificates are ultimately issued by your internal CA (CA01)
- The CA template may override Key Vault validity settings
- Template determines actual certificate lifetime

## ✅ **How to Make Certificate Expiry Configurable**

### **Option 1: Automation Variable Approach (Recommended)**

#### **Step 1: Add Automation Variable**
```bash
# Set via Azure Portal or PowerShell
Name: CertificateValidityMonths
Value: 12 (currently), then adjust as needed
Description: Certificate validity period in months for lifecycle management
```

#### **Step 2: Update PowerShell Script**
```powershell
# Add before certificate policy creation (line ~155)
try {
    $validityMonths = [int](Get-AutomationVariable -Name 'CertificateValidityMonths' -ErrorAction Stop)
    Write-Output "Using configured certificate validity: $validityMonths months"
} catch {
    $validityMonths = 12  # Default for current compliance
    Write-Output "Using default certificate validity: $validityMonths months (CertificateValidityMonths variable not set)"
}

# Update certificate policy creation
$Policy = New-AzKeyVaultCertificatePolicy `
    -SecretContentType "application/x-pkcs12" `
    -SubjectName $SubjectName `
    -IssuerName "Unknown" `
    -ReuseKeyOnRenewal `
    -ValidityInMonths $validityMonths

Write-Output "Certificate policy created with $validityMonths months validity"
```

### **Option 2: Environment-Based Configuration**
```powershell
# Set different validity based on certificate type or environment
if ($ObjectName -like "*prod*") {
    $validityMonths = 12    # Production: longer validity for stability
} elseif ($ObjectName -like "*demo*" -or $ObjectName -like "*test*") {
    $validityMonths = 1     # Demo/Test: shorter for practice with automation
} else {
    $validityMonths = 6     # Default: medium validity
}
```

### **Option 3: Template-Based at CA Level**
```powershell
# Configure different certificate templates with different validity periods
$template = switch ($certificateType) {
    "Production" { "ProductionCertTemplate" }      # 12 months
    "Staging"    { "StagingCertTemplate" }         # 6 months  
    "Demo"       { "DemoCertTemplate" }            # 1 month
    "ShortLived" { "ShortLivedCertTemplate" }      # 47 days (future)
}

$certificateRequest = Submit-CertificateRequest -CA $CA -Path $tempFile -Attribute "CertificateTemplate:$template"
```

## 🛣️ **Transition Roadmap for 47-Day Certificates**

### **Phase 1: Immediate (2025)**
1. ✅ Make validity configurable via Automation Variable
2. ✅ Test with shorter periods (1-3 months) in demo environment
3. ✅ Improve renewal threshold logic (already done)
4. ✅ Strengthen automation reliability

### **Phase 2: 2026 Preparation (200-day limit)**
1. 🔄 Set `CertificateValidityMonths = 6` (180 days)
2. 🔄 Adjust renewal threshold to 30-60 days  
3. 🔄 Test automation with higher frequency renewals
4. 🔄 Monitor automation job costs and performance

### **Phase 3: 2027 Preparation (100-day limit)**
1. 🔄 Set `CertificateValidityMonths = 3` (90 days)
2. 🔄 Adjust renewal threshold to 15-30 days
3. 🔄 Implement certificate renewal monitoring and alerting
4. 🔄 Optimize automation for monthly renewals

### **Phase 4: 2029 Preparation (47-day limit)**
1. 🔄 Set `CertificateValidityMonths = 1.5` (45 days)
2. 🔄 Adjust renewal threshold to 7-14 days
3. 🔄 Implement daily certificate health checks
4. 🔄 Consider moving to ACME protocol for full automation

## 📊 **Recommended Settings by Timeline**

| Period | Max Allowed | Recommended Setting | Renewal Threshold | Frequency |
|--------|-------------|-------------------|------------------|-----------|
| **2025** | 398 days | 12 months (365 days) | 30 days | Quarterly |
| **2026** | 200 days | 6 months (180 days) | 30 days | Bi-monthly |
| **2027** | 100 days | 3 months (90 days) | 21 days | Monthly |
| **2029** | 47 days | 1.5 months (45 days) | 14 days | Bi-weekly |

## 🔧 **Implementation Script Update**

Here's the improved certificate policy creation with configurable validity:

```powershell
# Get configurable validity period
try {
    $validityMonths = [int](Get-AutomationVariable -Name 'CertificateValidityMonths' -ErrorAction Stop)
    Write-Output "Using configured certificate validity: $validityMonths months"
} catch {
    # Default based on current industry limits
    $currentYear = (Get-Date).Year
    if ($currentYear -ge 2029) {
        $validityMonths = 1.5  # 47 days = ~1.5 months
    } elseif ($currentYear -ge 2027) {
        $validityMonths = 3    # 100 days = ~3 months
    } elseif ($currentYear -ge 2026) {
        $validityMonths = 6    # 200 days = ~6 months
    } else {
        $validityMonths = 12   # Current standard
    }
    Write-Output "Using automatic validity based on year $currentYear: $validityMonths months"
}

# Create certificate policy with configurable validity
$Policy = New-AzKeyVaultCertificatePolicy `
    -SecretContentType "application/x-pkcs12" `
    -SubjectName $SubjectName `
    -IssuerName "Unknown" `
    -ReuseKeyOnRenewal `
    -ValidityInMonths $validityMonths

Write-Output "Certificate policy created with $validityMonths months validity ($(($validityMonths * 30)) days approximately)"
```

## 🎯 **Next Steps**

1. **Implement configurable validity** (Automation Variable approach)
2. **Test with shorter certificates** (3-6 months) in demo environment
3. **Monitor automation performance** with increased renewal frequency
4. **Plan CA template updates** for different validity periods
5. **Consider ACME adoption** for long-term automation strategy

The **47-day future is coming** - but your automation system is already well-positioned to handle it! 🚀