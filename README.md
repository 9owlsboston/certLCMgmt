# Certificate Lifecycle Management Automation

This repository provides comprehensive solutions for automating SSL/TLS certificate management using Azure services. The solution leverages Azure Key Vault, Event Grid, Azure Automation, and other Azure services to streamline certificate issuance, renewal, and deployment.

## 🏗️ Implementation Options

This repository offers **two approaches** for certificate lifecycle management:

### 1. **Original ARM Template Implementation** (External Reference, ARM-based depployment)
- **Source**: [Certificate Lifecycle GitHub Repository](https://github.com/Azure/certlc)


- **Method**: Clone the official Microsoft repository for ARM template deployment
- **Use Case**: Portal-based deployment with original Microsoft reference implementation
- **Note**: See `docs/certlc-notes/` for additional deployment instructions and best practices

### 2. **Azure CLI Based Scripts** (`certificate-lifecycle-scripts/`)
- **Source**: This repository - custom implementation
- **Method**: Azure CLI-based deployment with configuration management
- **Use Case**: Script-based deployment with standardized configuration, idempotency, and comprehensive error handling
- **Features**: `.env` configuration, validation, monitoring, and target server integration

### 3. **Operational & Diagnostic Scripts** (`certlc-deployment-scripts/`)
- **Source**: This folder - operational utilities to support certlc testing
- **Method**: Organized operational utilities with comprehensive monitoring
- **Use Case**: Certificate lifecycle monitoring, deployment assistance, troubleshooting, and operational maintenance
- **Features**: End-to-end monitoring tools, diagnostic utilities, testing frameworks, and comprehensive documentation
- **Structure**: Organized into `monitoring/`, `deployment/`, `testing/`, `diagnostics/`, and `docs/` subdirectories

## 📚 Documentation

- **[Certificate Deployment Reference](CERTIFICATE_DEPLOYMENT_REFERENCE.md)** - Comprehensive guide for target server integration
- **[Environment Variables Guide](ENVIRONMENT_VARIABLES_GUIDE.md)** - Best practices for configuration management
- **[Azure CLI Scripts README](certificate-lifecycle-scripts/README-AZURE-CLI.md)** - Detailed guide for CLI-based deployment

## 📁 Project Structure

```
certLCMgmt/
├── README.md                           # This file - project overview and guidance
├── CERTIFICATE_DEPLOYMENT_REFERENCE.md # Target server integration guide
├── ENVIRONMENT_VARIABLES_GUIDE.md     # Configuration best practices
├── IDEMPOTENCY_SUMMARY.md             # Idempotency implementation details
│
├── certificate-lifecycle-scripts/     # Enhanced Azure CLI Implementation
│   ├── README-AZURE-CLI.md           # CLI scripts documentation
│   ├── config.sh                     # Configuration management system
│   ├── .env.example                  # Configuration template
│   ├── 01-environment-setup.sh       # Environment configuration
│   ├── 02-core-infrastructure.sh     # Core Azure resources
│   ├── 03-event-grid-setup.sh        # Event Grid configuration
│   ├── 04-automation-setup.sh        # Automation Account setup
│   ├── 05-rbac-permissions.sh        # RBAC and permissions
│   ├── deploy-all.sh                 # Complete deployment orchestrator
│   └── validate-deployment.sh        # Deployment validation
│
├── certlc-deployment-scripts/         # Operational & Diagnostic Scripts
│   ├── DEPLOYMENT_OVERVIEW.md        # Deployment guidance and overview
│   ├── deploy.sh                     # Main deployment script
│   ├── check-deployment-status.sh    # Status checking utilities
│   ├── check-keyvault-names.sh       # Key Vault name validation
│   ├── diagnose-keyvault.sh          # Key Vault diagnostic tools
│   ├── deploy-keyvault-only.sh       # Partial Key Vault deployment
│   ├── deploy-missing-resources.sh   # Deploy missing components
│   ├── create-expired-cert.ps1       # Testing utilities
│   ├── manual-cert-creation.ps1      # Manual certificate operations
│   └── ...                           # Additional operational scripts
│
└── docs/certlc-notes/                  # Documentation and Guides
    ├── LAB_INSTRUCTIONS.md            # Lab environment setup
    ├── PRODUCTION_BASE_INSTRUCTIONS.md # Production deployment guide
    └── PRODUCTION_DASHBOARD_INSTRUCTIONS.md # Dashboard configuration
```

## 🚀 Quick Start Guide

### For Original ARM Template Deployment:
```bash
# Clone the official Microsoft repository
git clone https://github.com/Azure-Samples/certificate-lifecycle-management.git
cd certificate-lifecycle-management
# Follow the instructions in their README.md
```

### For Azure CLI Deployment:
```bash
cd certificate-lifecycle-scripts
./config.sh init          # Create configuration from template
nano .env                 # Edit configuration with your values
./config.sh validate      # Validate settings
./deploy-all.sh           # Deploy complete infrastructure
```

### For Operational Scripts:
```bash
cd certlc-deployment-scripts
# Review DEPLOYMENT_OVERVIEW.md for guidance
./check-deployment-status.sh    # Check existing deployment
./deploy-keyvault-only.sh       # Deploy only Key Vault components
./diagnose-keyvault.sh          # Diagnose Key Vault issues
```

[Azure Reference Documentation](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

---

To automate certificate renewal for **non-integrated CAs** (i.e., certificates imported into Azure Key Vault from external or self-hosted CAs), you can build a fully automated solution using Azure-native services. Here's a detailed breakdown of the recommended architecture and workflow:

***

## 🎯 Architecture Overview

A robust automation pipeline comprises the following Azure components:

1.  **Key Vault** – stores the imported certificate and emits expiration events
2.  **Event Grid** – captures certificate lifecycle events
3.  **Storage Queue** – queues the certificate renewal request
4.  **Automation Account + Hybrid Runbook Worker** – runs scripts to renew and merge certificates
5.  **CA Server (on‑premises or Azure VM)** – issues the new certificate
6.  **Key Vault Extension or script on target servers** – deploys the renewed certificate

### 🔄 Renewal Workflow

1.  **Import certificate** from your external CA into Key Vault.
2.  **Set up tags or alerts** for near-expiry notifications using Key Vault's policy/event features. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
3.  When expiration nears, **Key Vault emits** a `CertificateNearExpiry` event to Event Grid. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
4.  **Event Grid** fans out the event to:
    *   a Storage Queue, and
    *   a webhook in an Automation Account. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
5.  The **runbook** on a Hybrid Runbook Worker (connected to your CA or on-premise network) does the following:
    *   Reads the queue,
    *   Calls Key Vault to generate a **new CSR**,
    *   Submits the CSR to your CA for signing,
    *   Merges the signed certificate back into Key Vault, creating a new version. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
6.  **Key Vault Extension or custom scripts** on your servers detect the new version and **automatically deploy** the renewed certificate. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
7.  The pipeline logs actions via **Log Analytics** and can send email notifications.

***

## ✅ Step-by-Step Implementation

### 1. **Import Certificate & Configure Key Vault**

*   Upload your CA-issued certificate to Key Vault.
*   Tag the certificate with metadata (e.g., `Recipient=<admin emails>`) or configure Key Vault contacts to get notified when the cert nears expiration. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

### 2. **Set Up Event Grid & Storage Queue**

*   Create an **Event Grid system topic** from your Key Vault.
*   Subscribe **two endpoints**:
    *   **Storage Queue** for queuing renewal jobs
    *   **Webhook** to trigger the Automation Runbook. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

### 3. **Configure Automation Account with Hybrid Worker**

*   Deploy an Automation Account and **Hybrid Runbook Worker** on a server that has network access to your CA.
*   Author a **PowerShell runbook** that:
    1.  Reads from the Storage Queue
    2.  Requests a new CSR from Key Vault
    3.  Submits CSR to CA and retrieves the signed cert
    4.  Calls `Merge Signed Request` against Key Vault
    5.  Optionally, sends email notifications and logs results to Log Analytics [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

### 4. **Deploy Renewed Cert to Servers**

*   **Windows/IIS or Azure VMs**: install the **Key Vault extension** to monitor and pull updated certificates. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)
*   **Linux or Azure Arc live servers**: use a scheduled script to inspect Key Vault and deploy new certs (same as for non-supported Linux distros). [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

### 5. **Monitoring & Alerts**

*   Use **Log Analytics + Azure Workbooks** to visualize certificate expiry status.
*   Email alerts/notifications can be triggered by runbook events or certificate tags.

***

## 🔍 Why This Works

*   **Near-zero downtime**: new cert version is created and deployed before expiration.
*   **Full automation**: no manual CSR download/upload.
*   **Secure key handling**: private keys remain within Key Vault—they’re never exposed.
*   **Scalable & monitored**: Event Grid + queueing + log analytics ensure visibility and resiliency. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/certificate-lifecycle/)

***

## 🛠 Summary Table

| Component                    | Role                                         |
| ---------------------------- | -------------------------------------------- |
| Key Vault                    | Stores cert, issues CSR, merges renewed cert |
| Event Grid                   | Detects near-expiry cert events              |
| Storage Queue                | Queues renewal jobs reliably                 |
| Automation + Hybrid Worker   | Automates CSR issuance & CA submission       |
| CA Server                    | Signs CSRs with your non-integrated CA       |
| Key Vault Extension / Script | Deploys renewed certs to servers             |
| Log Analytics + Workbooks    | Tracks status and alerts                     |

***

### ⏭ Next Steps

Tell me your environment specifics—**CA type**, **runbook scripting language preference**, and **target OS/platform**—and I’ll provide a ready-to-use **PowerShell runbook**, ARM/Bicep templates, and deployment scripts for automation and deployment.

### PowerShell runbook and Event Grid setup


Absolutely—here’s a ready-to-use blueprint to wire **Azure Key Vault → Event Grid → Azure Automation (PowerShell runbook)** for certificate renewal/rotation events. It includes:

*   An **architecture overview**
*   **Prereqs & permissions**
*   A **production‑ready PowerShell runbook** (parses Event Grid payloads, branches on event type, renews or imports a cert)
*   **Event Grid subscription** creation (CLI) targeting an **Automation webhook**
*   Hardening tips & validation steps

***

## 0) What this workflow does

1.  **Key Vault** emits lifecycle events (e.g., **CertificateNearExpiry** 30 days before expiry, **CertificateExpired**, **CertificateNewVersionCreated**). [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault)
2.  **Event Grid** forwards those events to an **Azure Automation runbook** via a **webhook**. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/handler-webhooks), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-tutorial)
3.  The **runbook** inspects the event, then:
    *   For **integrated CA** (DigiCert/GlobalSign) certs: optionally trigger a new version (or let Key Vault’s autorotation handle it). [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-rotate-certificates), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate)
    *   For **non‑integrated CA** certs: **import a new PFX** (pre‑staged) as a **new certificate version** in Key Vault. [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0)

