# Certificate Lifecycle Diagnostics

This directory contains diagnostic and troubleshooting tools for certificate lifecycle management.

## 🔍 Diagnostic Tools

### Deployment Diagnostics
- **`check-deployment-status.sh`** - Check status of Azure resource deployments

### Key Vault Diagnostics  
- **`check-keyvault-names.sh`** - Validate Key Vault naming availability and diagnose soft delete issues
- **`diagnose-keyvault.sh`** - Comprehensive Key Vault diagnostics and troubleshooting
- **`fix-keyvault-access.sh`** - 🆕 Fix Key Vault network access issues (public access disabled, firewall rules)

## 🚀 Quick Start

```bash
# Check deployment status
./check-deployment-status.sh

# Diagnose Key Vault issues
./diagnose-keyvault.sh

# Check Key Vault name availability (for ARM template redeployment)
./check-keyvault-names.sh

# Fix Key Vault network access issues
./fix-keyvault-access.sh
```

## 🔧 When to Use

### Use `check-deployment-status.sh` when:
- Deployments fail or show errors
- Need to verify resource provisioning
- Troubleshooting ARM template issues

### Use `diagnose-keyvault.sh` when:
- Key Vault access issues
- Certificate operations fail
- Permission or networking problems

### Use `fix-keyvault-access.sh` when: 🆕
- Getting "Public network access is disabled" errors
- Need to temporarily enable Key Vault access for management
- Firewall rules blocking your IP address
- Setting up trusted service bypass for Azure services

### Use `check-keyvault-names.sh` when:
- Planning new Key Vault deployments
- Name conflicts during ARM template redeployment (soft delete issues)
- Validating naming conventions

## 📚 Documentation

See `../docs/` for detailed troubleshooting guides and diagnostic procedures.