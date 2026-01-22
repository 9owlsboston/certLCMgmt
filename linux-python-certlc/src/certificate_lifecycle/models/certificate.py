"""
Certificate models and data structures for Certificate Lifecycle Management

This module defines the core data models for managing X.509 certificates
throughout their lifecycle in various Certificate Authority environments.
"""

import base64
import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Any, Dict, List, Optional, Union

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, rsa


class CertificateStatus(Enum):
    """Certificate status enumeration"""
    ACTIVE = "active"
    PENDING = "pending"
    EXPIRED = "expired"
    REVOKED = "revoked"
    RENEWAL_REQUIRED = "renewal_required"
    ERROR = "error"


class CertificateType(Enum):
    """Certificate type enumeration"""
    SERVER = "server"
    CLIENT = "client"
    CODE_SIGNING = "code_signing"
    EMAIL = "email"
    ROOT_CA = "root_ca"
    INTERMEDIATE_CA = "intermediate_ca"


class KeyAlgorithm(Enum):
    """Supported key algorithms"""
    RSA_2048 = "RSA-2048"
    RSA_3072 = "RSA-3072"
    RSA_4096 = "RSA-4096"
    ECDSA_P256 = "ECDSA-P256"
    ECDSA_P384 = "ECDSA-P384"


@dataclass
class CertificateSubject:
    """X.509 certificate subject information"""
    common_name: str
    organization: Optional[str] = None
    organizational_unit: Optional[str] = None
    locality: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    email: Optional[str] = None

    def to_x509_name(self) -> x509.Name:
        """Convert to cryptography X.509 Name object"""
        name_attributes = []

        if self.country:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.COUNTRY_NAME, self.country))
        if self.state:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.STATE_OR_PROVINCE_NAME, self.state))
        if self.locality:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.LOCALITY_NAME, self.locality))
        if self.organization:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.ORGANIZATION_NAME, self.organization))
        if self.organizational_unit:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.ORGANIZATIONAL_UNIT_NAME, self.organizational_unit))
        if self.common_name:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.COMMON_NAME, self.common_name))
        if self.email:
            name_attributes.append(x509.NameAttribute(
                x509.NameOID.EMAIL_ADDRESS, self.email))

        return x509.Name(name_attributes)

    @classmethod
    def from_x509_name(cls, name: x509.Name) -> 'CertificateSubject':
        """Create from cryptography X.509 Name object"""
        attrs = {}
        for attribute in name:
            oid = attribute.oid
            value = attribute.value

            if oid == x509.NameOID.COMMON_NAME:
                attrs['common_name'] = value
            elif oid == x509.NameOID.ORGANIZATION_NAME:
                attrs['organization'] = value
            elif oid == x509.NameOID.ORGANIZATIONAL_UNIT_NAME:
                attrs['organizational_unit'] = value
            elif oid == x509.NameOID.LOCALITY_NAME:
                attrs['locality'] = value
            elif oid == x509.NameOID.STATE_OR_PROVINCE_NAME:
                attrs['state'] = value
            elif oid == x509.NameOID.COUNTRY_NAME:
                attrs['country'] = value
            elif oid == x509.NameOID.EMAIL_ADDRESS:
                attrs['email'] = value

        return cls(**attrs)


@dataclass
class CertificateExtensions:
    """X.509 certificate extensions"""
    subject_alternative_names: List[str] = field(default_factory=list)
    key_usage: List[str] = field(default_factory=list)
    extended_key_usage: List[str] = field(default_factory=list)
    basic_constraints_ca: bool = False
    basic_constraints_path_length: Optional[int] = None
    authority_key_identifier: Optional[str] = None
    subject_key_identifier: Optional[str] = None
    crl_distribution_points: List[str] = field(default_factory=list)
    authority_info_access: Dict[str, str] = field(default_factory=dict)