***

## 1) Prerequisites & minimum permissions

*   **Key Vault** that holds your certificates. (Key Vault publishes certificate/key/secret events into Event Grid.) [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-overview)
*   **Azure Automation account** with **System-assigned Managed Identity** enabled (recommended). You’ll call `Connect-AzAccount -Identity` in runbook.
*   **Permissions for the Automation identity on the Key Vault**:
    *   If using **Access Policies**: grant at least **Certificates: get, list, import, create** and **Secrets: get** (if you need to read the PFX as a secret). [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-import-certificate)
    *   Or with **RBAC**, grant roles that map to those operations (e.g., certificate management roles). (Docs enumerate needed ops for import/create.) [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0)
*   **Az modules** in Automation: `Az.Accounts`, `Az.KeyVault` (current versions). Module reference: Az.KeyVault. [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/?view=azps-14.5.0)

> **Note on events:** Key Vault emits **CertificateNearExpiry** exactly **30 days prior** to expiry (not configurable). Use additional logic if you want 10‑day reminders. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault), [stackoverflow.com](https://stackoverflow.com/questions/64872379/how-can-we-configure-near-expiry-event-time-in-azure-key-vault)

***

## 2) Create the PowerShell runbook

### 2.1. New runbook (PowerShell 7.2 or 5.1)

*   In your Automation account → **Runbooks** → **Create a runbook** → Type: **PowerShell** → paste code below → **Publish**.
*   The runbook must accept **`$WebhookData`** (Event Grid posts JSON to your webhook). [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-tutorial)

```powershell
param(
    [Parameter(Mandatory = $false)]
    [object] $WebhookData
)

# ===== Settings you can customize =====
# For non-integrated CAs, the runbook can import a pre-staged PFX (e.g., from storage or as a KV secret).
# Example: $PfxSecureStringPassword = (Get-AutomationVariable -Name 'PfxPassword') | ConvertTo-SecureString -AsPlainText -Force
# Example: $PfxLocalPath = "D:\home\site\wwwroot\certs\mycert.pfx"   # or download at runtime

$ErrorActionPreference = "Stop"

function Write-Log($msg) {
    Write-Output ("[{0:u}] {1}" -f (Get-Date).ToUniversalTime(), $msg)
}

if (-not $WebhookData) {
    throw "This runbook must be invoked by an Event Grid webhook with WebhookData."
}

# Event Grid posts either EventGrid schema (array) or CloudEvents v1.0 (array).
$raw = $WebhookData.RequestBody
if (-not $raw) { throw "No RequestBody found in WebhookData." }

try {
    $events = $raw | ConvertFrom-Json
} catch {
    throw "Failed to parse RequestBody JSON: $($_.Exception.Message)"
}

if (-not ($events -is [System.Collections.IEnumerable])) { $events = @($events) }
$first = $events[0]

# Determine schema based on top-level field names
$schema = if ($first.eventType) { "EventGrid" } elseif ($first.type) { "CloudEvents" } else { "Unknown" }

# Extract standard fields from Key Vault event
switch ($schema) {
    "EventGrid" {
        $eventType = $first.eventType
        $subject   = $first.subject
        $data      = $first.data
        $kvName    = $data.VaultName
        $objType   = $data.ObjectType       # "Certificate" | "Key" | "Secret"
        $objName   = $data.ObjectName       # certificate name
        $version   = $data.Version
        $exp       = $data.EXP
    }
    "CloudEvents" {
        $eventType = $first.type
        $subject   = $first.subject
        $data      = $first.data
        $kvName    = $data.VaultName
        $objType   = $data.ObjectType
        $objName   = $data.ObjectName
        $version   = $data.Version
        $exp       = $data.EXP
    }
    default { throw "Unsupported event schema. Cannot extract Key Vault fields." }
}

Write-Log "Schema=$schema  EventType=$eventType  Vault=$kvName  ObjectType=$objType  Name=$objName  Version=$version  Exp=$exp"

# Only react to certificate events (ignore keys/secrets)
if ($objType -ne "Certificate") {
    Write-Log "Ignoring non-certificate event: $objType"
    return
}

# Authenticate as the Automation Account's Managed Identity
try {
    Connect-AzAccount -Identity | Out-Null
} catch {
    throw "Connect-AzAccount -Identity failed: $($_.Exception.Message)"
}

# Utility: get current certificate policy (useful to know issuer, autorotation settings, reuse key flag)
function Get-CertPolicy([string]$VaultName, [string]$Name) {
    try {
        return Get-AzKeyVaultCertificatePolicy -VaultName $VaultName -Name $Name
    } catch {
        Write-Log "Could not retrieve policy for $Name in $VaultName: $($_.Exception.Message)"
        return $null
    }
}

# Utility: create a new version via policy (works for self-signed or integrated CA if policy allows)
function New-CertVersionFromPolicy([string]$VaultName, [string]$Name, $Policy) {
    if (-not $Policy) { throw "Policy is required to create a new version." }
    Write-Log "Triggering new certificate version for '$Name' (issuer=$($Policy.IssuerName)) in vault '$VaultName'..."
    # Add-AzKeyVaultCertificate starts an enrollment per the supplied policy; if Name exists, it creates a NEW VERSION
    Add-AzKeyVaultCertificate -VaultName $VaultName -Name $Name -CertificatePolicy $Policy | Out-Null
    Write-Log "Enrollment started. The new version will appear when the CA operation completes."
}

# Utility: import a PFX as a new version for non-integrated CA path (replace with how you obtain the PFX)
function Import-PfxVersion([string]$VaultName, [string]$Name, [string]$PfxPath, [securestring]$PfxPassword, $Policy=$null) {
    if (-not (Test-Path $PfxPath)) { throw "PFX not found at $PfxPath" }
    Write-Log "Importing PFX as new version for '$Name' in vault '$VaultName'..."
    Import-AzKeyVaultCertificate -VaultName $VaultName -Name $Name -FilePath $PfxPath -Password $PfxPassword -PolicyObject $Policy | Out-Null
    Write-Log "Import complete. A new certificate version has been created."
}

# Branch on the event type
switch ($eventType) {

    # 30-day heads up (cannot be changed)
    "Microsoft.KeyVault.CertificateNearExpiry" {
        Write-Log "Handling NearExpiry for $objName"

        $policy = Get-CertPolicy -VaultName $kvName -Name $objName

        if ($policy -and $policy.IssuerName -in @("DigiCert","GlobalSign")) {
            # Integrated CA: Key Vault can auto-renew based on policy (lifetime actions).
            # Optionally, force an early re-enrollment to create a new version now:
            # New-CertVersionFromPolicy -VaultName $kvName -Name $objName -Policy $policy
            Write-Log "Integrated CA detected; rely on Key Vault autorotation per policy."
        }
        else {
            # Non-integrated CA path — import a pre-issued PFX (example placeholders below)
            # $pfxPath = "D:\home\site\wwwroot\certs\$objName.pfx"
            # $pfxPass = (Get-AutomationVariable -Name 'PfxPassword') | ConvertTo-SecureString -AsPlainText -Force
            # Import-PfxVersion -VaultName $kvName -Name $objName -PfxPath $pfxPath -PfxPassword $pfxPass -Policy $policy
            Write-Log "Non-integrated CA flow: supply/import new PFX to create a new version (placeholder)."
        }
    }

    "Microsoft.KeyVault.CertificateExpired" {
        Write-Log "Handling Expired for $objName"

        $policy = Get-CertPolicy -VaultName $kvName -Name $objName

        if ($policy -and $policy.IssuerName -in @("DigiCert","GlobalSign")) {
            # Trigger a new version via policy (if autorotation failed)
            New-CertVersionFromPolicy -VaultName $kvName -Name $objName -Policy $policy
        }
        else {
            # Non-integrated CA flow: import a new PFX version
            # $pfxPath = "D:\home\site\wwwroot\certs\$objName.pfx"
            # $pfxPass = (Get-AutomationVariable -Name 'PfxPassword') | ConvertTo-SecureString -AsPlainText -Force
            # Import-PfxVersion -VaultName $kvName -Name $objName -PfxPath $pfxPath -PfxPassword $pfxPass -Policy $policy
            Write-Log "Non-integrated CA flow: supply/import new PFX to create a new version (placeholder)."
        }
    }

    "Microsoft.KeyVault.CertificateNewVersionCreated" {
        Write-Log "New certificate version created for $objName — consider pushing to dependent services here."
        # TODO: Add code to update App Service, Application Gateway, APIM, etc.
        # (Use their respective Az.* modules; reference the new version by its SecretId from Get-AzKeyVaultCertificate)
    }

    default {
        Write-Log "Event type '$eventType' not handled by this runbook."
    }
}

Write-Log "Runbook completed."
```

**Notes & references:**

*   **Event schema fields** (`VaultName`, `ObjectType`, `ObjectName`, `Version`, `EXP`) come from the **Key Vault Event Grid schema**. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault)
*   `Add-AzKeyVaultCertificate` **creates a new version** when a cert of the **same name** exists (used for renewals). [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/add-azkeyvaultcertificate?view=azps-12.5.0), [stackoverflow.com](https://stackoverflow.com/questions/63678349/azure-cli-or-powershell-command-to-create-new-version-of-a-certificate-in-keyvau)
*   For **non‑integrated CAs**, import the PFX as a **new version** with `Import-AzKeyVaultCertificate` (PFX/PEM w/ private key required). [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-import-certificate)
*   **Integrated CA auto‑rotation** is managed by policy (DigiCert/GlobalSign). You can adjust **lifetime actions**; Key Vault handles renewals. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-rotate-certificates), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate)

