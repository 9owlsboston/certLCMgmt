"""
Configuration management for Certificate Lifecycle Management

This module provides centralized configuration management using environment variables,
YAML files, and Azure Key Vault for sensitive settings.
"""

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional

import yaml


@dataclass
class AzureConfig:
    """Azure-specific configuration"""
    subscription_id: str = ""
    tenant_id: str = ""
    key_vault_url: str = ""
    storage_account_url: str = ""
    automation_account_name: str = ""
    resource_group: str = ""
    location: str = "eastus"


@dataclass
class CAConfig:
    """Certificate Authority configuration"""
    provider: str = "lab"  # lab, enterprise, digicert, globalsign
    endpoint: str = ""
    auth_method: str = "api_key"  # api_key, certificate, ssh_key
    auth_credentials: Dict[str, Any] = field(default_factory=dict)
    templates: Dict[str, str] = field(default_factory=dict)
    timeout: int = 300
    retry_count: int = 3


@dataclass
class MonitoringConfig:
    """Monitoring and observability configuration"""
    prometheus_enabled: bool = True
    prometheus_port: int = 8000
    grafana_enabled: bool = True
    grafana_port: int = 3000
    log_level: str = "INFO"
    log_format: str = "json"
    metrics_prefix: str = "certlc"


@dataclass
class IdempotencyConfig:
    """Idempotency and locking configuration"""
    redis_url: str = "redis://localhost:6379"
    lock_timeout: int = 1800  # 30 minutes
    operation_window_hours: int = 2
    enable_distributed_locking: bool = True


@dataclass
class CertificateConfig:
    """Certificate lifecycle configuration"""
    default_renewal_threshold_days: int = 30
    compliance_transition_year: int = 2029
    max_certificate_lifetime_days: int = 365
    min_key_size: int = 2048
    supported_algorithms: list = field(
        default_factory=lambda: ["RSA", "ECDSA"])


class Settings:
    """Main configuration class for Certificate Lifecycle Management"""

    def __init__(self, config_file: Optional[str] = None):
        self.config_file = config_file or os.getenv(
            "CERTLC_CONFIG_FILE", "config.yaml")

        # Initialize configuration sections
        self.azure = AzureConfig()
        self.ca = CAConfig()
        self.monitoring = MonitoringConfig()
        self.idempotency = IdempotencyConfig()
        self.certificate = CertificateConfig()

        # Load configuration
        self._load_from_environment()
        self._load_from_file()
        self._validate_configuration()

    def _load_from_environment(self):
        """Load configuration from environment variables"""

        # Azure configuration
        self.azure.subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID", "")
        self.azure.tenant_id = os.getenv("AZURE_TENANT_ID", "")
        self.azure.key_vault_url = os.getenv("AZURE_KEY_VAULT_URL", "")
        self.azure.storage_account_url = os.getenv(
            "AZURE_STORAGE_ACCOUNT_URL", "")
        self.azure.automation_account_name = os.getenv(
            "AZURE_AUTOMATION_ACCOUNT_NAME", "")
        self.azure.resource_group = os.getenv("AZURE_RESOURCE_GROUP", "")
        self.azure.location = os.getenv("AZURE_LOCATION", "eastus")

        # CA configuration
        self.ca.provider = os.getenv("CA_PROVIDER", "lab")
        self.ca.endpoint = os.getenv("CA_ENDPOINT", "")
        self.ca.auth_method = os.getenv("CA_AUTH_METHOD", "api_key")

        # Monitoring configuration
        self.monitoring.log_level = os.getenv("LOG_LEVEL", "INFO")
        self.monitoring.prometheus_port = int(
            os.getenv("PROMETHEUS_PORT", "8000"))
        self.monitoring.grafana_port = int(os.getenv("GRAFANA_PORT", "3000"))

        # Idempotency configuration
        self.idempotency.redis_url = os.getenv(
            "REDIS_URL", "redis://localhost:6379")
        self.idempotency.lock_timeout = int(os.getenv("LOCK_TIMEOUT", "1800"))

        # Certificate configuration
        self.certificate.default_renewal_threshold_days = int(
            os.getenv("CERT_RENEWAL_THRESHOLD_DAYS", "30")
        )

    def _load_from_file(self):
        """Load configuration from YAML file"""
        config_path = Path(self.config_file)

        if not config_path.exists():
            return  # Use environment/default values

        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config_data = yaml.safe_load(f)

            if config_data is None:
                return

            # Update configurations from file
            if isinstance(config_data, dict) and 'azure' in config_data:
                azure_config = config_data.get('azure', {})
                if isinstance(azure_config, dict):
                    for key, value in azure_config.items():
                        if hasattr(self.azure, key):
                            setattr(self.azure, key, value)

            if isinstance(config_data, dict) and 'ca' in config_data:
                ca_config = config_data.get('ca', {})
                if isinstance(ca_config, dict):
                    for key, value in ca_config.items():
                        if hasattr(self.ca, key):
                            setattr(self.ca, key, value)

            # Similar for other sections...

        except Exception as e:
            raise ConfigurationError(
                f"Failed to load configuration file {config_path}: {e}") from e

    def _validate_configuration(self):
        """Validate configuration completeness and correctness"""
        errors = []

        # Validate Azure configuration
        if not self.azure.subscription_id:
            errors.append("Azure subscription ID is required")

        if not self.azure.key_vault_url:
            errors.append("Azure Key Vault URL is required")

        # Validate CA configuration
        if self.ca.provider not in ['lab', 'enterprise', 'digicert', 'globalsign', 'entrust']:
            errors.append(f"Invalid CA provider: {self.ca.provider}")

        # Validate certificate configuration
        if self.certificate.default_renewal_threshold_days < 1:
            errors.append(
                "Certificate renewal threshold must be at least 1 day")

        if errors:
            raise ConfigurationError(
                f"Configuration validation failed: {'; '.join(errors)}")

    def get_ca_config(self, ca_provider: Optional[str] = None) -> CAConfig:  # pylint: disable=unused-argument
        """Get CA configuration for specific provider"""
        # Return provider-specific configuration
        # This could be expanded to support multiple CA configurations
        return self.ca

    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary"""
        return {
            'azure': self.azure.__dict__,
            'ca': self.ca.__dict__,
            'monitoring': self.monitoring.__dict__,
            'idempotency': self.idempotency.__dict__,
            'certificate': self.certificate.__dict__
        }


class ConfigurationError(Exception):
    """Configuration-related errors"""


# Global settings instance
settings = Settings()
