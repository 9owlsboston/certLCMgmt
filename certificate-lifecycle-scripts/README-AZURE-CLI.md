# Azure Certificate Lifecycle Management Scripts

This directory contains Azure CLI scripts to deploy a complete certificate lifecycle management system based on the Azure CertLC project.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[CERTIFICATE_IMPORT_AUTOMATION.md](./CERTIFICATE_IMPORT_AUTOMATION.md)** | Comprehensive guide for certificate import automation strategies |
| **[INTEGRATED_CA_CERTIFICATE_GENERATION.md](./INTEGRATED_CA_CERTIFICATE_GENERATION.md)** | **New!** Step-by-step guide explaining how certificates are automatically generated with integrated CAs (DigiCert, GlobalSign) |
| **[IMPLEMENTATION-PLAN.md](./IMPLEMENTATION-PLAN.md)** | Deployment roadmap and implementation strategy |
| **[example-certificate-provisioning.sh](./example-certificate-provisioning.sh)** | Practical script demonstrating certificate provisioning workflow |

## Overview

The scripts create Azure services that automatically monitor, renew, and manage SSL/TLS certificates:

- **Azure Key Vault**: Stores certificates and triggers renewal events
- **Event Grid System Topic**: Detects certificate near-expiry events  
- **Storage Account with Queue**: Queues certificate renewal requests
- **Automation Account**: Contains PowerShell runbooks for automated certificate renewal
- **Log Analytics Workspace**: Monitors certificate status and provides dashboards
- **RBAC Permissions**: Secure access control for all components

## Architecture

```
Key Vault Certificate → Event Grid → Storage Queue → Runbook → New Certificate → Key Vault
                                ↘ Webhook → Runbook ↗
                     ↓
              Log Analytics ← Data Collection ← Monitoring Runbook
```

## Configuration Management

This project uses a standardized configuration system with `.env` files for environment variable management.

### Initial Setup

1. **Create configuration from template:**
   ```bash
   cd certificate-lifecycle-scripts
   ./config.sh init
   ```

2. **Edit your configuration:**
   ```bash
   nano .env
   ```
   
   Set required values:
   ```bash
   SUBSCRIPTION_ID=your-subscription-id
   RESOURCE_GROUP_NAME=rg-certlc-prod
   KEY_VAULT_NAME=kv-certlc-prod-001
   CERTIFICATE_NAME=example-com-cert
   # ... other required values
   ```

3. **Validate configuration:**
   ```bash
   ./config.sh validate
   ```

### Configuration Files

- `.env.example` - Template file with all available options
- `.env` - Your main configuration (git-ignored)
- `.env.local` - Local overrides (git-ignored)
- `config.sh` - Configuration loader and validator

## Quick Start

### Option 1: Complete Deployment (Recommended)

Run the complete deployment script:

```bash
# Make script executable and run
chmod +x deploy-all.sh
./deploy-all.sh
```

### Option 2: Step-by-Step Deployment

Run scripts individually for more control:

```bash
# 1. Environment setup
chmod +x 01-environment-setup.sh
./01-environment-setup.sh

# 2. Core infrastructure
chmod +x 02-core-infrastructure.sh
./02-core-infrastructure.sh

# 3. Event Grid configuration
chmod +x 03-event-grid-setup.sh
./03-event-grid-setup.sh

# 4. Automation setup
chmod +x 04-automation-setup.sh
./04-automation-setup.sh

# 5. RBAC permissions
chmod +x 05-rbac-permissions.sh
./05-rbac-permissions.sh
```

## Prerequisites

- Azure CLI installed and configured
- Azure subscription with Owner or Contributor permissions
- `curl` command available (for downloading runbooks)
- Bash shell environment

## Configuration

### Environment Variables

Modify these variables in `01-environment-setup.sh`:

```bash
RESOURCE_GROUP_NAME="rg-certlc-prod"
LOCATION="eastus"
EMAIL_RECIPIENT="admin@yourdomain.com"
SMTP_SERVER="localhost"
CERT_EXPIRY_DAYS="30"
```

### Resource Naming

Resources are automatically named with a unique suffix to avoid conflicts:
- Key Vault: `kv-certlc-XXXXXX`
- Storage Account: `stcertlcXXXXXX`
- Automation Account: `aa-certlc-XXXXXX`

## Script Details

### 01-environment-setup.sh
- Sets up environment variables
- Validates Azure CLI installation and login
- Registers required Azure resource providers

### 02-core-infrastructure.sh
- Creates Resource Group
- Deploys Key Vault with RBAC authorization
- Creates Storage Account with queue services
- Sets up Automation Account with managed identity
- Creates Log Analytics workspace

### 03-event-grid-setup.sh
- Creates Event Grid system topic for Key Vault events
- Sets up event subscriptions for webhook and queue processing
- Configures data collection endpoints and rules
- Creates custom table in Log Analytics