***

## 3) Create the Automation **webhook** for this runbook

1.  In your runbook → **Webhooks** → **Create** → set expiry → **copy the URL** (you can’t see it again). Treat it like a secret. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/automation/automation-webhooks), [github.com](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/automation/automation-webhooks.md)
2.  (Optional but recommended) Store that webhook URL in a **Key Vault secret** and reference it during provisioning.

***

## 4) Wire **Event Grid** from **Key Vault** to the runbook webhook

> Key Vault integrates with **Event Grid system topics**; you create the **event subscription** directly on the vault. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-overview), [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault)

### 4.1. Grab IDs & webhook URL

```bash
# Variables
SUB_ID=$(az account show --query id -o tsv)
RG="<resource-group>"
KV_NAME="<your-keyvault>"
WEBHOOK_URL="<paste-the-automation-webhook-url>"

KV_ID="/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KV_NAME"
```

### 4.2. Create the Event Grid subscription (Azure CLI)

```bash
# Create an Event Grid event subscription from Key Vault to the Automation webhook
az eventgrid event-subscription create \
  --name kv-cert-lifecycle-to-automation \
  --source-resource-id "$KV_ID" \
  --endpoint "$WEBHOOK_URL" \
  --endpoint-type webhook \
  --included-event-types Microsoft.KeyVault.CertificateNearExpiry \
                          Microsoft.KeyVault.CertificateExpired \
                          Microsoft.KeyVault.CertificateNewVersionCreated \
  --event-delivery-schema eventgridschema
```

