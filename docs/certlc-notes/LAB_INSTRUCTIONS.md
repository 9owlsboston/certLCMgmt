# Certificate Lifecycle Management LAB Deployment Guide

## Architecture Overview

The LAB environment creates a complete **automated certificate renewal system** for non-integrated Certificate Authorities. This is a fully functional demo environment that requires no manual configuration.

### Key Components Deployed:
1. **Virtual Network Infrastructure**:
   - **Domain Controller (DC01)** - Windows Server with Active Directory Domain Services
   - **Certificate Authority (CA01)** - Windows Server with Enterprise Root CA + SMTP server

2. **Azure Services**:
   - **Key Vault** - Stores certificates and triggers renewal events
   - **Event Grid System Topic** - Detects certificate expiration events
   - **Storage Account** - Queues certificate renewal requests
   - **Automation Account** - Contains PowerShell runbooks and hybrid worker configuration
   - **Log Analytics Workspace** - Stores certificate monitoring data
   - **Azure Workbook** - Dashboard for certificate status visualization

3. **Automation Components**:
   - **PowerShell Runbooks** - Automated certificate renewal logic
   - **Hybrid Worker Group** - Enables runbook execution on CA server
   - **Event Grid Subscriptions** - Links Key Vault events to renewal workflow
   - **Key Vault Extension** - Automatically deploys renewed certificates to target servers

## Architecture Workflow

```
Key Vault Certificate → Event Grid → Storage Queue → Runbook (on CA) → New Certificate → Key Vault → Target Servers
```

## Prerequisites

- **Azure Subscription** with Owner role
- **Unique String** for globally unique resource names (replace `UNIQUESTRING` placeholders)
- **Valid Email Address** for certificate renewal notifications

## Step-by-Step Deployment Process

### 1. Deploy the LAB Environment

**Deployment Time:** Approximately 30 minutes

1. **Access the Deployment Template**:
   - Click the "Deploy to Azure" button for LAB deployment from the repository
   - Or use direct link: `https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcertlc%2Fmain%2F.armtemplate%2Ffulllabdeploy.json`

2. **Configure Required Parameters**:
   ```
   Subscription: [Your Azure Subscription]
   Resource Group: [Create new or select existing]
   Region: [Your preferred region]
   
   Domain Admin Password: [Secure password for domain administrator]
   CA Admin Password: [Secure password for CA administrator]
   
   Key Vault Name: DEMO-KV-<UNIQUESTRING>
   Event Grid Name: DEMO-EG-<UNIQUESTRING>
   Storage Account Name: demosa<UNIQUESTRING>
   Automation Account Name: DEMO-AA-<UNIQUESTRING>
   
   Recipient: [Your email address for notifications]
   ```

3. **Default Parameters** (recommended to keep):
   ```
   Virtual Network Name: ad-vnet
   Virtual Network Address Range: 10.0.0.0/16
   Subnet Name: ad-vnet-subnet
   Subnet Range: 10.0.0.0/24
   Domain Name: demo.com
   Domain Administrator User Name: demoadmin
   DC VM Size: Standard_D2s_v3
   DC VM Name: dc01
   CA VM Size: Standard_D2s_v3
   CA VM Name: ca01
   CA Admin User Name: caadmin
   ```

4. **Start Deployment**:
   - Review all parameters
   - Accept terms and conditions
   - Click "Create"
   - Monitor deployment progress in Azure portal

### 2. Access the LAB Environment

After deployment completes successfully:

1. **Connect to Domain Controller (DC01)**:
   - Navigate to the deployed resource group
   - Find the DC01 virtual machine
   - Click "Connect" → "RDP"
   - Download RDP file
   - Connect using credentials:
     - Username: `demo.com\demoadmin`
     - Password: [Your domain admin password]

2. **Connect to Certificate Authority (CA01)**:
   - From DC01, open Remote Desktop Connection
   - Connect to `ca01.demo.com`
   - Use the same domain credentials
   - This server hosts the Enterprise CA and SMTP services

## Step-by-Step Testing Process

### 3. Verify Initial Certificate Creation

