# Certificate Lifecycle Management - Production Dashboard Deployment Guide

## Overview

The Production Dashboard deployment is an **optional add-on** that extends the base certificate lifecycle management solution with comprehensive monitoring and visualization capabilities. This deployment creates a complete monitoring solution for tracking certificate expiration status across your organization.

> **Important**: This deployment must be performed **after** the [Production Base deployment](./PRODUCTION_BASE_INSTRUCTIONS.md) is completed and operational.

## Architecture Components

### New Resources Deployed:
1. **Log Analytics Workspace** - Central data repository for certificate information
2. **Data Collection Endpoint (DCE)** - Secure data ingestion endpoint
3. **Data Collection Rule (DCR)** - Data processing and routing configuration
4. **Custom Table** - Structured storage for certificate expiration data
5. **Azure Workbook** - Interactive dashboard for certificate visualization
6. **PowerShell Runbook** - Automated data collection from Key Vault

### Dashboard Features:
- **Real-time Certificate Status**: Visual indicators for certificate health
- **Expiration Timeline**: Proactive monitoring of upcoming expirations
- **Certificate Inventory**: Comprehensive list of all tracked certificates
- **Status Categories**:
  - 🟢 **Not Expired**: Certificates with sufficient validity remaining
  - 🟡 **Expiring Soon**: Certificates nearing expiration (configurable threshold)
  - 🔴 **Expired**: Certificates that have already expired

## Prerequisites

### Completed Deployments:
- **Production Base deployment** must be successfully deployed and operational
- **Key Vault** containing certificates with proper tagging
- **Automation Account** with functional certificate renewal process

### Azure Requirements:
- **Same Resource Group** as the base deployment
- **Owner role** on the subscription
- **Log Analytics workspace** quota availability

### Certificate Requirements:
- Certificates in Key Vault must have **"Recipient" tags** for email notifications
- Certificates should be actively managed by the base lifecycle system

## Step-by-Step Deployment Process

### 1. Deploy Dashboard Infrastructure

**Deployment Time:** Approximately 2 minutes

1. **Access the Dashboard Deployment Template**:
   - Use the "Deploy to Azure" button for Production Dashboard deployment
   - Or direct link: `https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcertlc%2Fmain%2F.armtemplate%2Fdashboard.json`

2. **Configure Required Parameters**:
   ```
   Subscription: [Same as base deployment]
   Resource Group: [SAME resource group as base deployment]
   Region: [Same region as base deployment]
   
   Workspace Name: [Unique name, e.g., "contoso-certlc-logs"]
   Table Name: [Custom table name, e.g., "CertificateStatus_CL"]
   Data Collection Endpoint Name: [Unique name, e.g., "contoso-certlc-dce"]
   Data Collection Rule Name: [Unique name, e.g., "contoso-certlc-dcr"]
   Workbook Display Name: [Display name, e.g., "Certificate Lifecycle Dashboard"]
   
   Key Vault Name: [EXISTING Key Vault from base deployment]
   Automation Account Name: [EXISTING Automation Account from base deployment]
   ```

3. **Optional Parameters** (can use defaults):
   ```
   SKU: PerGB2018
   Retention In Days: 120
   Resource Permissions: true
   Heartbeat Table Retention: 30
   Workbook ID: [Auto-generated GUID]
   Schedule Dashboard Data Start Time: [10 minutes from deployment]
   ```

4. **Start Deployment**:
   - Verify all parameters, especially existing resource names
   - Click "Create" to begin deployment
   - Monitor deployment progress

### 2. Configure RBAC Permissions

After deployment completes, configure the required role assignments for the Automation Account's managed identity:

#### **Get Automation Account Managed Identity**:
```powershell
# Get the managed identity information
$ResourceGroupName = "your-resource-group"
$AutomationAccountName = "your-automation-account-name"

$AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
$ManagedIdentityId = $AutomationAccount.Identity.PrincipalId

Write-Output "Managed Identity ID: $ManagedIdentityId"
```

#### **Assign Required Roles**:

1. **Data Collection Rule (DCR) Permissions**:
   ```powershell
   # Assign Monitoring Metrics Publisher role on DCR
   $DCRName = "your-dcr-name"
   $DCRResourceId = "/subscriptions/your-subscription-id/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/$DCRName"
   
   New-AzRoleAssignment -ObjectId $ManagedIdentityId `
     -RoleDefinitionName "Monitoring Metrics Publisher" `
     -Scope $DCRResourceId
   ```

