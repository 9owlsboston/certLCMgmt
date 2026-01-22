# Archived Testing Scripts

These scripts have been archived because they contain outdated configurations or have been superseded by newer versions.

## 🗂️ Archived Scripts

### Obsolete Certificate Creation Scripts
- **`create-shortlived-cert.ps1`** - Original version (hardcoded DEMO-KV-1030164500)
- **`create-shortlived-cert-enhanced.ps1`** - Enhanced version (hardcoded DEMO-KV-1030164500)  
- **`create-shortlived-cert-fixed.ps1`** - Fixed version (hardcoded DEMO-KV-1030164500)

### Obsolete Diagnostic Scripts
- **`diagnose-keyvault-connectivity.ps1`** - Old Key Vault diagnostic (hardcoded DEMO-KV-1030164500)
- **`diagnose-dc01-issues.ps1`** - Old DC01 diagnostic (hardcoded DEMO-KV-1030164500)

## ❌ Why Archived

All these scripts were using the hardcoded Key Vault name `"DEMO-KV-1030164500"` which:
- No longer exists or is incorrect
- Caused DNS resolution failures
- Made scripts inflexible for different deployments

## ✅ Current Replacements

| Archived Script | Current Replacement | Improvement |
|----------------|-------------------|-------------|
| `create-shortlived-cert.ps1` | `create-shortlived-cert-robust.ps1` | Uses .env config, retry logic |
| `create-shortlived-cert-enhanced.ps1` | `create-shortlived-cert-robust.ps1` | Uses .env config, better error handling |
| `create-shortlived-cert-fixed.ps1` | `create-shortlived-cert-robust.ps1` | Uses .env config, network diagnostics |
| `diagnose-keyvault-connectivity.ps1` | `test-keyvault-dns.ps1` | Uses .env config, multiple DNS servers |
| `diagnose-dc01-issues.ps1` | `diagnose-dc01-network.ps1` | Uses .env config, comprehensive testing |

## 🔄 Migration Notes

If you need to restore any functionality from these scripts:
1. Check the current replacement script first
2. Copy any unique logic to the current scripts
3. Ensure .env configuration is used instead of hardcoded values
4. Test thoroughly with current Key Vault name

## 📅 Archive Date
November 3, 2025 - Cleaned up during PowerShell .env configuration implementation.