1. **Check Azure Key Vault**:
   - Navigate to Azure portal → Resource Groups → [Your RG]
   - Open the Key Vault (`DEMO-KV-<UNIQUESTRING>`)
   - Go to **Objects** → **Certificates**
   - Verify the `democert` certificate exists
   - Note the 5-day validity period (configured for demo purposes)
   
   > **Note**: You need "Key Vault Certificate Officer" role to view certificates

2. **Examine Certificate Details**:
   - Click on the `democert` certificate
   - Check the **Tags** section for the "Recipient" tag
   - Note the expiration date and thumbprint

### 4. Monitor the Automated Renewal Workflow

The system automatically performs these steps when a certificate nears expiration:

#### **Phase 1: Event Detection**
1. Key Vault monitors certificate expiration (configurable threshold)
2. Event Grid receives the `CertificateNearExpiry` event
3. Event Grid triggers the configured webhook
4. Webhook queues the renewal request in Storage Account

#### **Phase 2: Certificate Renewal**
The PowerShell runbook executes on CA01 as a Hybrid Worker:
1. Reads certificate details from the storage queue
2. Authenticates to Azure using the Automation Account's managed identity
3. Retrieves certificate template OID and recipient information
4. Requests a new CSR (Certificate Signing Request) from Key Vault
5. Submits CSR to the local Enterprise CA
6. Receives the new certificate from CA
7. Uploads renewed certificate to Key Vault
8. Sends email notification to recipients

#### **Phase 3: Certificate Distribution**
1. Key Vault extension on target servers polls for certificate updates
2. New certificate is automatically downloaded and installed
3. Old certificate is replaced in the local certificate store

### 5. Verify Renewal Process Components

#### **Check Event Grid Activity**:
1. Navigate to your Event Grid System Topic (`DEMO-EG-<UNIQUESTRING>`)
2. Go to **Event Subscriptions**
3. Click on the **CertLC** subscription
4. View the **Metrics** tab to see event activity
5. Check **Events** for webhook trigger history

#### **Verify Storage Queue Messages**:
1. Navigate to your Storage Account (`demosa<UNIQUESTRING>`)
2. Go to **Data storage** → **Queues**
3. Click on the **certlc** queue
4. Monitor for queued certificate renewal messages

#### **Monitor Runbook Execution**:
1. Navigate to your Automation Account (`DEMO-AA-<UNIQUESTRING>`)
2. Go to **Process Automation** → **Runbooks**
3. Click on **CertLCv3** runbook
4. Check **Jobs** tab for execution history
5. Review job output for detailed renewal process logs

### 6. Verify Certificate Authority Operations

#### **Check CA Certificate Issuance**:
1. RDP to CA01 server
2. Open **Server Manager** → **Tools** → **Certification Authority**
3. Expand your CA name → **Issued Certificates**
4. Look for renewed certificates (should appear after runbook execution)
5. Verify certificate details match the renewal request

#### **Check SMTP Server Logs**:
1. On CA01, navigate to **C:\inetpub\mailroot\Drop**
2. Look for `.eml` files containing notification emails
3. Open **MailViewer** tool from desktop
4. Select recent `.eml` files to view sent notifications

### 7. Verify Certificate Deployment to Target Servers

#### **Check Key Vault Certificate Update**:
1. Return to Azure Key Vault in portal
2. Navigate to **Certificates** → **democert**
3. Verify new certificate version appears
4. Check that **Tags** (especially "Recipient") are preserved
5. Compare thumbprints to confirm renewal

#### **Verify Client Certificate Installation**:
1. RDP to DC01 server
2. Open **Certificate Manager** (`certmgr.msc`)
3. Navigate to **Personal** → **Certificates**
4. Look for the renewed certificate (appears after Key Vault extension polling)
5. Verify certificate properties and validity period

### 8. Test the Monitoring Dashboard

#### **Run Dashboard Data Collection**:
1. Navigate to Automation Account in Azure portal
2. Go to **Runbooks** → **CertLCDashboardDataIngestion**
3. Click **Start** to manually trigger data collection
4. Monitor job execution and output