### 04-automation-setup.sh
- Creates automation variables for configuration
- Imports PowerShell runbooks for certificate management
- Sets up webhooks for Event Grid integration
- Creates schedules for automated monitoring

### 05-rbac-permissions.sh
- Assigns Key Vault permissions (Certificates Officer, Secrets User)
- Configures Storage Account access (Queue Data Contributor)
- Sets up Log Analytics permissions (Metrics Publisher)
- Creates saved searches for certificate monitoring

### deploy-all.sh
- Runs all scripts in sequence
- Validates deployment success
- Provides comprehensive summary and next steps

## PowerShell Runbooks

The system includes two main runbooks:

### CertLifeCycleMgmt
- Main certificate lifecycle management logic
- Processes certificate near-expiry events
- Handles certificate renewal workflow
- Sends email notifications

### CertLCDashboardDataInjestion
- Collects certificate data from Key Vaults
- Sends data to Log Analytics for monitoring
- Runs on scheduled basis (every hour)

## Event Processing

The system processes certificate events through two paths:

1. **Webhook Path**: Immediate processing via webhook
2. **Queue Path**: Reliable processing via storage queue

Both paths trigger the same runbook but provide different reliability guarantees.

## Monitoring

### Log Analytics Queries

Use these queries to monitor certificate status:

```kql
// Certificate status summary
Clcdata_CL
| where TimeGenerated == toscalar(Clcdata_CL | summarize max(TimeGenerated))
| extend ExpiryStatus = case(
    todatetime(CertExpiration) <= now(), "Expired",
    todatetime(CertExpiration) <= now() + 5d, "Expiring in 5 Days",
    "Not Expired"
)
| summarize CertificateCount = count() by ExpiryStatus

// Certificate details
Clcdata_CL
| extend ExpirationDate = todatetime(CertExpiration)
| extend ExpiryStatus = case(
    ExpirationDate <= now(), "Expired",
    ExpirationDate <= now() + 5d, "Expiring in 5 Days", 
    "Not Expired"
)
| where TimeGenerated == toscalar(Clcdata_CL | summarize max(TimeGenerated))
| project ExpiryStatus, CertExpiration, CertName, CertSubject, CertRecipient, KeyVault, CertThumbprint, TimeGenerated
| sort by ExpiryStatus
```

### Automation Monitoring

Monitor automation jobs in the Azure portal:
- Check runbook execution history
- Review job outputs and errors
- Monitor webhook calls and queue processing

## Security

### RBAC Roles Applied

- **Key Vault Certificates Officer**: Manage certificates
- **Key Vault Secrets User**: Access certificate private keys
- **Storage Queue Data Contributor**: Read/write queue messages
- **Storage Queue Data Message Processor**: Process queue messages
- **Monitoring Metrics Publisher**: Send data to Log Analytics
- **Reader**: Read resource configurations

### Security Features

- Managed identities for authentication
- RBAC-based access control
- Encrypted webhook URIs
- Soft delete enabled on Key Vault
- TLS 1.2 minimum on storage accounts

## Troubleshooting

### Common Issues

1. **Module Installation Failures**
   - Check automation account region compatibility
   - Verify internet connectivity for PowerShell Gallery

2. **Permission Errors**
   - Ensure deployment account has Owner role
   - Check that managed identity is properly assigned

3. **Event Grid Issues**
   - Verify webhook URL is accessible
   - Check event subscription filters
   - Monitor Event Grid metrics

4. **Runbook Failures**
   - Check automation account modules
   - Verify managed identity permissions
   - Review runbook execution logs

### Log Sources

- **Automation Account**: Job execution logs
- **Event Grid**: Subscription metrics and delivery status
- **Storage Account**: Queue message processing
- **Log Analytics**: Certificate monitoring data

## Cost Optimization

### Resource Costs

- **Key Vault**: ~$0.03 per 10,000 operations
- **Storage Account**: ~$0.045/GB/month + operations
- **Automation Account**: ~$0.002 per minute of runbook execution
- **Event Grid**: ~$0.60 per million operations
- **Log Analytics**: ~$2.30/GB ingested

### Optimization Tips

1. Adjust monitoring schedules based on needs
2. Use retention policies to manage log costs
3. Consider regional pricing differences
4. Monitor and optimize runbook execution time

## Support

For issues related to:
- **Azure CertLC Project**: [GitHub Repository](https://github.com/Azure/certlc)
- **Azure CLI**: [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- **PowerShell Modules**: [PowerShell Gallery](https://www.powershellgallery.com/)

## Contributing

To contribute improvements to these scripts:
1. Test changes in a development environment
2. Ensure backwards compatibility
3. Update documentation
4. Submit pull requests with clear descriptions

## License

These scripts are provided as-is under the same license as the Azure CertLC project.