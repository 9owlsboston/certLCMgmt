# Certificate Lifecycle Management - Production Base Deployment Guide

## Overview

The Production Base deployment creates the essential Azure infrastructure for automated certificate lifecycle management in existing enterprise environments. This deployment is designed to integrate with your existing Certificate Authority infrastructure and requires manual configuration steps to connect with your environment.

## Architecture Components

### Azure Resources Deployed:
1. **Azure Key Vault** - Secure storage for certificates and secrets
2. **Event Grid System Topic** - Event-driven automation for certificate expiration
3. **Storage Account** - Queue storage for certificate renewal requests
4. **Automation Account** - PowerShell runbooks and automation workflows

### Integration Points (Manual Configuration Required):
1. **Hybrid Runbook Worker** - Installed on your Certificate Authority server
2. **Certificate Authority** - Your existing Microsoft Certificate Services infrastructure
3. **SMTP Server** - Your existing email infrastructure for notifications
4. **Target Servers** - Servers that receive renewed certificates via Key Vault extension

## Prerequisites

### Azure Requirements:
- **Azure Subscription** with Owner role
- **Resource Group** (new or existing)
- **Unique Resource Names** for globally unique resources

### Infrastructure Requirements:
- **Windows Server** with Certificate Services (Enterprise CA recommended)
- **Active Directory Domain** (for certificate templates and permissions)
- **SMTP Server** (for email notifications)
- **Network Connectivity** from CA server to Azure (HTTPS/443)

### Permissions Required:
- **Azure Subscription Owner** (for deployment and RBAC assignments)
- **Domain Admin** or **Enterprise Admin** (for CA template permissions)
- **Local Admin** on CA server (for Hybrid Worker installation)

## Step-by-Step Deployment Process

### 1. Deploy Azure Infrastructure

**Deployment Time:** Approximately 2 minutes

1. **Access the Deployment Template**:
   - Use the "Deploy to Azure" button for Production Base deployment
   - Or direct link: `https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcertlc%2Fmain%2F.armtemplate%2Fmindeploy.json`

2. **Configure Required Parameters**:
   ```
   Subscription: [Your Azure Subscription]
   Resource Group: [Create new or select existing]
   Region: [Your preferred region - should be close to your CA server]
   
   Key Vault Name: [Globally unique name, e.g., "contoso-certlc-kv-prod"]
   Event Grid Name: [Globally unique name, e.g., "contoso-certlc-eg-prod"]
   Storage Account Name: [Globally unique name, lowercase, e.g., "contosocertlcprod"]
   Automation Account Name: [Unique name, e.g., "contoso-certlc-aa-prod"]
   
   CA Server: [FQDN of your Certificate Authority, e.g., "ca01.contoso.com"]
   SMTP Server: [FQDN or IP of your SMTP server, e.g., "mail.contoso.com"]
   ```

3. **Optional Parameters** (can use defaults):
   ```
   Webhook Name: clc-webhook
   Worker Group Name: EnterpriseCA
   Webhook Expiry Time: [1 year from deployment]
   Schedule Start Time: [1 hour from deployment]
   ```

4. **Start Deployment**:
   - Review all parameters
   - Click "Create" to begin deployment
   - Monitor progress in Azure portal

### 2. Configure Hybrid Runbook Worker

After Azure deployment completes, configure the Hybrid Worker on your CA server:

#### **Install Azure Hybrid Worker Extension**:

1. **Connect to your Certificate Authority server**
2. **Install the Hybrid Worker Extension**:
   ```powershell
   # Run on CA server as Administrator
   # Replace with your actual values
   $ResourceGroupName = "your-resource-group"
   $AutomationAccountName = "your-automation-account-name"
   $WorkerGroupName = "EnterpriseCA"
   $VmName = $env:COMPUTERNAME
   
   # Install the extension
   Set-AzVMExtension -ResourceGroupName $ResourceGroupName `
     -VMName $VmName `
     -Name "HybridWorkerExtension" `
     -Publisher "Microsoft.Azure.Automation.HybridWorker" `
     -ExtensionType "HybridWorkerForWindows" `
     -TypeHandlerVersion "1.1" `
     -Settings @{
       "AutomationAccountURL" = "https://$AutomationAccountName.azure-automation.net"
       "WorkerGroupName" = $WorkerGroupName
     }
   ```

