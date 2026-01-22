#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - Automation Setup
# =============================================================================

set -e  # Exit on any error

# Source environment variables
if [ -f "./01-environment-setup.sh" ]; then
    source ./01-environment-setup.sh
else
    echo "ERROR: Please run 01-environment-setup.sh first to set environment variables"
    exit 1
fi

echo "Setting up automation components for certificate lifecycle management..."

# =============================================================================
# CREATE AUTOMATION VARIABLES
# =============================================================================

echo "Creating Automation Account variables..."

# Helper function to create or update automation variables
create_or_update_variable() {
    local var_name="$1"
    local var_value="$2"
    local var_description="$3"
    local is_encrypted="${4:-false}"
    
    if az automation variable show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "$var_name" --output none 2>/dev/null; then
        echo "✓ Variable '$var_name' already exists, updating value..."
        az automation variable update \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$var_name" \
            --value "$var_value"
    else
        echo "Creating variable '$var_name'..."
        if [ "$is_encrypted" = "true" ]; then
            az automation variable create \
                --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --name "$var_name" \
                --value "$var_value" \
                --description "$var_description" \
                --is-encrypted true
        else
            az automation variable create \
                --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --name "$var_name" \
                --value "$var_value" \
                --description "$var_description"
        fi
    fi
}

# SMTP Server variable
create_or_update_variable "SMTPServer" "\"$SMTP_SERVER\"" "The name of the SMTP Server to send email notifications"

# Storage Account variable
create_or_update_variable "StorageAccount" "\"$STORAGE_ACCOUNT_NAME\"" "The name of the Storage Account containing the message queue"

# Email Recipient variable
create_or_update_variable "EmailRecipient" "\"$EMAIL_RECIPIENT\"" "Email address for certificate notifications"

# Certificate Expiry Days variable
create_or_update_variable "CertExpiryDays" "\"$CERT_EXPIRY_DAYS\"" "Number of days before expiry to trigger renewal"

