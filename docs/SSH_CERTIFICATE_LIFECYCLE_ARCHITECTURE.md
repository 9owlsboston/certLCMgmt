# 🔐 SSH Certificate Lifecycle Management - Proposed Architecture

## Executive Summary

This document proposes an extension to the existing Certificate Lifecycle Management system to support **SSH Certificate signing and lifecycle management** using a **custom Azure-native signing service**. The solution leverages Azure Key Vault for CA key storage, Azure Functions for certificate signing, and integrates with the existing Event Grid and Automation infrastructure.

---

## 📊 Solution Overview

### Current State (X.509 TLS Certificates)
```
Azure Key Vault → Event Grid → Automation Runbook → Enterprise CA → Certificate Renewal
```

### Proposed State (SSH Certificates Added)
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Unified Credential Lifecycle Management                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────┐   ┌─────────────────────────────────┐ │
│  │     X.509 Certificate Lifecycle     │   │    SSH Certificate Lifecycle    │ │
│  │                                     │   │                                 │ │
│  │  Key Vault → Event Grid → CA       │   │  Key Vault → Event Grid → SSH  │ │
│  │              → Hybrid Worker        │   │              → Azure Function   │ │
│  │              → Enterprise CA        │   │              → SSH CA Service   │ │
│  └─────────────────────────────────────┘   └─────────────────────────────────┘ │
│                                                                                 │
│                    ┌───────────────────────────────────┐                       │
│                    │      Shared Infrastructure        │                       │
│                    │  • Azure Key Vault (CA Keys)      │                       │
│                    │  • Event Grid (Triggers)          │                       │
│                    │  • Monitoring (App Insights)      │                       │
│                    │  • RBAC & Managed Identity        │                       │
│                    └───────────────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Detailed Architecture

### Component Diagram

```
                                    ┌─────────────────────────────────────┐
                                    │         Azure Key Vault             │
                                    │  ┌─────────────┬─────────────────┐  │
                                    │  │ SSH CA Keys │ SSH Certificates│  │
                                    │  │ (HSM-backed)│ (User/Host)     │  │
                                    │  └──────┬──────┴────────┬────────┘  │
                                    └─────────┼───────────────┼───────────┘
                                              │               │
                    ┌─────────────────────────┼───────────────┼─────────────────────────┐
                    │                         │               │                         │
                    ▼                         ▼               │                         │
        ┌───────────────────┐     ┌───────────────────┐       │                         │
        │   Event Grid      │     │  SSH Signing API  │       │                         │
        │   Topic           │     │  (Azure Function) │       │                         │
        │                   │     │                   │       │                         │
        │ • KeyNearExpiry   │────▶│ • Sign user certs │       │                         │
        │ • CertRotation    │     │ • Sign host certs │       │                         │
        │ • ManualRequest   │     │ • Validate request│       │                         │
        └───────────────────┘     └─────────┬─────────┘       │                         │
                                            │                 │                         │
                                            ▼                 │                         │
                              ┌─────────────────────────┐     │                         │
                              │   Certificate Store     │     │                         │
                              │   (Blob Storage)        │◀────┘                         │
                              │                         │                               │
                              │ • Signed certificates   │                               │
                              │ • Audit logs            │                               │
                              │ • Revocation list       │                               │
                              └───────────┬─────────────┘                               │
                                          │                                             │
                    ┌─────────────────────┼─────────────────────┐                       │
                    │                     │                     │                       │
                    ▼                     ▼                     ▼                       │
        ┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐               │
        │   Linux Hosts     │ │   User Endpoints  │ │   Bastion/Jump    │               │
        │   (TrustedUserCA) │ │   (SSH Clients)   │ │   (Audit Point)   │               │
        └───────────────────┘ └───────────────────┘ └───────────────────┘               │
```

---

## ⚡ SSH Certificate Flow Sequences

### Flow 1: User Certificate Issuance (On-Demand)

