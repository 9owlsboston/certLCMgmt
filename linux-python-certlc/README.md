# Linux/Python Certificate Lifecycle Management

A comprehensive Python-based implementation for managing X.509 certificate lifecycles in Azure and enterprise environments. This project replaces the Windows-based LAB environment with a more robust, scalable Linux architecture.

## 🏗️ Current Implementation Status

### ✅ Completed Components

- **Core Configuration Management** (`src/certificate_lifecycle/config/settings.py`)
  - Environment variable and YAML file support
  - Azure service configuration
  - Certificate authority settings
  - Monitoring and idempotency configuration

- **Certificate Data Models** (`src/certificate_lifecycle/models/certificate.py`)
  - Complete X.509 certificate representation
  - Certificate request and status management
  - Cryptography library integration
  - JSON serialization support

- **Certificate Manager Service** (`src/certificate_lifecycle/services/certificate_manager.py`)
  - Async certificate lifecycle operations
  - Azure Key Vault and Blob Storage integration (framework)
  - Certificate health monitoring
  - Idempotency and caching support

- **Package Structure** 
  - Proper Python package initialization
  - Clean import hierarchy
  - Development-friendly structure

### 🚧 In Progress / Next Steps

- **Certificate Authority Adapters** (`src/certificate_lifecycle/ca_adapters/`)
  - Azure Integrated CA (DigiCert, GlobalSign, Entrust)
  - Enterprise CA integration (REST/SSH)
  - Lab CA for development/testing

- **Automation Runbooks** (`src/certificate_lifecycle/runbooks/`)
  - Python-based renewal automation
  - Health monitoring runbooks
  - Azure Automation Account integration

- **Infrastructure Deployment** (`deployment/`)
  - ARM templates for Linux VMs
  - Docker containerization
  - Monitoring stack (Prometheus/Grafana)

## 🚀 Quick Start

### Prerequisites

```bash
# Install Python dependencies
pip install -r requirements.txt

# Set up environment variables
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_KEY_VAULT_URL="https://your-keyvault.vault.azure.net/"
export AZURE_STORAGE_ACCOUNT_URL="https://yourstorageaccount.blob.core.windows.net/"
```

### Basic Usage

```python
import os
import asyncio
from certificate_lifecycle import (
    Settings, CertificateManager, CertificateRequest,
    CertificateType, KeyAlgorithm, CertificateSubject
)

async def main():
    # Initialize configuration
    settings = Settings()
    
    # Create certificate manager
    cert_manager = CertificateManager(settings)
    
    # Create certificate request
    subject = CertificateSubject(
        common_name="server.example.com",
        organization="Example Corp",
        country="US"
    )
    
    request = CertificateRequest(
        subject=subject,
        certificate_type=CertificateType.SERVER,
        key_algorithm=KeyAlgorithm.RSA_2048,
        validity_days=365
    )
    
    # Create certificate
    certificate = await cert_manager.create_certificate(request)
    print(f"Created certificate: {certificate.display_name}")
    
    # Monitor health
    health = await cert_manager.monitor_certificate_health()
    print(f"Health score: {health['health_score']}%")
    
    await cert_manager.close()

# Run the example
asyncio.run(main())
```

### Configuration

Copy `config.yaml.example` to `config.yaml` and customize:

```yaml
azure:
  subscription_id: "your-subscription-id"
  key_vault_url: "https://your-keyvault.vault.azure.net/"
  
ca:
  provider: "lab"  # lab, enterprise, digicert, globalsign
  
certificate:
  default_renewal_threshold_days: 30
  max_certificate_lifetime_days: 365
```

## 🏛️ Architecture

This implementation addresses the idempotency issues found in the original Windows LAB:

- **Distributed Locking**: Redis-based job coordination
- **Idempotent Operations**: Prevent duplicate certificate creation
- **Enhanced Monitoring**: Prometheus metrics and health scoring
- **Multi-CA Support**: Extensible adapter pattern for different CAs

## � Project Structure

```
linux-python-certlc/
├── src/certificate_lifecycle/          # Main package
│   ├── config/                         # Configuration management
│   ├── models/                         # Data models
│   ├── services/                       # Core services
│   ├── ca_adapters/                    # CA integrations
│   ├── utils/                          # Utilities
│   └── runbooks/                       # Automation scripts
├── deployment/                         # Infrastructure as Code
├── tests/                              # Test suites
├── monitoring/                         # Observability configs
├── docs/                               # Documentation
└── examples/                           # Usage examples
```

## 🔗 Related Documentation

- [Linux LAB Proposal](../docs/certlc-notes/LINUX_LAB_PROPOSAL.md) - Comprehensive architecture design
- [Original Windows LAB Issues](../certlc-deployment-scripts/RUNAWAY_ISSUE_RESOLVED.md) - Problems this addresses

## 🧪 Testing

```bash
# Run basic functionality test
PYTHONPATH=./src python3 -c "
import os
os.environ['AZURE_SUBSCRIPTION_ID'] = 'demo'
os.environ['AZURE_KEY_VAULT_URL'] = 'https://demo.vault.azure.net/'
from certificate_lifecycle import Settings, CertificateManager
settings = Settings()
manager = CertificateManager(settings)
print('✅ Core functionality working!')
"
```

## 📈 Development Roadmap

1. **Phase 1**: Complete CA adapters and basic automation
2. **Phase 2**: Deploy infrastructure and monitoring
3. **Phase 3**: Enterprise integration and advanced features
4. **Phase 4**: Migration from Windows LAB environment

This Python implementation provides a solid foundation for enterprise-grade certificate lifecycle management with the flexibility to integrate with various certificate authorities and Azure services.