#!/bin/bash
# example-certificate-provisioning.sh
# Demonstrates certificate provisioning workflow for integrated CAs

set -e

VAULT_NAME="my-keyvault"
RESOURCE_GROUP="my-rg"

echo "🔐 Certificate Provisioning Workflow for Integrated CAs"
echo "======================================================"

# Function to create certificate policy
create_cert_policy() {
    local domain="$1"
    local cert_name="$2"
    local validity_months="${3:-12}"
    local renew_percentage="${4:-80}"
    
    echo "📝 Creating policy for $domain..."
    
    cat > "${cert_name}-policy.json" << EOF
{
  "issuerParameters": {
    "name": "DigiCert"
  },
  "x509CertificateProperties": {
    "subject": "CN=$domain",
    "subjectAlternativeNames": {
      "dnsNames": ["$domain"]
    },
    "validityInMonths": $validity_months
  },
  "lifetimeActions": [
    {
      "trigger": {
        "lifetimePercentage": $renew_percentage
      },
      "action": {
        "actionType": "AutoRenew"
      }
    },
    {
      "trigger": {
        "lifetimePercentage": $renew_percentage
      },
      "action": {
        "actionType": "EmailContacts"
      }
    }
  ],
  "keyProperties": {
    "reuseKey": false,
    "keyType": "RSA",
    "keySize": 2048
  }
}
EOF
    
    echo "✅ Policy created: ${cert_name}-policy.json"
}

# Function to create certificate with policy
create_certificate() {
    local cert_name="$1"
    local policy_file="${cert_name}-policy.json"
    
    echo "🚀 Creating certificate: $cert_name"
    
    # Create certificate using the policy
    az keyvault certificate create \
        --vault-name "$VAULT_NAME" \
        --name "$cert_name" \
        --policy "@$policy_file"
    
    echo "✅ Certificate creation initiated: $cert_name"
}

# Function to monitor certificate creation
monitor_certificate() {
    local cert_name="$1"
    local max_attempts=20
    local attempt=1
    
    echo "⏳ Monitoring certificate creation: $cert_name"
    
    while [ $attempt -le $max_attempts ]; do
        # Check if certificate is ready
        STATUS=$(az keyvault certificate show \
            --vault-name "$VAULT_NAME" \
            --name "$cert_name" \
            --query "attributes.enabled" \
            --output tsv 2>/dev/null || echo "false")
        
        if [ "$STATUS" = "true" ]; then
            echo "✅ Certificate ready: $cert_name"
            
            # Show certificate details
            az keyvault certificate show \
                --vault-name "$VAULT_NAME" \
                --name "$cert_name" \
                --query "{Name:name, Subject:policy.x509CertificateProperties.subject, ValidFrom:attributes.notBefore, ValidTo:attributes.expires, Thumbprint:x509Thumbprint}" \
                --output table
            return 0
        else
            echo "   Attempt $attempt/$max_attempts - Certificate not ready yet..."
            sleep 30
            ((attempt++))
        fi
    done
    
    echo "❌ Certificate creation timed out: $cert_name"
    return 1
}

# Main execution
main() {
    echo "Starting certificate provisioning workflow..."
    
    # Define certificates to create
    declare -A certificates=(
        ["api.example.com"]="api-example-com-cert"
        ["admin.example.com"]="admin-example-com-cert"
        ["portal.example.com"]="portal-example-com-cert"
    )
    
    # Step 1: Create policies for all certificates
    echo ""
    echo "📋 Step 1: Creating certificate policies"
    echo "----------------------------------------"
    for domain in "${!certificates[@]}"; do
        cert_name="${certificates[$domain]}"
        create_cert_policy "$domain" "$cert_name"
    done
    
    # Step 2: Create certificates using policies
    echo ""
    echo "🔐 Step 2: Creating certificates with policies"
    echo "----------------------------------------------"
    for domain in "${!certificates[@]}"; do
        cert_name="${certificates[$domain]}"
        create_certificate "$cert_name"
        echo ""
    done
    
    # Step 3: Monitor certificate creation
    echo ""
    echo "👀 Step 3: Monitoring certificate creation"
    echo "------------------------------------------"
    for domain in "${!certificates[@]}"; do
        cert_name="${certificates[$domain]}"
        monitor_certificate "$cert_name"
        echo ""
    done
    
    echo "🎉 Certificate provisioning workflow completed!"
}

# Wildcard certificate example
create_wildcard_certificate() {
    local domain="*.example.com"
    local cert_name="wildcard-example-com-cert"
    
    echo "🌟 Creating wildcard certificate policy..."
    
    cat > "${cert_name}-policy.json" << EOF
{
  "issuerParameters": {
    "name": "DigiCert"
  },
  "x509CertificateProperties": {
    "subject": "CN=*.example.com",
    "subjectAlternativeNames": {
      "dnsNames": ["*.example.com", "example.com"]
    },
    "validityInMonths": 12
  },
  "lifetimeActions": [
    {
      "trigger": {
        "lifetimePercentage": 80
      },
      "action": {
        "actionType": "AutoRenew"
      }
    }
  ],
  "keyProperties": {
    "reuseKey": false,
    "keyType": "RSA",
    "keySize": 2048
  }
}
EOF
    
    echo "🚀 Creating wildcard certificate..."
    az keyvault certificate create \
        --vault-name "$VAULT_NAME" \
        --name "$cert_name" \
        --policy "@${cert_name}-policy.json"
    
    monitor_certificate "$cert_name"
}

# Helper function to show all certificates
show_all_certificates() {
    echo "📊 Current certificates in Key Vault:"
    echo "------------------------------------"
    az keyvault certificate list \
        --vault-name "$VAULT_NAME" \
        --query "[].{Name:name, Subject:policy.x509CertificateProperties.subject, ValidFrom:attributes.notBefore, ValidTo:attributes.expires, Status:attributes.enabled}" \
        --output table
}

# Usage examples
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-main}" in
        "main")
            main
            ;;
        "wildcard")
            create_wildcard_certificate
            ;;
        "show")
            show_all_certificates
            ;;
        *)
            echo "Usage: $0 [main|wildcard|show]"
            echo "  main     - Create multiple individual certificates"
            echo "  wildcard - Create wildcard certificate"
            echo "  show     - Show all certificates"
            ;;
    esac
fi