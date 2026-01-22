#!/bin/bash

# =============================================================================
# Azure Certificate Management Services - Event Grid Setup
# =============================================================================

set -e  # Exit on any error

# Source environment variables
if [ -f "./01-environment-setup.sh" ]; then
    source ./01-environment-setup.sh
else
    echo "ERROR: Please run 01-environment-setup.sh first to set environment variables"
    exit 1
fi

echo "Setting up Event Grid for certificate expiry notifications..."

# =============================================================================
# GET RESOURCE IDS
# =============================================================================

echo "Retrieving resource IDs..."

# Get Key Vault resource ID
KEY_VAULT_ID=$(az keyvault show \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

if [ -z "$KEY_VAULT_ID" ]; then
    echo "ERROR: Could not find Key Vault $KEY_VAULT_NAME"
    exit 1
fi

# Get Storage Account resource ID
STORAGE_ACCOUNT_ID=$(az storage account show \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

if [ -z "$STORAGE_ACCOUNT_ID" ]; then
    echo "ERROR: Could not find Storage Account $STORAGE_ACCOUNT_NAME"
    exit 1
fi

echo "Key Vault ID: $KEY_VAULT_ID"
echo "Storage Account ID: $STORAGE_ACCOUNT_ID"

# =============================================================================
# CREATE EVENT GRID SYSTEM TOPIC
# =============================================================================

echo "Creating Event Grid System Topic: $EVENT_GRID_TOPIC_NAME"

if az eventgrid system-topic show --name "$EVENT_GRID_TOPIC_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Event Grid System Topic '$EVENT_GRID_TOPIC_NAME' already exists"
else
    echo "Creating new Event Grid System Topic..."
    az eventgrid system-topic create \
        --name "$EVENT_GRID_TOPIC_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --source "$KEY_VAULT_ID" \
        --topic-type "microsoft.keyvault.vaults" \
        --tags \
            Purpose="CertificateEvents" \
            Component="EventGrid"
    echo "✓ Event Grid System Topic created: $EVENT_GRID_TOPIC_NAME"
fi

# =============================================================================
# CREATE STORAGE QUEUE EVENT SUBSCRIPTION
# =============================================================================

echo "Creating Event Grid subscription for Storage Queue..."

# Calculate expiry time (1 year from now)
SUBSCRIPTION_EXPIRY=$(date -u -d "+1 year" '+%Y-%m-%dT%H:%M:%SZ')

if az eventgrid system-topic event-subscription show --name "CertLC-queue" --system-topic-name "$EVENT_GRID_TOPIC_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Event Grid subscription 'CertLC-queue' already exists"
    
    # Update the subscription if needed
    echo "Updating Event Grid subscription configuration..."
    az eventgrid system-topic event-subscription update \
        --name "CertLC-queue" \
        --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --included-event-types "Microsoft.KeyVault.CertificateNearExpiry" \
        --max-delivery-attempts 30 \
        --event-ttl 1440 \
        --expiration-date "$SUBSCRIPTION_EXPIRY"
    echo "✓ Event Grid subscription updated"
else
    echo "Creating new Event Grid subscription..."
    az eventgrid system-topic event-subscription create \
        --name "CertLC-queue" \
        --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --endpoint-type "storagequeue" \
        --endpoint "$STORAGE_ACCOUNT_ID" \
        --storage-queue-name "$QUEUE_NAME" \
        --storage-queue-msg-ttl 5184000 \
        --included-event-types "Microsoft.KeyVault.CertificateNearExpiry" \
        --event-delivery-schema "EventGridSchema" \
        --max-delivery-attempts 30 \
        --event-ttl 1440 \
        --expiration-date "$SUBSCRIPTION_EXPIRY"
    echo "✓ Storage Queue event subscription created"
fi

# =============================================================================
# CREATE DATA COLLECTION COMPONENTS
# =============================================================================

echo "Creating Data Collection Endpoint: $DATA_COLLECTION_ENDPOINT_NAME"

if az monitor data-collection endpoint show --name "$DATA_COLLECTION_ENDPOINT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Data Collection Endpoint '$DATA_COLLECTION_ENDPOINT_NAME' already exists"
else
    echo "Creating new Data Collection Endpoint..."
    az monitor data-collection endpoint create \
        --name "$DATA_COLLECTION_ENDPOINT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --public-network-access Enabled \
        --tags \
            Purpose="CertificateDataCollection" \
            Component="DataCollection"
    echo "✓ Data Collection Endpoint created"
fi

# Get workspace resource ID for data collection rule
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

# Get data collection endpoint resource ID
DCE_ID=$(az monitor data-collection endpoint show \
    --name "$DATA_COLLECTION_ENDPOINT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

echo "Creating custom table in Log Analytics..."

# Create custom table for certificate data
if az monitor log-analytics workspace table show --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --name "${TABLE_NAME}_CL" --output none 2>/dev/null; then
    echo "✓ Custom table '${TABLE_NAME}_CL' already exists"
else
    echo "Creating new custom table..."
    az monitor log-analytics workspace table create \
        --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "${TABLE_NAME}_CL" \
        --columns '[
            {"name": "TimeGenerated", "type": "datetime"},
            {"name": "CertName", "type": "string"},
            {"name": "CertSubject", "type": "string"},
            {"name": "CertExpiration", "type": "string"},
            {"name": "CertThumbprint", "type": "string"},
            {"name": "CertRecipient", "type": "string"},
            {"name": "KeyVault", "type": "string"},
            {"name": "RawData", "type": "string"}
        ]' \
        --retention-in-days 120
    echo "✓ Custom table created: ${TABLE_NAME}_CL"
fi

echo "Creating Data Collection Rule: $DATA_COLLECTION_RULE_NAME"

if az monitor data-collection rule show --name "$DATA_COLLECTION_RULE_NAME" --resource-group "$RESOURCE_GROUP_NAME" --output none 2>/dev/null; then
    echo "✓ Data Collection Rule '$DATA_COLLECTION_RULE_NAME' already exists"
else
    echo "Creating new Data Collection Rule..."
    
    # Create a temporary JSON file for the data collection rule
    cat > /tmp/dcr-config.json << EOF
{
    "location": "$LOCATION",
    "properties": {
        "dataCollectionEndpointId": "$DCE_ID",
        "streamDeclarations": {
            "Custom-${TABLE_NAME}RawData": {
                "columns": [
                    {"name": "TimeGenerated", "type": "datetime"},
                    {"name": "RawData", "type": "string"}
                ]
            }
        },
        "dataSources": {},
        "destinations": {
            "logAnalytics": [
                {
                    "workspaceResourceId": "$WORKSPACE_ID",
                    "name": "clv2ws1"
                }
            ]
        },
        "dataFlows": [
            {
                "streams": ["Custom-${TABLE_NAME}RawData"],
                "destinations": ["clv2ws1"],
                "transformKql": "source | extend TimeGenerated = now()",
                "outputStream": "Custom-${TABLE_NAME}_CL"
            }
        ]
    },
    "tags": {
        "Purpose": "CertificateDataCollection",
        "Component": "DataCollectionRule"
    }
}
EOF

    az monitor data-collection rule create \
        --name "$DATA_COLLECTION_RULE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --rule-file /tmp/dcr-config.json

    # Clean up temporary file
    rm /tmp/dcr-config.json
    echo "✓ Data Collection Rule created"
fi

# =============================================================================
# VERIFY EVENT GRID SETUP
# =============================================================================

echo "Verifying Event Grid setup..."

# List system topics
echo "Event Grid System Topics:"
az eventgrid system-topic list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[].{Name:name,Source:source,TopicType:topicType}" \
    --output table

# List event subscriptions
echo ""
echo "Event Subscriptions:"
az eventgrid system-topic event-subscription list \
    --system-topic-name "$EVENT_GRID_TOPIC_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[].{Name:name,EndpointType:destination.endpointType,EventTypes:filter.includedEventTypes}" \
    --output table

# =============================================================================
# CREATE DATA COLLECTION COMPONENTS
# =============================================================================

echo "Creating Data Collection Endpoint: $DATA_COLLECTION_ENDPOINT_NAME"

az monitor data-collection endpoint create \
    --name "$DATA_COLLECTION_ENDPOINT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --public-network-access Enabled \
    --tags \
        Purpose="CertificateDataCollection" \
        Component="DataCollection"

echo "Data Collection Endpoint created successfully"

# Get workspace resource ID for data collection rule
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

# Get data collection endpoint resource ID
DCE_ID=$(az monitor data-collection endpoint show \
    --name "$DATA_COLLECTION_ENDPOINT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "id" -o tsv)

echo "Creating custom table in Log Analytics..."

# Create custom table for certificate data
az monitor log-analytics workspace table create \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "${TABLE_NAME}_CL" \
    --columns '[
        {"name": "TimeGenerated", "type": "datetime"},
        {"name": "CertName", "type": "string"},
        {"name": "CertSubject", "type": "string"},
        {"name": "CertExpiration", "type": "string"},
        {"name": "CertThumbprint", "type": "string"},
        {"name": "CertRecipient", "type": "string"},
        {"name": "KeyVault", "type": "string"},
        {"name": "RawData", "type": "string"}
    ]' \
    --retention-in-days 120 || echo "Table may already exist, continuing..."

echo "Creating Data Collection Rule: $DATA_COLLECTION_RULE_NAME"

# Create a temporary JSON file for the data collection rule
cat > /tmp/dcr-config.json << EOF
{
    "location": "$LOCATION",
    "properties": {
        "dataCollectionEndpointId": "$DCE_ID",
        "streamDeclarations": {
            "Custom-${TABLE_NAME}RawData": {
                "columns": [
                    {"name": "TimeGenerated", "type": "datetime"},
                    {"name": "RawData", "type": "string"}
                ]
            }
        },
        "dataSources": {},
        "destinations": {
            "logAnalytics": [
                {
                    "workspaceResourceId": "$WORKSPACE_ID",
                    "name": "clv2ws1"
                }
            ]
        },
        "dataFlows": [
            {
                "streams": ["Custom-${TABLE_NAME}RawData"],
                "destinations": ["clv2ws1"],
                "transformKql": "source | extend TimeGenerated = now()",
                "outputStream": "Custom-${TABLE_NAME}_CL"
            }
        ]
    },
    "tags": {
        "Purpose": "CertificateDataCollection",
        "Component": "DataCollectionRule"
    }
}
EOF

az monitor data-collection rule create \
    --name "$DATA_COLLECTION_RULE_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --rule-file /tmp/dcr-config.json

# Clean up temporary file
rm /tmp/dcr-config.json

echo "Data Collection Rule created successfully"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "EVENT GRID SETUP COMPLETED SUCCESSFULLY"
echo "==============================================================================="
echo "Event Grid System Topic: $EVENT_GRID_TOPIC_NAME"
echo "  - Source: Key Vault ($KEY_VAULT_NAME)"
echo "  - Topic Type: microsoft.keyvault.vaults"
echo ""
echo "Event Subscriptions:"
echo "  - CertLC-queue: Routes to Storage Queue ($QUEUE_NAME)"
echo "  - Event Type: Microsoft.KeyVault.CertificateNearExpiry"
echo ""
echo "Data Collection:"
echo "  - Endpoint: $DATA_COLLECTION_ENDPOINT_NAME"
echo "  - Rule: $DATA_COLLECTION_RULE_NAME" 
echo "  - Table: ${TABLE_NAME}_CL"
echo ""
echo "Next steps:"
echo "1. Run 04-automation-setup.sh to configure automation components"
echo "2. Run 05-rbac-permissions.sh to set up permissions"
echo "==============================================================================="