#### **View Certificate Status Dashboard**:
1. Navigate to **Monitor** in Azure portal
2. Select **Workbooks**
3. Find your certificate monitoring workbook
4. Open the workbook to view:
   - **Pie Chart**: Certificate status distribution
   - **Data Table**: Detailed certificate information
   - **Status Colors**:
     - 🟢 **Green**: Not Expired certificates
     - 🟡 **Yellow**: Expiring Soon certificates
     - 🔴 **Red**: Expired certificates

> **Note**: The LAB includes fake data entries to demonstrate all possible certificate statuses

## Manual Testing Scenarios

### Test Certificate Renewal Trigger

1. **Force Certificate Near Expiration**:
   - Modify the certificate's expiration date in Key Vault
   - Or adjust Event Grid subscription filters
   - Monitor subsequent automation workflow

2. **Manual Webhook Trigger**:
   - Get webhook URL from Event Grid subscription
   - Send test POST request with certificate data
   - Verify runbook execution and certificate renewal

### Test Email Notifications

1. **Update Recipient Information**:
   - Modify certificate tags in Key Vault
   - Add multiple recipient email addresses
   - Trigger renewal and verify notifications

2. **Check SMTP Functionality**:
   - Review MailViewer on CA01
   - Verify email formatting and content
   - Test with different recipient configurations

### Test Certificate Templates

1. **Create Additional Templates**:
   - On CA01, open Certificate Templates console
   - Create new templates with different properties
   - Issue certificates using new templates
   - Verify renewal process works with custom templates

## Troubleshooting Guide

### Common Issues and Solutions

1. **Missing `democert` Certificate in Key Vault**:
   - **Check Permissions**: Ensure you have "Key Vault Certificate Officer" role to view certificates
   - **Verify Deployment**: Check Azure portal deployments for failures
   - **Check CA Server**: RDP to CA01 and verify DSC script execution completed
   - **Manual Creation**: Use the provided manual certificate creation script
   - **Script Logs**: Check Windows Event Logs on CA01 for DSC errors

2. **Deployment Failures**:
   - Verify unique strings are globally unique
   - Check subscription quotas and limits
   - Ensure proper permissions on subscription
   - Validate all required parameters are provided

3. **RDP Connection Issues**:
   - Verify Network Security Group rules
   - Check VM status and networking
   - Confirm credentials and domain join status
   - Ensure VMs are fully deployed before connecting

4. **Certificate Template Issues**:
   - Verify "webservershort" template exists on CA01
   - Check template permissions for computer accounts
   - Ensure CA service is running
   - Verify domain join and AD connectivity

5. **Azure Connectivity from CA Server**:
   - Test HTTPS connectivity to *.vault.azure.net
   - Verify managed identity is enabled on CA01 VM
   - Check Azure PowerShell modules are installed
   - Validate Key Vault access policies

6. **Certificate Renewal Failures**:
   - Check Hybrid Worker connectivity
   - Verify managed identity permissions
   - Review runbook execution logs
   - Ensure certificate has proper tags

7. **Dashboard Data Missing**:
   - Manually run data ingestion runbook
   - Verify Log Analytics workspace permissions
   - Check Data Collection Rule configuration

## Validation Checklist

Use this checklist to verify successful LAB deployment and testing:

- [ ] **Deployment Phase**:
  - [ ] LAB ARM template deployed successfully (~30 minutes)
  - [ ] All Azure resources created in resource group
  - [ ] No deployment errors in Azure portal

- [ ] **Access Phase**:
  - [ ] Can RDP to DC01 using domain credentials
  - [ ] Can RDP to CA01 from DC01
  - [ ] Both VMs joined to demo.com domain

- [ ] **Certificate Creation Phase**:
  - [ ] Initial `democert` certificate visible in Key Vault
  - [ ] Certificate has 5-day validity period
  - [ ] Certificate tags include recipient information

- [ ] **Automation Phase**:
  - [ ] Event Grid subscription configured and active
  - [ ] Storage queue receiving certificate events
  - [ ] Automation Account runbooks deployed
  - [ ] Hybrid Worker Group configured on CA01

- [ ] **Renewal Process Phase**:
  - [ ] CA console shows issued certificates
  - [ ] Runbook executions complete successfully
  - [ ] Email notifications sent via SMTP