*   CLI reference for `event-subscription create` and parameters: **`az eventgrid event-subscription`**. [learn.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/eventgrid/event-subscription?view=azure-cli-latest), [learn.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/eventgrid?view=azure-cli-latest)
*   Key Vault **event type names** used above come from the **Key Vault event schema**. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault)
*   Endpoints can be **webhooks** (Automation runbooks), Functions, Logic Apps, etc. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/handler-webhooks)

> **FYI**: Key Vault event source uses **system topics**, not custom topics (design choice). You subscribe directly on the vault resource. [stackoverflow.com](https://stackoverflow.com/questions/66202456/azure-key-vault-event-is-it-possible-to-subscribe-to-event-grid-topic-not-sys)

***

## 5) Hardening & operations

*   **Webhook security**: The webhook URL is a bearer‑style secret; rotate before webhook expiry; keep it in Key Vault. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/automation/automation-webhooks)
*   **Idempotency**: Event Grid may deliver at‑least‑once. Your runbook already ignores non‑certificate events and unhandled types; consider de‑duping if you add external calls. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-overview)
*   **Testing**:
    *   Trigger a **new version** manually (e.g., via policy) to see **CertificateNewVersionCreated** flow. You can do this using `Add-AzKeyVaultCertificate` with the existing policy (creates a new version). [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/add-azkeyvaultcertificate?view=azps-12.5.0), [stackoverflow.com](https://stackoverflow.com/questions/63678349/azure-cli-or-powershell-command-to-create-new-version-of-a-certificate-in-keyvau)
    *   To simulate non‑integrated CA renewal, **import** a staged PFX with the same name—Key Vault will create a **new version**. [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0)

***

## 6) When to let Key Vault do it vs. your runbook

*   **Integrated CA (DigiCert/GlobalSign)**: prefer **Key Vault autorotation** and keep the runbook as a safety net (e.g., if an autorenew failed). Adjust lifecycle actions in the certificate policy to meet your SLO (e.g., renew at 80% life, email contacts). [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-rotate-certificates)
*   **Non‑integrated CA**: use **this Event Grid → runbook** path to **import** new PFX versions and then propagate to dependent services. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/overview-renew-certificate)