```
┌──────────┐      ┌─────────────┐      ┌──────────────┐      ┌───────────┐      ┌────────────┐
│  User    │      │  Azure AD   │      │ SSH Signing  │      │ Key Vault │      │   Target   │
│ Request  │      │   (AuthN)   │      │   Function   │      │ (SSH CA)  │      │   Hosts    │
└────┬─────┘      └──────┬──────┘      └──────┬───────┘      └─────┬─────┘      └─────┬──────┘
     │                   │                    │                    │                  │
     │  1. Request cert  │                    │                    │                  │
     │──────────────────▶│                    │                    │                  │
     │                   │                    │                    │                  │
     │                   │ 2. Validate token  │                    │                  │
     │                   │───────────────────▶│                    │                  │
     │                   │                    │                    │                  │
     │                   │                    │ 3. Get CA key      │                  │
     │                   │                    │───────────────────▶│                  │
     │                   │                    │                    │                  │
     │                   │                    │ 4. Sign user cert  │                  │
     │                   │                    │◀───────────────────│                  │
     │                   │                    │    (HSM operation) │                  │
     │                   │                    │                    │                  │
     │  5. Signed SSH Certificate             │                    │                  │
     │◀───────────────────────────────────────│                    │                  │
     │                                        │                    │                  │
     │  6. SSH with certificate                                                       │
     │───────────────────────────────────────────────────────────────────────────────▶│
     │                                                                                │
     │  7. Validate against TrustedUserCAKeys                                         │
     │◀───────────────────────────────────────────────────────────────────────────────│
```

### Flow 2: Host Certificate Auto-Rotation (Event-Driven)

```
┌───────────┐     ┌─────────────┐     ┌──────────────┐     ┌───────────┐     ┌────────────┐
│ Key Vault │     │ Event Grid  │     │ SSH Signing  │     │ Automation│     │   Target   │
│ (Monitor) │     │   Topic     │     │   Function   │     │  Account  │     │   Host     │
└─────┬─────┘     └──────┬──────┘     └──────┬───────┘     └─────┬─────┘     └─────┬──────┘
      │                  │                   │                   │                 │
      │ 1. Host cert     │                   │                   │                 │
      │    near expiry   │                   │                   │                 │
      │─────────────────▶│                   │                   │                 │
      │                  │                   │                   │                 │
      │                  │ 2. Trigger event  │                   │                 │
      │                  │──────────────────▶│                   │                 │
      │                  │                   │                   │                 │
      │                  │                   │ 3. Generate new   │                 │
      │                  │                   │    host key pair  │                 │
      │                  │                   │                   │                 │
      │                  │                   │ 4. Sign host cert │                 │
      │                  │                   │    (self-sign     │                 │
      │                  │                   │     with CA key)  │                 │
      │                  │                   │                   │                 │
      │                  │                   │ 5. Store new cert │                 │
      │◀─────────────────────────────────────│                   │                 │
      │                  │                   │                   │                 │
      │                  │                   │ 6. Trigger deploy │                 │
      │                  │                   │──────────────────▶│                 │
      │                  │                   │                   │                 │
      │                  │                   │                   │ 7. Deploy cert  │
      │                  │                   │                   │────────────────▶│
      │                  │                   │                   │                 │
      │                  │                   │                   │ 8. Restart sshd │
      │                  │                   │                   │◀────────────────│
```

---

## 🔧 Component Specifications

### 1. SSH CA Key Storage (Azure Key Vault)

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **User CA Key** | RSA-4096 or Ed25519, HSM-backed | Signs user SSH certificates |
| **Host CA Key** | RSA-4096 or Ed25519, HSM-backed | Signs host SSH certificates |
| **Key Rotation Policy** | 2 years, automated | CA key lifecycle management |
| **Access Policy** | Managed Identity only | Zero standing privileges |

