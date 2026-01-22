"""
Certificate Lifecycle Management Package

A comprehensive Python package for managing X.509 certificate lifecycles
in Azure and enterprise environments.
"""

__version__ = "0.1.0"
__author__ = "Certificate Lifecycle Management Team"
__description__ = "Linux/Python-based X.509 certificate lifecycle management for Azure"

# Core imports
from .config.settings import ConfigurationError, Settings
from .models.certificate import (Certificate, CertificateExtensions,
                                 CertificateInfo, CertificateRequest,
                                 CertificateStatus, CertificateSubject,
                                 CertificateType, KeyAlgorithm)
from .services.certificate_manager import (CertificateManager,
                                           CertificateStorageError,
                                           CertificateValidationError)

# Package-level exports
__all__ = [
    # Configuration
    "Settings",
    "ConfigurationError",

    # Models
    "Certificate",
    "CertificateInfo",
    "CertificateRequest",
    "CertificateStatus",
    "CertificateType",
    "KeyAlgorithm",
    "CertificateSubject",
    "CertificateExtensions",

    # Services
    "CertificateManager",
    "CertificateStorageError",
    "CertificateValidationError",
]