#### **Install Required PowerShell Modules**:

1. **Run on CA server as Administrator**:
   ```powershell
   # Install required PowerShell modules for certificate lifecycle automation
   Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
   Register-PSRepository -Default -InstallationPolicy Trusted
   
   # Install specific module versions (tested and verified)
   Install-Module Az.Resources -RequiredVersion 6.6.0 -Repository PSGallery -Scope AllUsers -Force
   Install-Module Az.Compute -RequiredVersion 5.7.0 -Repository PSGallery -Scope AllUsers -Force
   Install-Module Az.Storage -RequiredVersion 5.5.0 -Repository PSGallery -Scope AllUsers -Force
   Install-Module Az.KeyVault -RequiredVersion 4.9.2 -Repository PSGallery -Scope AllUsers -Force
   Install-Module Az.Accounts -RequiredVersion 2.12.1 -Repository PSGallery -Scope AllUsers -Force
   Install-Module PSPKI -Repository PSGallery -Scope AllUsers -Force
   ```

2. **Verify Module Installation**:
   ```powershell
   # Verify modules are installed correctly
   Get-Module -ListAvailable Az.* | Select Name, Version
   Get-Module -ListAvailable PSPKI | Select Name, Version
   ```

### 3. Configure Certificate Authority Permissions

#### **Grant Permissions to Hybrid Worker**:

1. **Open Certificate Templates Console** on CA server:
   ```
   Start → Run → certtmpl.msc
   ```

2. **Configure Template Permissions**:
   - Right-click the certificate template used for automated certificates
   - Select "Properties" → "Security" tab
   - Add the CA server's computer account (e.g., "CA01$")
   - Grant "Read" and "Enroll" permissions
   - Click "OK" to save changes

3. **Alternative Method - PowerShell**:
   ```powershell
   # Grant permissions programmatically
   $TemplateName = "WebServer"  # Replace with your template name
   $ComputerAccount = "$env:COMPUTERNAME$"
   
   # Use PSPKI module to set permissions
   Import-Module PSPKI
   $Template = Get-CertificateTemplate -Name $TemplateName
   # Add computer account with Read and Enroll permissions
   # (Specific commands depend on your template configuration)
   ```

### 4. Configure Key Vault Extension on Target Servers

Install the Key Vault extension on servers that need to receive renewed certificates:

#### **For Azure VMs**:
```powershell
# Run for each target Azure VM
$ResourceGroupName = "your-vm-resource-group"
$VmName = "your-target-server"
$KeyVaultName = "your-key-vault-name"
$CertificateName = "your-certificate-name"
$PollingInterval = "43200"  # 12 hours

$Settings = @{
    secretsManagementSettings = @{
        pollingIntervalInS = $PollingInterval
        linkOnRenewal = $false
        observedCertificates = @(
            @{
                url = "https://$KeyVaultName.vault.azure.net:443/secrets/$CertificateName"
                certificateStoreName = "My"
                certificateStoreLocation = "LocalMachine"
            }
        )
    }
    authenticationSettings = @{
        msiEndpoint = "http://169.254.169.254/metadata/identity"
    }
}

Set-AzVMExtension -ResourceGroupName $ResourceGroupName `
  -VMName $VmName `
  -Name "KeyVaultForWindows" `
  -Publisher "Microsoft.Azure.KeyVault" `
  -Type "KeyVaultForWindows" `
  -TypeHandlerVersion "3.0" `
  -SettingString ($Settings | ConvertTo-Json -Depth 10)
```