```bash
# Key Vault structure for SSH CA
keyvault/
├── keys/
│   ├── ssh-user-ca          # User certificate signing key
│   └── ssh-host-ca          # Host certificate signing key
├── secrets/
│   ├── ssh-user-ca-pub      # User CA public key (for distribution)
│   └── ssh-host-ca-pub      # Host CA public key (for distribution)
└── certificates/
    └── (existing X.509 certs)
```

### 2. SSH Signing Service (Azure Function)

**Runtime:** Python 3.11+ (aligns with existing linux-python-certlc project)  
**Trigger:** HTTP (API) + Event Grid (automation)  
**Authentication:** Azure AD + Managed Identity

#### API Endpoints

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/api/ssh/user/sign` | POST | Sign user certificate | Azure AD token |
| `/api/ssh/host/sign` | POST | Sign host certificate | Managed Identity |
| `/api/ssh/ca/public` | GET | Get CA public keys | Public |
| `/api/ssh/revoke` | POST | Add to revocation list | Admin role |
| `/api/ssh/health` | GET | Health check | None |

#### Sign Request Schema

```json
{
  "publicKey": "ssh-ed25519 AAAAC3Nza... user@host",
  "certificateType": "user",
  "principals": ["username", "admin"],
  "validityDuration": "8h",
  "extensions": {
    "permit-pty": "",
    "permit-port-forwarding": ""
  },
  "criticalOptions": {
    "source-address": "10.0.0.0/8,192.168.0.0/16"
  },
  "keyId": "user@example.com-20260122-abc123"
}
```

#### Sign Response Schema

```json
{
  "certificate": "ssh-ed25519-cert-v01@openssh.com AAAAIHNza...",
  "serialNumber": 1234567890,
  "validAfter": "2026-01-22T10:00:00Z",
  "validBefore": "2026-01-22T18:00:00Z",
  "principals": ["username", "admin"],
  "keyId": "user@example.com-20260122-abc123",
  "caFingerprint": "SHA256:abc123..."
}
```

### 3. Certificate Distribution & Deployment

#### User Certificates
- **Delivery:** Direct API response to requesting client
- **Storage:** Local SSH agent or `~/.ssh/id_ed25519-cert.pub`
- **Validity:** Short-lived (1-24 hours recommended)

#### Host Certificates  
- **Delivery:** Azure Automation Runbook deployment
- **Storage:** `/etc/ssh/ssh_host_ed25519_key-cert.pub`
- **Validity:** Medium-lived (30-90 days)
- **sshd_config:** `HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub`

#### CA Public Key Distribution
- **User CA → Hosts:** `/etc/ssh/trusted_user_ca_keys`
- **Host CA → Clients:** `~/.ssh/known_hosts` or `ssh_known_hosts`

### 4. Azure Automation Integration

Extends existing Automation Account with new runbooks:

| Runbook | Trigger | Purpose |
|---------|---------|---------|
| `Deploy-SSHHostCertificate` | Event Grid | Deploy rotated host certificates |
| `Distribute-SSHCAPublicKey` | Manual/Schedule | Push CA public key to all hosts |
| `Revoke-SSHCertificate` | Manual | Emergency certificate revocation |
| `Monitor-SSHCertificates` | Schedule (daily) | Report on certificate status |

---

## 🔒 Security Architecture

### Authentication & Authorization Flow

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              Security Layers                                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Layer 1: Identity                                                               │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  Azure AD Authentication                                                    │ │
│  │  • User principals (interactive)                                           │ │
│  │  • Service principals (automation)                                         │ │
│  │  • Managed identities (Azure resources)                                    │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                        │
│                                         ▼                                        │
│  Layer 2: Authorization                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  RBAC + Custom Roles                                                        │ │
│  │  • SSH-User-Certificate-Requester   (request own certs)                    │ │
│  │  • SSH-Host-Certificate-Admin       (manage host certs)                    │ │
│  │  • SSH-CA-Administrator             (CA key management)                    │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                        │
│                                         ▼                                        │
│  Layer 3: Policy Enforcement                                                     │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  Certificate Policy Engine (in Azure Function)                             │ │
│  │  • Maximum validity duration per principal                                 │ │
│  │  • Allowed principals per user/group                                       │ │
│  │  • Permitted extensions and critical options                               │ │
│  │  • Source IP restrictions                                                  │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                        │
│                                         ▼                                        │
│  Layer 4: Audit & Monitoring                                                     │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  • All signing requests logged to Log Analytics                            │ │
│  │  • Certificate metadata stored in Blob Storage                             │ │
│  │  • Alerts on anomalous patterns (high volume, unusual principals)          │ │
│  │  • Integration with Azure Sentinel for SIEM                                │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Certificate Policy Configuration

```yaml
# ssh-certificate-policy.yaml
userCertificates:
  maxValidityDuration: "24h"
  defaultValidityDuration: "8h"
  allowedPrincipals:
    - pattern: "${azure_ad_upn}"          # User's own username
    - pattern: "${azure_ad_groups}"       # Group-based principals
  requiredExtensions:
    - permit-pty
  forbiddenExtensions:
    - permit-agent-forwarding             # Disabled by policy
  criticalOptions:
    force-command: null                   # Not enforced by default
    source-address: null                  # Optional IP restriction

