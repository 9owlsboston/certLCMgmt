#!/bin/bash

# Certificate Lifecycle Configuration Script
# Sets up Automation Variables for configurable certificate management

echo "🔧 Certificate Lifecycle Configuration Setup"
echo "============================================"

# Configuration variables
RESOURCE_GROUP="rg-demo-certlc"
AUTOMATION_ACCOUNT="DEMO-AA-20251103"

echo "📝 Setting up Automation Variables..."

# Note: Azure CLI doesn't have direct automation variable commands
# These need to be set via Azure Portal or PowerShell
echo
echo "🏗️ Required Automation Variables (set via Azure Portal):"
echo "--------------------------------------------------------"
echo
echo "Variable 1: Certificate Validity Period"
echo "  Name: CertificateValidityMonths"
echo "  Value: 12 (current), 6 (2026), 3 (2027), 1.5 (2029)"
echo "  Type: Integer"
echo "  Description: Certificate validity period in months"
echo
echo "Variable 2: Renewal Threshold"  
echo "  Name: CertRenewalThresholdDays"
echo "  Value: 30 (current), adjust based on certificate lifetime"
echo "  Type: Integer"
echo "  Description: Days before expiration to trigger renewal"
echo

echo "🌐 Portal Navigation:"
echo "Azure Portal → Resource Groups → $RESOURCE_GROUP → $AUTOMATION_ACCOUNT → Variables → Add Variable"
echo

echo "📊 Recommended Settings by Timeline:"
echo "======================================"
echo
echo "2025 (Current):"
echo "  CertificateValidityMonths: 12"
echo "  CertRenewalThresholdDays: 30"
echo
echo "2026 (Max 200 days):"
echo "  CertificateValidityMonths: 6"
echo "  CertRenewalThresholdDays: 30"
echo
echo "2027 (Max 100 days):"
echo "  CertificateValidityMonths: 3"
echo "  CertRenewalThresholdDays: 21"
echo
echo "2029 (Max 47 days):"
echo "  CertificateValidityMonths: 1.5"
echo "  CertRenewalThresholdDays: 14"

echo
echo "🧪 Testing Recommendations:"
echo "============================="
echo
echo "For Demo Environment (immediate testing):"
echo "  CertificateValidityMonths: 1 (practice monthly renewals)"
echo "  CertRenewalThresholdDays: 7 (test weekly automation)"
echo
echo "✅ Benefits of Configurable Lifetime:"
echo "• Prepares for industry certificate lifetime reductions"
echo "• Allows gradual transition and testing"
echo "• Enables different policies for different environments"
echo "• Reduces future migration complexity"

echo
echo "🚀 Next Steps:"
echo "1. Set CertificateValidityMonths = 12 (maintain current behavior)"
echo "2. Test with shorter periods in demo environment"
echo "3. Monitor automation performance with increased frequency"
echo "4. Plan transition timeline based on CA/B Forum schedule"