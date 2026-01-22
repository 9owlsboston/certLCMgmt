#!/bin/bash

# Real-time Test Monitor for Certificate Lifecycle Fix
# This script monitors for new automation jobs and certificate changes

RESOURCE_GROUP="rg-demo-certlc"
AUTOMATION_ACCOUNT="DEMO-AA-1030164500"
KEY_VAULT="DEMO-KV-1030164500"
CERTIFICATE_NAME="democert"
TEST_SCHEDULE="TestRun-1762045101"

echo "🔍 REAL-TIME TEST MONITOR"
echo "========================="
echo "⏰ Started at: $(date)"
echo "🎯 Watching for: New automation jobs and certificate changes"
echo "📊 Baseline certificate versions: 92"
echo ""

# Get initial job count
INITIAL_JOB_COUNT=$(az automation job list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
echo "📋 Initial job count: $INITIAL_JOB_COUNT"

echo ""
echo "🕐 Monitoring every 30 seconds... (Press Ctrl+C to stop)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while true; do
    echo ""
    echo "⏰ Check at: $(date)"
    
    # Check for new jobs
    CURRENT_JOB_COUNT=$(az automation job list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    
    if [ "$CURRENT_JOB_COUNT" -gt "$INITIAL_JOB_COUNT" ]; then
        echo "🚀 NEW JOB DETECTED! Job count increased from $INITIAL_JOB_COUNT to $CURRENT_JOB_COUNT"
        
        # Get the latest job details
        echo "📋 Latest job details:"
        az automation job list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "[0].{jobId:jobId, status:status, runbook:runbook.name, startTime:startTime, endTime:endTime}" -o table 2>/dev/null
        
        # Update our baseline
        INITIAL_JOB_COUNT=$CURRENT_JOB_COUNT
    else
        echo "📊 Job count: $CURRENT_JOB_COUNT (no change)"
    fi
    
    # Check latest job status
    LATEST_JOB_STATUS=$(az automation job list --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "[0].status" -o tsv 2>/dev/null || echo "none")
    echo "🔄 Latest job status: $LATEST_JOB_STATUS"
    
    # Check certificate version count
    CURRENT_CERT_VERSIONS=$(az keyvault certificate list-versions --vault-name "$KEY_VAULT" --name "$CERTIFICATE_NAME" --query "length(@)" -o tsv 2>/dev/null || echo "unknown")
    if [ "$CURRENT_CERT_VERSIONS" != "unknown" ] && [ "$CURRENT_CERT_VERSIONS" != "92" ]; then
        echo "🎯 CERTIFICATE CHANGE! Versions changed from 92 to $CURRENT_CERT_VERSIONS"
    else
        echo "📋 Certificate versions: $CURRENT_CERT_VERSIONS (no change from baseline)"
    fi
    
    # Check if our test schedule ran
    if az automation schedule show --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --name "$TEST_SCHEDULE" >/dev/null 2>&1; then
        SCHEDULE_STATUS=$(az automation schedule show --automation-account-name "$AUTOMATION_ACCOUNT" --resource-group "$RESOURCE_GROUP" --name "$TEST_SCHEDULE" --query "isEnabled" -o tsv 2>/dev/null)
        echo "📅 Test schedule '$TEST_SCHEDULE' status: $SCHEDULE_STATUS"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sleep 30
done