hostCertificates:
  maxValidityDuration: "90d"
  defaultValidityDuration: "30d"
  allowedPrincipals:
    - pattern: "${hostname}.${domain}"
    - pattern: "${hostname}"
  requiredExtensions: []

revocation:
  checkEnabled: true
  krlUpdateInterval: "1h"
  krlStorageLocation: "blob://ssh-certificates/revocation/krl"
```

---

## 🖥️ Infrastructure Components

### Azure Resources Required

| Resource | SKU/Tier | Purpose | Estimated Cost |
|----------|----------|---------|----------------|
| **Key Vault** | Premium (HSM) | CA key storage | ~$3/key/month + operations |
| **Function App** | Premium EP1 | SSH signing service | ~$150/month |
| **Storage Account** | Standard LRS | Certificate & audit storage | ~$5/month |
| **Event Grid** | Standard | Event routing | ~$1/million operations |
| **Log Analytics** | Pay-as-you-go | Audit logging | Variable |
| **Automation Account** | Basic | Host certificate deployment | ~$0.002/minute |

### Resource Naming Convention

```
{prefix}-{component}-{purpose}-{uniquestring}

Examples:
├── certlc-kv-sshca-prod          # Key Vault for SSH CA
├── certlc-func-sshsign-prod      # SSH Signing Function
├── certlc-st-sshcerts-prod       # Storage for certificates
├── certlc-eg-sshevents-prod      # Event Grid topic
└── certlc-aa-sshdeploy-prod      # Automation Account
```

---

## 📦 Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Provision Key Vault with HSM-backed SSH CA keys
- [ ] Create Azure Function App skeleton
- [ ] Implement basic signing logic using `cryptography` library
- [ ] Set up Managed Identity and RBAC

### Phase 2: User Certificates (Week 3-4)
- [ ] Implement `/api/ssh/user/sign` endpoint
- [ ] Azure AD authentication integration
- [ ] Certificate policy engine
- [ ] Client CLI tool for requesting certificates

### Phase 3: Host Certificates (Week 5-6)
- [ ] Implement `/api/ssh/host/sign` endpoint
- [ ] Event Grid integration for auto-rotation
- [ ] Automation runbook for host deployment
- [ ] CA public key distribution automation

### Phase 4: Operations (Week 7-8)
- [ ] Monitoring dashboards (Azure Monitor/Grafana)
- [ ] Alerting rules
- [ ] Revocation list (KRL) management
- [ ] Documentation and runbooks

### Phase 5: Integration (Week 9-10)
- [ ] Integration with existing certlc monitoring
- [ ] Unified dashboard for all credential types
- [ ] End-to-end testing
- [ ] Security review and hardening

---

## 🔄 Integration with Existing System

### Shared Components

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Existing certLCMgmt Components                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Azure Key Vault (DEMO-KV-{UNIQUESTRING})                               │   │
│  │  ├── certificates/     ← Existing X.509 certificates                    │   │
│  │  ├── keys/             ← NEW: SSH CA keys (ssh-user-ca, ssh-host-ca)   │   │
│  │  └── secrets/          ← NEW: SSH CA public keys for distribution       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Event Grid Topic (DEMO-EG-{UNIQUESTRING})                              │   │
│  │  ├── Microsoft.KeyVault.CertificateNearExpiry  ← Existing               │   │
│  │  ├── Microsoft.KeyVault.KeyNearExpiry          ← NEW: SSH CA rotation   │   │
│  │  └── Custom.SSHCertificate.RotationRequired    ← NEW: Host cert trigger │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Azure Automation Account (DEMO-AA-{UNIQUESTRING})                      │   │
│  │  ├── Enhanced-CertLifeCycleMgmt     ← Existing X.509 runbook            │   │
│  │  ├── Deploy-SSHHostCertificate      ← NEW: Deploy host certs            │   │
│  │  ├── Distribute-SSHCAPublicKey      ← NEW: CA key distribution          │   │
│  │  └── Monitor-SSHCertificates        ← NEW: SSH cert monitoring          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Hybrid Worker Group (EnterpriseRootCA)                                 │   │
│  │  └── worker.ca01  ← Existing, reused for SSH cert deployment            │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Python Project Extension

Extends `linux-python-certlc/src/certificate_lifecycle/`:

```
src/
├── certificate_lifecycle/           # Existing
│   ├── config/
│   ├── models/
│   ├── services/
│   └── ...
│
└── ssh_lifecycle/                   # NEW MODULE
    ├── __init__.py
    ├── config/
    │   └── settings.py              # SSH-specific configuration
    ├── models/
    │   ├── ssh_certificate.py       # SSH certificate data model
    │   ├── ssh_key.py               # SSH key pair model
    │   └── signing_request.py       # Certificate request model
    ├── services/
    │   ├── ssh_ca_service.py        # CA signing operations
    │   ├── key_vault_ssh.py         # Key Vault SSH key operations
    │   └── certificate_store.py     # Blob storage for certs
    ├── api/
    │   ├── app.py                   # Azure Function entry point
    │   ├── user_endpoints.py        # User certificate API
    │   └── host_endpoints.py        # Host certificate API
    ├── policy/
    │   ├── policy_engine.py         # Certificate policy enforcement
    │   └── principal_mapper.py      # Azure AD to SSH principal mapping
    └── deployment/
        ├── host_deployer.py         # Host certificate deployment
        └── ca_distributor.py        # CA public key distribution