@dataclass
class CertificateInfo:
    """Core certificate information"""
    thumbprint: str
    serial_number: str
    subject: CertificateSubject
    issuer: CertificateSubject
    not_before: datetime
    not_after: datetime
    key_algorithm: KeyAlgorithm
    key_size: int
    signature_algorithm: str
    extensions: CertificateExtensions = field(
        default_factory=CertificateExtensions)

    @property
    def is_expired(self) -> bool:
        """Check if certificate is expired"""
        return datetime.utcnow() > self.not_after

    @property
    def is_valid(self) -> bool:
        """Check if certificate is currently valid"""
        now = datetime.utcnow()
        return self.not_before <= now <= self.not_after

    @property
    def days_until_expiry(self) -> int:
        """Calculate days until certificate expires"""
        delta = self.not_after - datetime.utcnow()
        return max(0, delta.days)

    @property
    def validity_period_days(self) -> int:
        """Get total validity period in days"""
        delta = self.not_after - self.not_before
        return delta.days

    def needs_renewal(self, threshold_days: int = 30) -> bool:
        """Check if certificate needs renewal based on threshold"""
        return self.days_until_expiry <= threshold_days

    @classmethod
    def from_x509_certificate(cls, cert: x509.Certificate) -> 'CertificateInfo':
        """Create CertificateInfo from cryptography X.509 certificate"""
        # Extract basic information
        subject = CertificateSubject.from_x509_name(cert.subject)
        issuer = CertificateSubject.from_x509_name(cert.issuer)

        # Calculate thumbprint (SHA-1 fingerprint)
        thumbprint = cert.fingerprint(hashes.SHA1()).hex().upper()

        # Extract key information
        public_key = cert.public_key()
        key_size = 0
        key_algorithm = KeyAlgorithm.RSA_2048  # Default fallback

        if isinstance(public_key, rsa.RSAPublicKey):
            key_size = public_key.key_size
            key_algorithm = KeyAlgorithm(f"RSA-{key_size}")
        elif isinstance(public_key, ec.EllipticCurvePublicKey):
            key_size = public_key.curve.key_size
            if key_size == 256:
                key_algorithm = KeyAlgorithm.ECDSA_P256
            elif key_size == 384:
                key_algorithm = KeyAlgorithm.ECDSA_P384
        else:
            key_size = 2048  # Default for unknown types

        # Extract extensions (simplified to avoid complex type handling)
        extensions = CertificateExtensions()
        try:
            # Try to get SAN extension but handle gracefully if it fails
            san_ext = cert.extensions.get_extension_for_oid(
                x509.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
            # For now, just indicate that SAN is present
            extensions.subject_alternative_names = [
                "<SAN present - see certificate>"]
        except (x509.ExtensionNotFound, AttributeError):
            pass

        return cls(
            thumbprint=thumbprint,
            serial_number=str(cert.serial_number),
            subject=subject,
            issuer=issuer,
            not_before=cert.not_valid_before,
            not_after=cert.not_valid_after,
            key_algorithm=key_algorithm,
            key_size=key_size,
            signature_algorithm=cert.signature_algorithm_oid.dotted_string,
            extensions=extensions
        )


@dataclass
class Certificate:
    """Complete certificate object with metadata"""
    certificate_info: CertificateInfo
    status: CertificateStatus
    certificate_type: CertificateType

    # Storage and management metadata
    key_vault_name: Optional[str] = None
    key_vault_certificate_name: Optional[str] = None
    storage_account_name: Optional[str] = None
    storage_container_name: Optional[str] = None
    storage_blob_name: Optional[str] = None

    # CA-specific information
    ca_provider: Optional[str] = None
    ca_template: Optional[str] = None
    ca_order_id: Optional[str] = None
    ca_certificate_id: Optional[str] = None

    # Lifecycle tracking
    created_date: datetime = field(default_factory=datetime.utcnow)
    last_updated: datetime = field(default_factory=datetime.utcnow)
    renewal_history: List[Dict[str, Any]] = field(default_factory=list)
    tags: Dict[str, str] = field(default_factory=dict)

    # Certificate data (base64 encoded)
    certificate_pem: Optional[str] = None
    private_key_pem: Optional[str] = None  # Encrypted
    certificate_chain_pem: Optional[str] = None

    @property
    def unique_id(self) -> str:
        """Generate unique identifier for the certificate"""
        return f"{self.certificate_info.thumbprint}_{self.created_date.isoformat()}"

    @property
    def display_name(self) -> str:
        """Generate human-readable display name"""
        return f"{self.certificate_info.subject.common_name} ({self.certificate_info.thumbprint[:8]})"

    def update_status(self, new_status: CertificateStatus, reason: Optional[str] = None):
        """Update certificate status with timestamp"""
        old_status = self.status
        self.status = new_status
        self.last_updated = datetime.utcnow()

        # Add to renewal history
        status_change = {
            'timestamp': self.last_updated.isoformat(),
            'old_status': old_status.value,
            'new_status': new_status.value,
            'reason': reason
        }
        self.renewal_history.append(status_change)

    def add_renewal_record(self, action: str, result: str, details: Optional[Dict[str, Any]] = None):
        """Add renewal action to history"""
        renewal_record = {
            'timestamp': datetime.utcnow().isoformat(),
            'action': action,
            'result': result,
            'details': details or {}
        }
        self.renewal_history.append(renewal_record)

    def set_certificate_data(self, cert_pem: str, private_key_pem: Optional[str] = None,
                             chain_pem: Optional[str] = None):
        """Set certificate data and update info from PEM"""
        self.certificate_pem = cert_pem
        self.private_key_pem = private_key_pem
        self.certificate_chain_pem = chain_pem

        # Update certificate info from PEM data
        try:
            cert_bytes = cert_pem.encode('utf-8')
            cert = x509.load_pem_x509_certificate(cert_bytes)
            self.certificate_info = CertificateInfo.from_x509_certificate(cert)
        except Exception as e:
            raise ValueError(f"Invalid certificate PEM data: {e}") from e

    def to_dict(self) -> Dict[str, Any]:
        """Convert certificate to dictionary for serialization"""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Certificate':
        """Create certificate from dictionary"""
        # Handle nested objects
        if 'certificate_info' in data:
            cert_info_data = data['certificate_info']

            # Reconstruct subject and issuer
            if 'subject' in cert_info_data:
                cert_info_data['subject'] = CertificateSubject(
                    **cert_info_data['subject'])
            if 'issuer' in cert_info_data:
                cert_info_data['issuer'] = CertificateSubject(
                    **cert_info_data['issuer'])
            if 'extensions' in cert_info_data:
                cert_info_data['extensions'] = CertificateExtensions(
                    **cert_info_data['extensions'])

            # Convert enum strings back to enums
            if 'key_algorithm' in cert_info_data:
                cert_info_data['key_algorithm'] = KeyAlgorithm(
                    cert_info_data['key_algorithm'])

            # Convert datetime strings back to datetime objects
            for date_field in ['not_before', 'not_after']:
                if date_field in cert_info_data and isinstance(cert_info_data[date_field], str):
                    cert_info_data[date_field] = datetime.fromisoformat(
                        cert_info_data[date_field])

            data['certificate_info'] = CertificateInfo(**cert_info_data)

        # Convert enum strings back to enums
        if 'status' in data:
            data['status'] = CertificateStatus(data['status'])
        if 'certificate_type' in data:
            data['certificate_type'] = CertificateType(
                data['certificate_type'])

        # Convert datetime strings back to datetime objects
        for date_field in ['created_date', 'last_updated']:
            if date_field in data and isinstance(data[date_field], str):
                data[date_field] = datetime.fromisoformat(data[date_field])

        return cls(**data)

    def to_json(self) -> str:
        """Convert certificate to JSON string"""
        data = self.to_dict()

        # Convert datetime objects to ISO format strings
        def convert_datetime(obj):
            if isinstance(obj, datetime):
                return obj.isoformat()
            elif isinstance(obj, dict):
                return {k: convert_datetime(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_datetime(item) for item in obj]
            return obj

        return json.dumps(convert_datetime(data), indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> 'Certificate':
        """Create certificate from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)


@dataclass
class CertificateRequest:
    """Certificate signing request information"""
    subject: CertificateSubject
    certificate_type: CertificateType
    key_algorithm: KeyAlgorithm
    validity_days: int = 365

    # Optional fields
    subject_alternative_names: List[str] = field(default_factory=list)
    key_usage: List[str] = field(default_factory=list)
    extended_key_usage: List[str] = field(default_factory=list)

    # CA-specific fields
    ca_provider: Optional[str] = None
    ca_template: Optional[str] = None

    # Storage configuration
    key_vault_name: Optional[str] = None
    key_vault_certificate_name: Optional[str] = None

    # Request metadata
    requestor: Optional[str] = None
    business_justification: Optional[str] = None
    tags: Dict[str, str] = field(default_factory=dict)

    def validate(self) -> List[str]:
        """Validate certificate request and return list of errors"""
        errors = []

        if not self.subject.common_name:
            errors.append("Common name is required")

        if self.validity_days < 1:
            errors.append("Validity period must be at least 1 day")

        if self.validity_days > 1095:  # 3 years max
            errors.append("Validity period cannot exceed 3 years (1095 days)")

        # Validate key algorithm and size
        if self.key_algorithm == KeyAlgorithm.RSA_2048 and not self._validate_rsa_min_size(2048):
            errors.append("RSA key size must be at least 2048 bits")

        return errors

    def _validate_rsa_min_size(self, min_size: int) -> bool:
        """Validate RSA key size meets minimum requirements"""
        if self.key_algorithm.value.startswith("RSA-"):
            key_size = int(self.key_algorithm.value.split("-")[1])
            return key_size >= min_size
        return True  # Non-RSA keys

    def to_dict(self) -> Dict[str, Any]:
        """Convert request to dictionary"""
        return asdict(self)