2. **Data Collection Endpoint (DCE) Permissions**:
   ```powershell
   # Assign Monitoring Metrics Publisher role on DCE
   $DCEName = "your-dce-name"
   $DCEResourceId = "/subscriptions/your-subscription-id/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionEndpoints/$DCEName"
   
   New-AzRoleAssignment -ObjectId $ManagedIdentityId `
     -RoleDefinitionName "Monitoring Metrics Publisher" `
     -Scope $DCEResourceId
   ```

3. **Log Analytics Workspace Permissions**:
   ```powershell
   # Assign Log Analytics Contributor role on workspace
   $WorkspaceName = "your-workspace-name"
   $WorkspaceResourceId = "/subscriptions/your-subscription-id/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"
   
   New-AzRoleAssignment -ObjectId $ManagedIdentityId `
     -RoleDefinitionName "Log Analytics Contributor" `
     -Scope $WorkspaceResourceId
   ```

4. **Key Vault Permissions**:
   ```powershell
   # Assign Key Vault Certificate Officer role (if not already assigned from base deployment)
   $KeyVaultName = "your-key-vault-name"
   $KeyVaultResourceId = "/subscriptions/your-subscription-id/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
   
   New-AzRoleAssignment -ObjectId $ManagedIdentityId `
     -RoleDefinitionName "Key Vault Certificate Officer" `
     -Scope $KeyVaultResourceId
   
   # Also assign Key Vault Crypto Officer for additional operations
   New-AzRoleAssignment -ObjectId $ManagedIdentityId `
     -RoleDefinitionName "Key Vault Crypto Officer" `
     -Scope $KeyVaultResourceId
   ```

#### **Alternative: Portal-Based Role Assignment**:

1. **Navigate to each resource** (DCR, DCE, Log Analytics, Key Vault)
2. **Go to Access Control (IAM)**
3. **Click "Add" → "Add role assignment"**
4. **Select the appropriate role**:
   - DCR/DCE: "Monitoring Metrics Publisher"
   - Log Analytics: "Log Analytics Contributor"
   - Key Vault: "Key Vault Certificate Officer" and "Key Vault Crypto Officer"
5. **Select "Managed Identity"**
6. **Choose your Automation Account**
7. **Click "Save"**

### 3. Configure Data Collection

#### **Verify Automation Variables**:

The dashboard runbook requires specific automation variables. Verify they are configured:

```powershell
# Check automation variables
$ResourceGroupName = "your-resource-group"
$AutomationAccountName = "your-automation-account-name"

# Required variables for dashboard
$RequiredVariables = @(
    "VaultName",
    "dcrImmutableId",
    "dcrEndpointUri",
    "streamName"
)

foreach ($Variable in $RequiredVariables) {
    try {
        $Value = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
          -AutomationAccountName $AutomationAccountName `
          -Name $Variable
        Write-Output "$Variable = $($Value.Value)"
    }
    catch {
        Write-Warning "Variable $Variable not found or not accessible"
    }
}
```

#### **Set Missing Variables** (if needed):
```powershell
# Set automation variables if they're missing
$VaultName = "your-key-vault-name"
$DCRResourceId = "/subscriptions/your-subscription-id/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/your-dcr-name"
$DCEEndpoint = "https://your-dce-name.eastus-1.ingest.monitor.azure.com"
$StreamName = "Custom-CertificateStatus_CL"

# Create or update variables
New-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -Name "VaultName" `
  -Value $VaultName `
  -Encrypted $false

New-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -Name "dcrImmutableId" `
  -Value $DCRResourceId `
  -Encrypted $false

New-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -Name "dcrEndpointUri" `
  -Value $DCEEndpoint `
  -Encrypted $false

New-AzAutomationVariable -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -Name "streamName" `
  -Value $StreamName `
  -Encrypted $false
```

### 4. Test Data Collection

#### **Manual Runbook Execution**:

1. **Navigate to Automation Account** in Azure portal
2. **Go to Runbooks** → **CertLCDashboardDataIngestion**
3. **Click "Start"** to manually trigger data collection
4. **Monitor job execution**:
   - Check "Jobs" tab for execution status
   - Review output logs for any errors
   - Verify successful data transmission

#### **Verify Data in Log Analytics**:

```kusto
// Query to check if data is being collected
CertificateStatus_CL
| where TimeGenerated > ago(1h)
| summarize count() by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