```

---

## 📊 Monitoring & Observability

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `ssh_certificates_issued` | Certificates issued per hour | > 1000/hour |
| `ssh_signing_latency_ms` | Time to sign certificate | > 500ms p99 |
| `ssh_signing_errors` | Failed signing attempts | > 5/minute |
| `ssh_ca_key_operations` | Key Vault CA key usage | > 10000/day |
| `ssh_revocations_active` | Active revoked certificates | Informational |
| `ssh_host_certs_expiring` | Host certs expiring in 7 days | > 0 |

### Log Analytics Queries

```kusto
// SSH Certificate Signing Activity
AzureDiagnostics
| where Category == "SSHCertificateSigning"
| summarize 
    Issued = countif(ResultType == "Success"),
    Failed = countif(ResultType == "Failure")
  by bin(TimeGenerated, 1h), CertificateType
| render timechart

// Unusual Principal Requests
SSHCertificateRequests
| where TimeGenerated > ago(24h)
| summarize RequestCount = count() by Principal, RequestorUPN
| where RequestCount > 50
| order by RequestCount desc
```

### Unified Dashboard

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                    Credential Lifecycle Management Dashboard                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐             │
│  │   X.509 Certificates        │    │   SSH Certificates          │             │
│  │   ────────────────────      │    │   ──────────────────        │             │
│  │   Active: 47                │    │   User Certs Today: 234     │             │
│  │   Expiring (30d): 3         │    │   Host Certs Active: 89     │             │
│  │   Renewed Today: 2          │    │   Expiring (7d): 12         │             │
│  │   Failed: 0                 │    │   Revoked: 3                │             │
│  └─────────────────────────────┘    └─────────────────────────────┘             │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │   Certificate Activity (Last 24 Hours)                                     │  │
│  │   [========================================] X.509 Renewals                │  │
│  │   [████████████████                        ] SSH User Certs                │  │
│  │   [██                                      ] SSH Host Certs                │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │   Recent Events                                                            │  │
│  │   10:45 ✅ SSH user cert issued: alice@contoso.com (8h validity)          │  │
│  │   10:42 ✅ X.509 renewed: web-server-prod (365d validity)                 │  │
│  │   10:38 ✅ SSH host cert rotated: server42.internal (30d validity)        │  │
│  │   10:30 ⚠️  SSH signing latency high: 450ms                               │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

1. **Existing certLCMgmt deployment** with Key Vault and Automation Account
2. **Azure AD tenant** for authentication
3. **Python 3.11+** for Function development
4. **Azure CLI** and **Azure Functions Core Tools**

### Quick Start Commands

```bash
# Clone and navigate to project
cd /home/velen/cx/adobe/certLCMgmt