***

## 7) (Optional) Push updated certs to dependent services

Once a **new version** is created, add code under the `Microsoft.KeyVault.CertificateNewVersionCreated` branch to update:

*   **App Service** (upload/Bind to TLS)
*   **Application Gateway** (ssl cert / listener)
*   **API Management** (management and client certs)

(Use the corresponding Az modules; you’ll reference the **new secret version** from `Get-AzKeyVaultCertificate`.) Vendor‑specific binding steps are outside this runbook’s scope but follow the same pattern.

***

## 8) Why this approach

*   **Event-driven**—no polling; Key Vault pushes events (NearExpiry = **30 days** ahead) to your handler. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/event-grid/event-schema-key-vault)
*   **Serverless ops**—you pay per event and job runtime. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-overview)
*   **Flexible**—supports both **autorotation (integrated CA)** and **manual import (non‑integrated CA)** paths. [learn.microsoft.com](https://learn.microsoft.com/en-us/azure/key-vault/certificates/tutorial-rotate-certificates), [learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/az.keyvault/import-azkeyvaultcertificate?view=azps-14.4.0)

***

### To tailor this for your exact services

*   **Key Vault name** and whether the certs are **integrated CA** or **non‑integrated**.
*   Which **downstream services** need updates (App Service, App Gateway, APIM, …).

Runbook and add the binding code.

