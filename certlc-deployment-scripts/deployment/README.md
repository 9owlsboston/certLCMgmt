# Certificate Lifecycle Deployment Scripts

This directory contains deployment scripts and ARM templates for certificate lifecycle management.

## 🚀 Deployment Scripts

### Main Deployment
- **`deploy.sh`** - Primary deployment script using ARM templates

### Specialized Deployments
- **`deploy-keyvault-only.sh`** - Deploy only Key Vault components
- **`deploy-missing-resources.sh`** - Deploy missing or failed resources

## 📋 Templates and Configuration

### ARM Templates
- **`keyvault-only-template.json`** - Key Vault-specific ARM template

### Configuration
- **`parameters.json`** - Configuration parameters template

## 🚀 Quick Start

```bash
# Full deployment
./deploy.sh

# Key Vault only
./deploy-keyvault-only.sh

# Fix missing resources
./deploy-missing-resources.sh
```

## 📚 Documentation

See `../docs/DEPLOYMENT_OVERVIEW.md` for comprehensive deployment guidance.