#### **PowerShell Verification**:
```powershell
# Query Log Analytics for recent data
$WorkspaceId = "your-workspace-id"
$Query = "CertificateStatus_CL | where TimeGenerated > ago(1h) | limit 10"

# Note: Requires appropriate permissions and authentication
Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $Query
```

### 5. Configure Dashboard Visualization

#### **Access the Workbook**:

1. **Navigate to Azure Monitor** in Azure portal
2. **Select "Workbooks"** from the left menu
3. **Find your workbook** (by the display name you specified)
4. **Click to open** the certificate dashboard

#### **Customize Dashboard** (optional):

1. **Edit Mode**: Click "Edit" to modify the workbook
2. **Add Parameters**: Create filters for specific certificates or time ranges
3. **Modify Queries**: Adjust KQL queries for your specific requirements
4. **Add Visualizations**: Include additional charts or tables

#### **Example Custom Queries**:

```kusto
// Certificates expiring in next 30 days
CertificateStatus_CL
| where CertExpiration_s < now() + 30d
| where CertExpiration_s > now()
| project CertName_s, CertExpiration_s, CertRecipient_s
| order by CertExpiration_s asc

// Certificate count by status
CertificateStatus_CL
| extend Status = case(
    CertExpiration_s < now(), "Expired",
    CertExpiration_s < now() + 30d, "Expiring Soon",
    "Valid"
)
| summarize Count = count() by Status

// Certificates by issuer
CertificateStatus_CL
| summarize Count = count() by CertIssuer_s
| order by Count desc
```

### 6. Configure Automated Data Collection

#### **Schedule Configuration**:

The dashboard runbook is automatically scheduled during deployment. Verify the schedule:

```powershell
# Check scheduled jobs
$ResourceGroupName = "your-resource-group"
$AutomationAccountName = "your-automation-account-name"
$RunbookName = "CertLCDashboardDataIngestion"

Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  | Where-Object { $_.LinkedResourceName -eq $RunbookName }
```

#### **Modify Schedule** (if needed):
```powershell
# Create a new schedule (example: every 4 hours)
$ScheduleName = "CertDashboardSchedule"
$StartTime = (Get-Date).AddMinutes(10)

New-AzAutomationSchedule -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -Name $ScheduleName `
  -Description "Certificate dashboard data collection" `
  -StartTime $StartTime `
  -HourInterval 4

# Link schedule to runbook
Register-AzAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -RunbookName $RunbookName `
  -ScheduleName $ScheduleName
```

## Testing and Validation

### 1. Verify Data Collection Process

#### **Check Runbook Execution**:
```powershell
# Get recent job executions
$Jobs = Get-AzAutomationJob -ResourceGroupName $ResourceGroupName `
  -AutomationAccountName $AutomationAccountName `
  -RunbookName "CertLCDashboardDataIngestion" `
  | Sort-Object StartTime -Descending `
  | Select-Object -First 5

foreach ($Job in $Jobs) {
    Write-Output "Job: $($Job.JobId) - Status: $($Job.Status) - Start: $($Job.StartTime)"
    
    # Get job output for failed jobs
    if ($Job.Status -eq "Failed") {
        $Output = Get-AzAutomationJobOutput -ResourceGroupName $ResourceGroupName `
          -AutomationAccountName $AutomationAccountName `
          -JobId $Job.JobId
        Write-Output "Error Output: $($Output.Summary)"
    }
}
```

#### **Verify Log Analytics Data**:
```kusto
// Check data freshness
CertificateStatus_CL
| summarize 
    LatestData = max(TimeGenerated),
    RecordCount = count(),
    UniqueKeyVaults = dcount(KeyVault_s),
    UniqueCertificates = dcount(CertName_s)

// Check for data collection gaps
CertificateStatus_CL
| where TimeGenerated > ago(7d)
| summarize count() by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
| limit 50
```

### 2. Test Dashboard Functionality

#### **Dashboard Validation Checklist**:
- [ ] Workbook loads without errors
- [ ] Pie chart shows certificate status distribution
- [ ] Data table displays certificate details
- [ ] Time range filters work correctly
- [ ] Export functionality operates properly
- [ ] Refresh updates data appropriately

