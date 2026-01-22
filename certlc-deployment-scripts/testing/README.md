# Certificate Testing and Development Tools

This directory contains tools for creating test certificates and manual certificate operations.

## 🧪 Testing Tools

### Test Certificate Creation
- **`create-expired-cert.ps1`** - Create expired certificates for testing renewal processes
- **`create-shortlived-cert.ps1`** - Create short-lived certificates for testing automation

### Manual Operations
- **`manual-cert-creation.ps1`** - Manual certificate creation and management utilities

## 🚀 Quick Start

```powershell
# Create a short-lived test certificate
.\create-shortlived-cert.ps1 -CertificateName "test-cert" -ValidityHours 2

# Create an expired certificate for testing
.\create-expired-cert.ps1 -CertificateName "expired-test"

# Manual certificate operations
.\manual-cert-creation.ps1
```

## 📋 Testing Workflow

1. **Create Test Certificate**: Use `create-shortlived-cert.ps1`
2. **Monitor Renewal**: Use `../monitoring/cert-quick-status.sh`
3. **Analyze Results**: Use `../monitoring/cert-lifecycle-events.ps1`
4. **Cleanup**: Remove test certificates when done

## 📚 Documentation

# Certificate Testing Scripts

This folder contains the current, working scripts for testing certificate lifecycle management. All scripts now use configuration from the `.env` file.

## 🚀 Quick Start

1. **Verify Configuration:**
   ```powershell
   .\verify-config.ps1
   ```
   Confirms PowerShell can read the `.env` file and shows current Key Vault name.

2. **Network Diagnostics:**
   ```powershell
   .\diagnose-dc01-network.ps1
   ```
   Comprehensive network connectivity testing for DC01 (run on DC01).

3. **DNS Diagnostics:**
   ```powershell
   .\test-keyvault-dns.ps1
   ```
   Specific DNS testing for Key Vault endpoints.

4. **Create Test Certificate:**
   ```powershell
   .\create-shortlived-cert-robust.ps1
   ```
   Creates a 2-minute expiry certificate for immediate testing.

## 📁 Current Scripts

### 🔧 Core Testing Scripts
- **`verify-config.ps1`** - Verify .env configuration loading
- **`create-shortlived-cert-robust.ps1`** - Main certificate creation script (2-min expiry)
- **`diagnose-dc01-network.ps1`** - Network connectivity diagnostic for DC01
- **`test-keyvault-dns.ps1`** - Key Vault DNS resolution testing

### 🛠️ Utility Scripts  
- **`create-expired-cert.ps1`** - Create already-expired certificates
- **`manual-cert-creation.ps1`** - Manual certificate creation process
- **`install-azure-modules-dc01.ps1`** - Install Azure PowerShell modules on DC01

### 📋 Additional Files
- **`create-shortlived-cert-python.py`** - Python version of certificate creation
- **`CA01_NETWORK_ISOLATION_SOLUTION.md`** - Network isolation solutions

## ⚙️ Configuration

All scripts automatically load configuration from `../env` using the `Config-Loader.psm1` module:

- **KEY_VAULT_NAME** - Current: `DEMO-KV-20251103`
- **RESOURCE_GROUP** - Current: `rg-demo-certlc`
- **RECIPIENT_EMAIL** - For certificate notifications

## 🗂️ Archive

Obsolete script versions have been moved to `./archive/` folder:
- Old scripts with hardcoded Key Vault names
- Previous iterations and test versions

## 🎯 Recommended Workflow

1. Run `verify-config.ps1` to confirm setup
2. If network issues on DC01, run `diagnose-dc01-network.ps1`
3. For DNS issues, run `test-keyvault-dns.ps1`  
4. Create test certificates with `create-shortlived-cert-robust.ps1`
5. Monitor certificate expiry and renewal

## 💡 Troubleshooting

- **Configuration issues:** Check `.env` file exists and contains required values
- **Network issues:** Run diagnostic scripts to identify specific problems
- **DNS issues:** May indicate corporate filtering or Key Vault name problems
- **Authentication issues:** Ensure Azure PowerShell is connected with proper permissions