#### **For Azure Arc Servers**:
```powershell
# Run for each Azure Arc connected server
$ResourceGroupName = "your-arc-resource-group"
$MachineName = "your-arc-server"
$KeyVaultName = "your-key-vault-name"
$CertificateName = "your-certificate-name"
$PollingInterval = "43200"

$Settings = @{
    secretsManagementSettings = @{
        pollingIntervalInS = $PollingInterval
        observedCertificates = @(
            "https://$KeyVaultName.vault.azure.net:443/secrets/$CertificateName"
        )
        certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault.Store/"
    }
    authenticationSettings = @{
        msiEndpoint = "http://localhost:40342/metadata/identity"
    }
}

New-AzConnectedMachineExtension -ResourceGroupName $ResourceGroupName `
  -MachineName $MachineName `
  -Name "KeyVaultForLinux" `
  -Location "East US" `
  -Publisher "Microsoft.Azure.KeyVault" `
  -ExtensionType "KeyVaultForLinux" `
  -Setting $Settings
```

### 5. Configure Azure RBAC Permissions

#### **Grant Key Vault Permissions**:

1. **Navigate to your Key Vault** in Azure portal
2. **Go to Access Control (IAM)**
3. **Add Role Assignments**:
   - **Automation Account Managed Identity**:
     - Role: "Key Vault Certificate Officer"
     - Assignee: Your Automation Account's managed identity
   
   - **Target Server Managed Identities**:
     - Role: "Key Vault Secret User"
     - Assignee: Each target server's managed identity

#### **Verify Managed Identity**:
```powershell
# Verify Automation Account managed identity is enabled
$ResourceGroupName = "your-resource-group"
$AutomationAccountName = "your-automation-account"

$AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
$AutomationAccount.Identity
```

### 6. Import and Tag Certificates

#### **Import Certificates to Key Vault**:

1. **Using Azure Portal**:
   - Navigate to Key Vault → Certificates
   - Click "Generate/Import"
   - Choose "Import" method
   - Upload your certificate file (.pfx or .p12)
   - Set password if required
   - Click "Create"

2. **Using PowerShell**:
   ```powershell
   # Import certificate to Key Vault
   $VaultName = "your-key-vault-name"
   $CertificateName = "your-certificate-name"
   $CertificateFilePath = "C:\path\to\certificate.pfx"
   $CertificatePassword = ConvertTo-SecureString "password" -AsPlainText -Force
   
   Import-AzKeyVaultCertificate -VaultName $VaultName `
     -Name $CertificateName `
     -FilePath $CertificateFilePath `
     -Password $CertificatePassword
   ```

#### **Add Required Tags**:

**Critical Step**: Tag certificates with recipient information for notifications.

```powershell
# Add recipient tag for email notifications
$VaultName = "your-key-vault-name"
$CertificateName = "your-certificate-name"
$Recipients = "admin@contoso.com,security@contoso.com"  # Multiple recipients separated by comma

# Get current certificate
$Certificate = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertificateName

# Add recipient tag
$Tags = @{
    "Recipient" = $Recipients
    "Environment" = "Production"
    "Owner" = "IT Security Team"
}

Set-AzKeyVaultCertificate -VaultName $VaultName `
  -Name $CertificateName `
  -Tag $Tags
```

### 7. Configure Network and Firewall

#### **Required Network Connectivity**:

1. **From CA Server to Azure**:
   - HTTPS (443) to *.azure-automation.net
   - HTTPS (443) to *.vault.azure.net
   - HTTPS (443) to *.queue.core.windows.net
   - HTTPS (443) to *.servicebus.windows.net

2. **From CA Server to SMTP Server**:
   - SMTP (25) or SMTPS (587/465) to your SMTP server
   - Configure firewall rules as needed

#### **Test Connectivity**:
```powershell
# Test connectivity from CA server
Test-NetConnection -ComputerName "your-automation-account.azure-automation.net" -Port 443
Test-NetConnection -ComputerName "your-key-vault.vault.azure.net" -Port 443
Test-NetConnection -ComputerName "your-smtp-server.contoso.com" -Port 25
```

## Testing and Validation

### 1. Test Hybrid Worker Connectivity

```powershell
# On CA server, verify Hybrid Worker registration
Get-Service -Name "Hybrid Worker*"
Get-EventLog -LogName Application -Source "Hybrid Worker" -Newest 10
```

### 2. Test Certificate Renewal Process

#### **Manual Test**:
1. **Create a test certificate** with short validity period
2. **Import to Key Vault** with recipient tags
3. **Trigger Event Grid** manually or wait for near-expiration event
4. **Monitor Automation Account** job execution
5. **Verify renewed certificate** appears in Key Vault

#### **Webhook Test**:
```powershell
# Get webhook URL from Automation Account
$ResourceGroupName = "your-resource-group"
$AutomationAccountName = "your-automation-account"
$WebhookName = "clc-webhook"