#### **Data Accuracy Verification**:
1. **Compare with Key Vault**: Manually verify certificate count matches Key Vault
2. **Check Expiration Dates**: Verify dashboard dates match Key Vault certificate properties
3. **Validate Recipients**: Confirm recipient information displays correctly
4. **Test Status Logic**: Verify expired/expiring/valid classifications are accurate

### 3. Test Alert Configuration (Optional)

#### **Create Certificate Expiration Alerts**:
```powershell
# Example: Alert for certificates expiring in 7 days
$AlertRuleName = "CertificateExpiringAlert"
$ResourceGroupName = "your-resource-group"
$WorkspaceName = "your-workspace-name"

$Query = @"
CertificateStatus_CL
| where CertExpiration_s between (now() .. now() + 7d)
| summarize count()
"@

# Note: Use Azure portal or ARM templates for complete alert configuration
```

## Monitoring and Maintenance

### Regular Monitoring Tasks

#### **Daily Checks**:
- Verify dashboard data is current (within last collection interval)
- Review certificate expiration status
- Check for any failed runbook executions

#### **Weekly Reviews**:
- Analyze certificate expiration trends
- Review and update recipient information
- Validate data collection accuracy

#### **Monthly Maintenance**:
- Review Log Analytics data retention and costs
- Update dashboard visualizations as needed
- Assess additional monitoring requirements

### Troubleshooting Common Issues

#### **No Data in Dashboard**:
1. **Check runbook execution status and errors**
2. **Verify RBAC permissions on all resources**
3. **Validate automation variables configuration**
4. **Test connectivity from Automation Account to Key Vault**

#### **Incomplete Data**:
1. **Check Key Vault certificate tags**
2. **Verify certificate visibility permissions**
3. **Review runbook logs for partial failures**
4. **Validate Log Analytics ingestion limits**

#### **Dashboard Visualization Issues**:
1. **Verify workbook queries and parameters**
2. **Check Log Analytics table schema**
3. **Review time range and filter settings**
4. **Test with sample data queries**

### Performance Optimization

#### **Data Collection Optimization**:
- Adjust collection frequency based on certificate lifecycle patterns
- Implement incremental data collection for large certificate volumes
- Configure appropriate Log Analytics retention policies

#### **Cost Management**:
- Monitor Log Analytics ingestion costs
- Optimize query efficiency
- Consider data aggregation for historical reporting

## Security Considerations

### Access Control
- Limit workbook access to authorized personnel
- Use Azure RBAC for granular Log Analytics permissions
- Regular review of dashboard access patterns

### Data Protection
- Ensure certificate sensitive data is appropriately handled
- Configure Log Analytics workspace security settings
- Implement data retention policies per compliance requirements

### Audit and Compliance
- Monitor dashboard access and usage
- Maintain audit logs for certificate status changes
- Document dashboard configuration for compliance reviews

## Integration with Existing Systems

### SIEM Integration
Export certificate status data to Security Information and Event Management (SIEM) systems:

```kusto
// Export data for SIEM consumption
CertificateStatus_CL
| where TimeGenerated > ago(1d)
| project 
    Timestamp = TimeGenerated,
    KeyVault = KeyVault_s,
    Certificate = CertName_s,
    Expiration = CertExpiration_s,
    Status = case(
        CertExpiration_s < now(), "EXPIRED",
        CertExpiration_s < now() + 30d, "EXPIRING",
        "VALID"
    ),
    Recipients = CertRecipient_s
```

### Notification Systems
Integrate with existing notification platforms:
- Microsoft Teams webhooks
- Slack notifications
- Custom API endpoints
- Service Now integration

### Reporting Systems
Create automated reports for stakeholders:
- Weekly certificate status summaries
- Monthly expiration forecasts
- Quarterly compliance reports
- Annual certificate lifecycle analytics

## Next Steps

After successful dashboard deployment:

1. **Customize Visualizations**: Adapt dashboard to your organization's specific needs
2. **Implement Alerting**: Set up proactive notifications for certificate events
3. **Integrate with ITSM**: Connect to existing IT service management processes
4. **Expand Monitoring**: Include additional certificate sources and metrics
5. **Develop Automation**: Create additional runbooks for certificate management tasks

The production dashboard provides comprehensive visibility into your certificate lifecycle management system, enabling proactive monitoring and informed decision-making for certificate operations.