- [ ] **Certificate Distribution Phase**:
  - [ ] Renewed certificates appear in Key Vault
  - [ ] Certificate tags preserved during renewal
  - [ ] Target servers receive updated certificates

- [ ] **Monitoring Phase**:
  - [ ] Dashboard runbook executes successfully
  - [ ] Workbook displays certificate status
  - [ ] All certificate states represented (green/yellow/red)

## Architecture Benefits Demonstrated

This LAB showcases:

1. **Zero-Touch Automation**: Complete certificate lifecycle without manual intervention
2. **Enterprise PKI Integration**: Works with existing Microsoft Certificate Services
3. **Cloud-Native Security**: Leverages Azure managed identities and Key Vault
4. **Scalable Architecture**: Supports multiple certificates and certificate authorities
5. **Comprehensive Monitoring**: Real-time dashboard and email notifications
6. **Production-Ready**: Demonstrates patterns suitable for enterprise deployment

## Next Steps

After completing the LAB testing:

1. **Review Production Deployment Options**:
   - Base production deployment for existing environments
   - Optional dashboard deployment for monitoring

2. **Plan Production Implementation**:
   - Identify target certificate authorities
   - Plan hybrid worker deployment strategy
   - Design certificate template and naming conventions

3. **Security Considerations**:
   - Review RBAC role assignments
   - Plan Key Vault access policies
   - Configure network security and firewall rules

4. **Operational Procedures**:
   - Define monitoring and alerting strategies
   - Plan certificate lifecycle policies
   - Establish troubleshooting procedures

The LAB provides a complete, working reference implementation that can be adapted for your production certificate lifecycle management requirements.

## Certificate Expiry Testing Options

To thoroughly test the certificate renewal automation, you have several options to trigger certificate expiry scenarios:

### Option 1: Wait for Natural Expiry (Recommended)

The default `democert` certificate is configured with a 5-day validity period for demo purposes:

1. **Check Current Certificate Status**:
   ```bash
   az keyvault certificate show --vault-name DEMO-KV-<UNIQUESTRING> --name democert \
     --query "{Name:name, Subject:policy.x509CertificateProperties.subject, ValidFrom:attributes.notBefore, ValidTo:attributes.expires, Status:attributes.enabled}" \
     --output table
   ```

2. **Monitor Renewal Timeline**:
   - **Day 4**: Certificate renewal should trigger (80% threshold)
   - **Day 5**: Certificate expires if renewal fails
   - **Monitor**: Azure Automation Account jobs for renewal activity

### Option 2: Create an Immediately Expiring Certificate

For faster testing, create a certificate that expires within 24 hours:

1. **Create Short-Lived Certificate**:
   ```bash
   # Create certificate expiring tomorrow
   openssl req -x509 -newkey rsa:2048 -keyout /tmp/expired-key.pem \
     -out /tmp/expired-cert.pem -days 1 -nodes \
     -subj "/CN=democert-expired-immediate"
   
   # Convert to PKCS12 format
   openssl pkcs12 -export -out /tmp/expired-cert.p12 \
     -inkey /tmp/expired-key.pem -in /tmp/expired-cert.pem \
     -passout pass:TempPass123
   
   # Import to Key Vault
   az keyvault certificate import \
     --vault-name DEMO-KV-<UNIQUESTRING> \
     --name democert-expired-immediate \
     --file /tmp/expired-cert.p12 \
     --password TempPass123
   
   # Clean up temporary files
   rm -f /tmp/expired-cert.p12 /tmp/expired-cert.pem /tmp/expired-key.pem
   ```

2. **Verify Certificate Details**:
   ```bash
   az keyvault certificate show --vault-name DEMO-KV-<UNIQUESTRING> \
     --name democert-expired-immediate \
     --query "{Name:name, Expires:attributes.expires, Status:attributes.enabled}" \
     --output table
   ```

### Option 3: Create Ultra-Short-Lived Certificate (Advanced)

For immediate testing, create a certificate using PowerShell on the CA01 server:

1. **Connect to CA01 Server**:
   - RDP to CA01 using domain credentials
   - Open PowerShell as Administrator