# Test webhook trigger (replace with actual webhook URL)
$WebhookUrl = "https://your-automation-webhook-url"
$TestData = @{
    data = @{
        VaultName = "your-key-vault-name"
        ObjectName = "test-certificate"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $TestData -ContentType "application/json"
```

### 3. Test Email Notifications

1. **Check SMTP connectivity** from CA server
2. **Verify email delivery** to tagged recipients
3. **Review email format** and content

### 4. Test Certificate Distribution

1. **Verify Key Vault extension** installation on target servers
2. **Check certificate store** on target servers for renewed certificates
3. **Monitor polling intervals** and certificate updates

## Monitoring and Troubleshooting

### Common Issues and Solutions

#### **Hybrid Worker Registration Issues**:
- Verify Azure connectivity from CA server
- Check firewall rules and proxy settings
- Ensure Automation Account managed identity is enabled
- Review Windows Event Logs for Hybrid Worker errors

#### **Certificate Renewal Failures**:
- Check CA server permissions on certificate templates
- Verify PowerShell module versions and compatibility
- Review Automation Account job logs for detailed errors
- Ensure Key Vault RBAC permissions are correctly assigned

#### **Email Notification Issues**:
- Test SMTP connectivity from CA server
- Verify SMTP server configuration and authentication
- Check certificate tags for recipient information
- Review runbook logs for email sending errors

#### **Certificate Distribution Issues**:
- Verify Key Vault extension configuration on target servers
- Check managed identity permissions on Key Vault
- Review polling intervals and certificate store locations
- Monitor Key Vault access logs for retrieval attempts

### Monitoring Resources

1. **Automation Account Jobs**:
   - Monitor runbook execution status
   - Review job output logs for errors
   - Set up job failure alerts

2. **Event Grid Metrics**:
   - Track event delivery success rates
   - Monitor webhook trigger frequency
   - Set up alerts for delivery failures

3. **Key Vault Metrics**:
   - Monitor certificate access patterns
   - Track certificate renewal cycles
   - Set up alerts for access failures

4. **Storage Queue Metrics**:
   - Monitor queue message processing
   - Track message age and delivery
   - Set up alerts for queue backlogs

## Security Considerations

### Access Control
- Use Azure RBAC for granular Key Vault access
- Implement least-privilege principle for managed identities
- Regular review of certificate access permissions
- Monitor Key Vault access logs

### Network Security
- Use private endpoints for Key Vault access where possible
- Implement network security groups for traffic filtering
- Consider Azure Firewall for outbound traffic control
- Use VPN or ExpressRoute for hybrid connectivity

### Certificate Security
- Regular rotation of certificates and keys
- Secure storage of certificate passwords and secrets
- Audit certificate usage and access patterns
- Implement certificate lifecycle policies

## Operational Procedures

### Regular Maintenance
- **Monthly**: Review certificate expiration dates and renewal schedules
- **Quarterly**: Update PowerShell modules on Hybrid Workers
- **Annually**: Review and update certificate templates and policies

### Disaster Recovery
- **Backup**: Key Vault certificates and configuration
- **Documentation**: Current certificate inventory and dependencies
- **Testing**: Regular disaster recovery procedures
- **Monitoring**: Automated alerts for certificate-related issues

## Next Steps

After successful production deployment:

1. **Deploy Optional Dashboard** for certificate monitoring
2. **Implement additional certificate templates** as needed
3. **Scale to additional Certificate Authorities** if required
4. **Integrate with existing monitoring systems**
5. **Develop operational runbooks** for common scenarios

The production base deployment provides a solid foundation for enterprise certificate lifecycle management that can be extended and customized based on your specific requirements.