# Create SSH lifecycle module structure
mkdir -p linux-python-certlc/src/ssh_lifecycle/{config,models,services,api,policy,deployment}

# Install additional dependencies
pip install cryptography azure-functions azure-identity azure-keyvault-keys

# Deploy Function App (after implementation)
cd linux-python-certlc
func azure functionapp publish certlc-func-sshsign-prod
```

---

## 📋 Appendix

### A. SSH Certificate Format Reference

```
# User certificate structure
ssh-ed25519-cert-v01@openssh.com AAAAIHNza...
├── Type: ssh-ed25519-cert-v01@openssh.com
├── Nonce: <random 32 bytes>
├── Public Key: <user's public key>
├── Serial: 1234567890
├── Type: 1 (user) or 2 (host)
├── Key ID: "user@example.com-20260122-abc123"
├── Valid Principals: ["username", "admin"]
├── Valid After: 1737540000 (Unix timestamp)
├── Valid Before: 1737576000 (Unix timestamp)
├── Critical Options: {...}
├── Extensions: {...}
└── Signature: <CA signature>
```

### B. Host sshd_config Example

```bash
# /etc/ssh/sshd_config additions for SSH CA

# Host certificate (signed by Host CA)
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub

# Trust user certificates signed by User CA
TrustedUserCAKeys /etc/ssh/trusted_user_ca_keys

# Optional: Authorized principals file per user
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u

# Optional: Revocation list
RevokedKeys /etc/ssh/revoked_keys
```

### C. Client ssh_config Example

```bash
# ~/.ssh/config additions for SSH CA

Host *.internal.contoso.com
    # Use certificate for authentication
    CertificateFile ~/.ssh/id_ed25519-cert.pub
    IdentityFile ~/.ssh/id_ed25519
    
    # Trust host certificates signed by Host CA
    GlobalKnownHostsFile /etc/ssh/ssh_known_hosts
    
    # Verify host certificate
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519
```

---

## 📞 References

- [OpenSSH Certificate Authentication](https://man.openbsd.org/ssh-keygen#CERTIFICATES)
- [Azure Key Vault Keys Documentation](https://learn.microsoft.com/en-us/azure/key-vault/keys/)
- [Azure Functions Python Developer Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Existing certLCMgmt System Overview](../CERTIFICATE_LIFECYCLE_SYSTEM_OVERVIEW.md)

---

*Document Version: 1.0*  
*Created: January 22, 2026*  
*Author: Certificate Lifecycle Management Team*