2. **Run Certificate Creation Script**:
   ```powershell
   # Create certificate that expires in 2 minutes
   $certParams = @{
       Subject = "CN=democert-shortlived"
       NotBefore = (Get-Date)
       NotAfter = (Get-Date).AddMinutes(2)
       KeyAlgorithm = "RSA"
       KeyLength = 2048
       KeyUsage = @("DigitalSignature", "KeyEncipherment")
       KeyExportPolicy = "Exportable"
       CertStoreLocation = "Cert:\CurrentUser\My"
   }
   
   $cert = New-SelfSignedCertificate @certParams
   
   # Export and import to Key Vault
   $pfxPath = "$env:TEMP\democert-shortlived.pfx"
   $password = ConvertTo-SecureString -String "TempTest123!" -Force -AsPlainText
   Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password
   
   Import-AzKeyVaultCertificate -VaultName "DEMO-KV-<UNIQUESTRING>" \
     -Name "democert-shortlived" -FilePath $pfxPath -Password $password
   
   # Cleanup
   Remove-Item $pfxPath -Force
   Get-ChildItem -Path "Cert:\CurrentUser\My" | 
     Where-Object { $_.Subject -eq "CN=democert-shortlived" } | Remove-Item
   ```

### Option 4: Manual Runbook Execution

Test the renewal process by manually triggering the automation runbook:

1. **Start Certificate Lifecycle Runbook**:
   ```bash
   az automation runbook start \
     --automation-account-name DEMO-AA-<UNIQUESTRING> \
     --resource-group <your-resource-group> \
     --name CertLifeCycleMgmt
   ```

2. **Monitor Job Status**:
   ```bash
   # List recent jobs
   az automation job list \
     --automation-account-name DEMO-AA-<UNIQUESTRING> \
     --resource-group <your-resource-group> \
     --query "[].{JobId:jobId, Status:status, StartTime:startTime, RunbookName:runbook.name}" \
     --output table
   ```

3. **Check Job Details**:
   - Navigate to Azure Portal → Automation Account → Jobs
   - Click on the latest job to view detailed output and logs

### Testing Timeline and Expectations

| Test Method | Expiry Time | Renewal Trigger | Expected Automation Response |
|-------------|-------------|-----------------|------------------------------|
| Natural Expiry | 5 days | Day 4 (80% threshold) | Automatic renewal via Event Grid |
| 24-Hour Certificate | 1 day | ~19 hours (80% threshold) | Automatic renewal detection |
| 2-Minute Certificate | 2 minutes | Immediate | Manual monitoring required |
| Manual Runbook | N/A | Immediate | Direct execution test |

### Monitoring Certificate Renewal

1. **Azure Automation Account**:
   - Jobs → Monitor runbook execution
   - Hybrid Worker Groups → Verify CA01 connectivity
   - Runbooks → Review CertLifeCycleMgmt script

2. **Event Grid System Topic**:
   - Metrics → Monitor event delivery
   - Event Subscriptions → Verify webhook configuration

3. **Log Analytics Workspace**:
   ```kql
   CertificateLifecycleEvents_CL 
   | where TimeGenerated > ago(1h)
   | project TimeGenerated, Certificate_s, Action_s, Status_s
   | order by TimeGenerated desc
   ```

4. **Azure Workbook Dashboard**:
   - Navigate to the deployed workbook
   - Monitor certificate status and renewal history
   - Review renewal success/failure metrics

### Troubleshooting Common Issues

1. **Certificate Not Visible in Key Vault**:
   - Verify you have "Key Vault Certificates Officer" role
   - Check Key Vault RBAC permissions (not access policies)

2. **Automation Runbook Failures**:
   - Verify Hybrid Worker is online on CA01
   - Check Automation Account managed identity permissions
   - Review runbook execution logs

3. **Event Grid Not Triggering**:
   - Verify Event Grid system topic is created
   - Check storage queue for pending messages
   - Validate webhook endpoint configuration

4. **Certificate Renewal Not Working**:
   - Confirm Enterprise CA is running on CA01
   - Verify certificate template permissions
   - Check Key Vault certificate policy configuration

This comprehensive testing approach allows you to validate the complete certificate lifecycle automation under various scenarios and timeframes.