# Get Data Collection Endpoint URL
DCE_ENDPOINT=$(az monitor data-collection endpoint show \
    --name "$DATA_COLLECTION_ENDPOINT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "logsIngestion.endpoint" -o tsv)

# Data Collection Endpoint variable
create_or_update_variable "DataCollectionEndpoint" "\"$DCE_ENDPOINT\"" "Data Collection Endpoint for Log Analytics"

# Get Data Collection Rule Immutable ID
DCR_IMMUTABLE_ID=$(az monitor data-collection rule show \
    --name "$DATA_COLLECTION_RULE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "immutableId" -o tsv)

# Data Collection Rule variable
create_or_update_variable "DataCollectionRuleId" "\"$DCR_IMMUTABLE_ID\"" "Data Collection Rule Immutable ID"

# Table Name variable
create_or_update_variable "TableName" "\"$TABLE_NAME\"" "Custom table name for certificate data"

echo "✓ Automation variables created/updated successfully"

# =============================================================================
# CREATE RUNBOOKS
# =============================================================================

echo "Creating PowerShell runbooks..."

# Create certificate lifecycle management runbook
echo "Checking Certificate Lifecycle Management runbook..."

if az automation runbook show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "CertLifeCycleMgmt" --output none 2>/dev/null; then
    echo "✓ Runbook 'CertLifeCycleMgmt' already exists"
    
    # Check if runbook is published
    RUNBOOK_STATE=$(az automation runbook show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "CertLifeCycleMgmt" --query "state" -o tsv)
    if [ "$RUNBOOK_STATE" != "Published" ]; then
        echo "Publishing existing runbook..."
        az automation runbook publish \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "CertLifeCycleMgmt"
        echo "✓ Runbook published"
    fi
else
    echo "Creating Certificate Lifecycle Management runbook..."
    
    # Download the runbook content from the official repository
    if curl -s "https://raw.githubusercontent.com/Azure/certlc/main/.runbook/runbook_v3.ps1" > /tmp/certlc-runbook.ps1; then
        az automation runbook create \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "CertLifeCycleMgmt" \
            --type "PowerShell" \
            --description "Certificate Lifecycle Management automation runbook" \
            --runbook-content @/tmp/certlc-runbook.ps1

        # Publish the runbook
        az automation runbook publish \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "CertLifeCycleMgmt"
        
        rm -f /tmp/certlc-runbook.ps1
        echo "✓ Certificate Lifecycle Management runbook created and published"
    else
        echo "⚠ WARNING: Could not download runbook from GitHub, skipping..."
    fi
fi

# Create dashboard data injection runbook
echo "Checking Dashboard Data Injection runbook..."

if az automation runbook show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "CertLCDashboardDataInjestion" --output none 2>/dev/null; then
    echo "✓ Runbook 'CertLCDashboardDataInjestion' already exists"
    
    # Check if runbook is published
    DASHBOARD_RUNBOOK_STATE=$(az automation runbook show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "CertLCDashboardDataInjestion" --query "state" -o tsv)
    if [ "$DASHBOARD_RUNBOOK_STATE" != "Published" ]; then
        echo "Publishing existing runbook..."
        az automation runbook publish \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "CertLCDashboardDataInjestion"
        echo "✓ Runbook published"
    fi
else
    echo "Creating Dashboard Data Injection runbook..."

    cat > /tmp/dashboard-runbook.ps1 << 'EOF'
<#
.SYNOPSIS
    Certificate Lifecycle Dashboard Data Injection Runbook
.DESCRIPTION
    Collects certificate data from Key Vault and sends to Log Analytics
#>

# Get automation variables
$StorageAccount = Get-AutomationVariable -Name "StorageAccount"
$DataCollectionEndpoint = Get-AutomationVariable -Name "DataCollectionEndpoint"
$DataCollectionRuleId = Get-AutomationVariable -Name "DataCollectionRuleId"
$TableName = Get-AutomationVariable -Name "TableName"

try {
    # Connect using managed identity
    Connect-AzAccount -Identity
    
    # Get all Key Vaults in subscription
    $KeyVaults = Get-AzKeyVault
    
    $CertificateData = @()
    
    foreach ($KeyVault in $KeyVaults) {
        try {
            $Certificates = Get-AzKeyVaultCertificate -VaultName $KeyVault.VaultName
            
            foreach ($Certificate in $Certificates) {
                $CertDetails = Get-AzKeyVaultCertificate -VaultName $KeyVault.VaultName -Name $Certificate.Name
                
                $CertData = [PSCustomObject]@{
                    TimeGenerated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                    CertName = $Certificate.Name
                    CertSubject = $CertDetails.Certificate.Subject
                    CertExpiration = $CertDetails.Certificate.NotAfter.ToString("yyyy-MM-ddTHH:mm:ssZ")
                    CertThumbprint = $CertDetails.Certificate.Thumbprint
                    CertRecipient = "System"
                    KeyVault = $KeyVault.VaultName
                    RawData = ($CertDetails | ConvertTo-Json -Compress)
                }
                
                $CertificateData += $CertData
            }
        }
        catch {
            Write-Warning "Failed to process Key Vault $($KeyVault.VaultName): $($_.Exception.Message)"
        }
    }
    
    if ($CertificateData.Count -gt 0) {
        # Send data to Log Analytics
        $Headers = @{
            'Authorization' = "Bearer $((Get-AzAccessToken).Token)"
            'Content-Type' = 'application/json'
        }
        
        $Body = @{
            'data' = $CertificateData
        } | ConvertTo-Json -Depth 10
        
        $Uri = "$DataCollectionEndpoint/dataCollectionRules/$DataCollectionRuleId/streams/Custom-${TableName}RawData?api-version=2023-01-01"
        
        Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body
        
        Write-Output "Successfully sent $($CertificateData.Count) certificate records to Log Analytics"
    }
    else {
        Write-Output "No certificates found to process"
    }
}
catch {
    Write-Error "Error in dashboard data injection: $($_.Exception.Message)"
    throw
}
EOF

    az automation runbook create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "CertLCDashboardDataInjestion" \
        --type "PowerShell" \
        --description "Dashboard data injection for certificate monitoring" \
        --runbook-content @/tmp/dashboard-runbook.ps1

    # Publish the dashboard runbook
    az automation runbook publish \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "CertLCDashboardDataInjestion"

    rm -f /tmp/dashboard-runbook.ps1
    echo "✓ Dashboard Data Injection runbook created and published"
fi

# =============================================================================
# CREATE WEBHOOKS
# =============================================================================

echo "Creating webhook for Event Grid integration..."

# Check if webhook already exists
if az automation webhook show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "$WEBHOOK_NAME" --output none 2>/dev/null; then
    echo "✓ Webhook '$WEBHOOK_NAME' already exists"
    
    # Get existing webhook URI
    WEBHOOK_URI=$(az automation webhook show \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$WEBHOOK_NAME" \
        --query "uri" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$WEBHOOK_URI" ]; then
        echo "⚠ WARNING: Cannot retrieve webhook URI for existing webhook"
        echo "If Event Grid subscription fails, you may need to recreate the webhook"
    else
        echo "✓ Retrieved existing webhook URI"
    fi
else
    echo "Creating new webhook..."
    
    # Calculate webhook expiry time (1 year from now)
    WEBHOOK_EXPIRY=$(date -u -d "+1 year" '+%Y-%m-%dT%H:%M:%SZ')

    # Create webhook for the CertLifeCycleMgmt runbook
    WEBHOOK_URI=$(az automation webhook create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$WEBHOOK_NAME" \
        --runbook-name "CertLifeCycleMgmt" \
        --expiry-time "$WEBHOOK_EXPIRY" \
        --is-enabled true \
        --query "uri" -o tsv)

    echo "✓ Webhook created successfully"
fi

# Store webhook URI as an automation variable for reference (if we have it)
if [ -n "$WEBHOOK_URI" ]; then
    create_or_update_variable "WebhookURI" "\"$WEBHOOK_URI\"" "Webhook URI for Event Grid integration" "true"
    echo "✓ Webhook URI stored as encrypted variable"
else
    echo "⚠ WARNING: Webhook URI not available to store as variable"
fi

# =============================================================================
# CREATE EVENT GRID WEBHOOK SUBSCRIPTION
# =============================================================================

echo "Creating Event Grid webhook subscription..."

# Only create webhook subscription if webhook URI is available
if [ -n "$WEBHOOK_URI" ]; then
    # Check if webhook subscription already exists
    if az eventgrid system-topic event-subscription show \
        --name "CertLC-webhook" \
        --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --output none 2>/dev/null; then
        echo "✓ Event Grid webhook subscription 'CertLC-webhook' already exists"
    else
        echo "Creating new Event Grid webhook subscription..."
        az eventgrid system-topic event-subscription create \
            --name "CertLC-webhook" \
            --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --endpoint-type "webhook" \
            --endpoint "$WEBHOOK_URI" \
            --max-events-per-batch 1 \
            --preferred-batch-size-in-kilobytes 64 \
            --included-event-types "Microsoft.KeyVault.CertificateNearExpiry" \
            --event-delivery-schema "EventGridSchema" \
            --max-delivery-attempts 30 \
            --event-ttl 1440

        echo "✓ Event Grid webhook subscription created successfully"
    fi
else
    echo "⚠ WARNING: Webhook URI not available, skipping webhook subscription creation"
fi

# =============================================================================
# CREATE AUTOMATION SCHEDULES
# =============================================================================

echo "Creating automation schedules..."

# Helper function to create schedule if it doesn't exist
create_schedule_if_not_exists() {
    local schedule_name="$1"
    local description="$2"
    local frequency="$3"
    local interval="$4"
    local runbook_name="$5"
    
    if az automation schedule show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "$schedule_name" --output none 2>/dev/null; then
        echo "✓ Schedule '$schedule_name' already exists"
        
        # Check if job schedule link exists
        if ! az automation job-schedule show --automation-account-name "$AUTOMATION_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --runbook-name "$runbook_name" --schedule-name "$schedule_name" --output none 2>/dev/null; then
            echo "Linking schedule '$schedule_name' to runbook '$runbook_name'..."
            az automation job-schedule create \
                --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --runbook-name "$runbook_name" \
                --schedule-name "$schedule_name"
            echo "✓ Schedule linked to runbook"
        else
            echo "✓ Schedule already linked to runbook"
        fi
    else
        echo "Creating schedule '$schedule_name'..."
        
        # Calculate start time (5 minutes from now)
        START_TIME=$(date -u -d "+5 minutes" '+%Y-%m-%dT%H:%M:%SZ')
        
        # Create the schedule
        az automation schedule create \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$schedule_name" \
            --description "$description" \
            --frequency "$frequency" \
            --interval "$interval" \
            --start-time "$START_TIME"
        
        # Link schedule to runbook
        az automation job-schedule create \
            --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --runbook-name "$runbook_name" \
            --schedule-name "$schedule_name"
        
        echo "✓ Schedule '$schedule_name' created and linked to runbook '$runbook_name'"
    fi
}

# Create schedule for certificate monitoring (runs every 4 hours)
create_schedule_if_not_exists \
    "CertLCMonitoringSchedule" \
    "Certificate monitoring schedule - runs every 4 hours" \
    "Hour" \
    "4" \
    "CertLifeCycleMgmt"

# Create schedule for dashboard data injection (runs every hour)
create_schedule_if_not_exists \
    "CertLCDashboardSchedule" \
    "Dashboard data injection schedule - runs every hour" \
    "Hour" \
    "1" \
    "CertLCDashboardDataInjestion"

echo "✓ All automation schedules created successfully"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "AUTOMATION SETUP COMPLETED SUCCESSFULLY"
echo "==============================================================================="
echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
echo ""
echo "Variables Created:"
echo "  - SMTPServer: $SMTP_SERVER"
echo "  - StorageAccount: $STORAGE_ACCOUNT_NAME"
echo "  - EmailRecipient: $EMAIL_RECIPIENT"
echo "  - CertExpiryDays: $CERT_EXPIRY_DAYS"
echo "  - DataCollectionEndpoint: $DCE_ENDPOINT"
echo "  - DataCollectionRuleId: $DCR_IMMUTABLE_ID"
echo "  - TableName: $TABLE_NAME"
echo ""
echo "Runbooks Created:"
echo "  - CertLifeCycleMgmt: Main certificate lifecycle management"
echo "  - CertLCDashboardDataInjestion: Dashboard data collection"
echo ""
echo "Webhook:"
echo "  - Name: $WEBHOOK_NAME"
echo "  - Expiry: $WEBHOOK_EXPIRY"
echo "  - URI: [STORED SECURELY]"
echo ""
echo "Schedules:"
echo "  - CertLCMonitoringSchedule: Every 4 hours"
echo "  - CertLCDashboardSchedule: Every hour"
echo ""
echo "Event Subscriptions:"
echo "  - CertLC-webhook: Real-time webhook notifications"
echo "  - CertLC-queue: Reliable queue-based processing"
echo ""
echo "Next step:"
echo "1. Run 05-rbac-permissions.sh to set up required permissions"
echo "==============================================================================="