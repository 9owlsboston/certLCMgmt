"""
Certificate Manager Service

Core service for managing certificate lifecycle operations including
creation, renewal, monitoring, and storage management.
"""

import asyncio
import json
import logging
from dataclasses import asdict
from datetime import datetime, timedelta
from typing import Any, AsyncGenerator, Dict, List, Optional

from ..config.settings import ConfigurationError, Settings
from ..models.certificate import (Certificate, CertificateInfo,
                                  CertificateRequest, CertificateStatus,
                                  CertificateType, KeyAlgorithm)

# Note: Azure SDK imports would be added in production environment
# from azure.identity import DefaultAzureCredential
# from azure.keyvault.certificates import CertificateClient
# from azure.keyvault.secrets import SecretClient
# from azure.storage.blob.aio import BlobServiceClient


logger = logging.getLogger(__name__)


class CertificateStorageError(Exception):
    """Certificate storage operation errors"""


class CertificateValidationError(Exception):
    """Certificate validation errors"""


class CertificateManager:
    """Main certificate lifecycle management service"""

    def __init__(self, settings: Optional[Settings] = None):
        self.settings = settings or Settings()
        # Note: Azure credential would be initialized in production
        # self.credential = DefaultAzureCredential()

        # Initialize Azure clients (placeholders for development)
        self._key_vault_client: Optional[Any] = None
        self._key_vault_secret_client: Optional[Any] = None
        self._blob_service_client: Optional[Any] = None

        # Certificate cache
        self._certificate_cache: Dict[str, Certificate] = {}
        self._cache_expires_at: Optional[datetime] = None
        self._cache_ttl = timedelta(minutes=15)

    @property
    def key_vault_client(self) -> Any:
        """Get Key Vault certificate client"""
        if self._key_vault_client is None:
            if not self.settings.azure.key_vault_url:
                raise ConfigurationError("Key Vault URL not configured")

            # Note: Would initialize real client in production
            # self._key_vault_client = CertificateClient(
            #     vault_url=self.settings.azure.key_vault_url,
            #     credential=self.credential
            # )
            self._key_vault_client = "mock_key_vault_client"
        return self._key_vault_client

    @property
    def key_vault_secret_client(self) -> Any:
        """Get Key Vault secret client"""
        if self._key_vault_secret_client is None:
            if not self.settings.azure.key_vault_url:
                raise ConfigurationError("Key Vault URL not configured")

            # Note: Would initialize real client in production
            # self._key_vault_secret_client = SecretClient(
            #     vault_url=self.settings.azure.key_vault_url,
            #     credential=self.credential
            # )
            self._key_vault_secret_client = "mock_secret_client"
        return self._key_vault_secret_client

    @property
    async def blob_service_client(self) -> Any:
        """Get Blob Storage client"""
        if self._blob_service_client is None:
            if not self.settings.azure.storage_account_url:
                raise ConfigurationError("Storage account URL not configured")

            # Note: Would initialize real client in production
            # self._blob_service_client = BlobServiceClient(
            #     account_url=self.settings.azure.storage_account_url,
            #     credential=self.credential
            # )
            self._blob_service_client = "mock_blob_client"
        return self._blob_service_client

    async def get_certificate(self, certificate_id: str) -> Optional[Certificate]:
        """Get certificate by ID from storage"""
        try:
            # Try cache first
            if certificate_id in self._certificate_cache:
                if self._cache_expires_at and datetime.utcnow() < self._cache_expires_at:
                    return self._certificate_cache[certificate_id]

            # Try Key Vault first
            cert = await self._get_certificate_from_keyvault(certificate_id)
            if cert:
                self._certificate_cache[certificate_id] = cert
                return cert

            # Try Blob Storage
            cert = await self._get_certificate_from_blob(certificate_id)
            if cert:
                self._certificate_cache[certificate_id] = cert
                return cert

            return None

        except Exception as e:
            logger.error(f"Error retrieving certificate {certificate_id}: {e}")
            raise CertificateStorageError(
                f"Failed to retrieve certificate: {e}") from e

    async def list_certificates(self,
                                filter_status: Optional[CertificateStatus] = None,
                                filter_expiring_days: Optional[int] = None) -> List[Certificate]:
        """List certificates with optional filtering"""
        try:
            certificates = []

            # Get from Key Vault
            kv_certs = await self._list_certificates_from_keyvault()
            certificates.extend(kv_certs)

            # Get from Blob Storage
            blob_certs = await self._list_certificates_from_blob()
            certificates.extend(blob_certs)

            # Remove duplicates based on thumbprint
            unique_certs = {}
            for cert in certificates:
                thumbprint = cert.certificate_info.thumbprint
                if thumbprint not in unique_certs or cert.last_updated > unique_certs[thumbprint].last_updated:
                    unique_certs[thumbprint] = cert

            filtered_certs = list(unique_certs.values())

            # Apply filters
            if filter_status:
                filtered_certs = [
                    c for c in filtered_certs if c.status == filter_status]

            if filter_expiring_days is not None:
                filtered_certs = [
                    c for c in filtered_certs
                    if c.certificate_info.days_until_expiry <= filter_expiring_days
                ]

            return filtered_certs

        except Exception as e:
            logger.error(f"Error listing certificates: {e}")
            raise CertificateStorageError(
                f"Failed to list certificates: {e}") from e

    async def create_certificate(self, request: CertificateRequest) -> Certificate:
        """Create a new certificate from request"""
        try:
            # Validate request
            validation_errors = request.validate()
            if validation_errors:
                raise CertificateValidationError(
                    f"Invalid request: {'; '.join(validation_errors)}")

            # Create new certificate object
            certificate = Certificate(
                certificate_info=CertificateInfo(
                    thumbprint="",  # Will be set after generation
                    serial_number="",
                    subject=request.subject,
                    issuer=request.subject,  # Placeholder
                    not_before=datetime.utcnow(),
                    not_after=datetime.utcnow() + timedelta(days=request.validity_days),
                    key_algorithm=request.key_algorithm,
                    key_size=self._get_key_size_from_algorithm(
                        request.key_algorithm),
                    signature_algorithm="sha256WithRSAEncryption"
                ),
                status=CertificateStatus.PENDING,
                certificate_type=request.certificate_type,
                ca_provider=request.ca_provider or self.settings.ca.provider,
                ca_template=request.ca_template,
                key_vault_name=request.key_vault_name,
                key_vault_certificate_name=request.key_vault_certificate_name,
                tags=request.tags.copy()
            )

            # Add creation record
            certificate.add_renewal_record(
                action="create_request",
                result="initiated",
                details={
                    "requestor": request.requestor,
                    "business_justification": request.business_justification,
                    "validity_days": request.validity_days
                }
            )

            logger.info(
                f"Created certificate request for {request.subject.common_name}")
            return certificate

        except Exception as e:
            logger.error(f"Error creating certificate: {e}")
            raise CertificateValidationError(
                f"Failed to create certificate: {e}") from e

    async def store_certificate(self, certificate: Certificate) -> bool:
        """Store certificate in configured storage"""
        try:
            # Store in Key Vault if configured
            if certificate.key_vault_name and certificate.key_vault_certificate_name:
                await self._store_certificate_in_keyvault(certificate)

            # Store in Blob Storage as backup/archive
            await self._store_certificate_in_blob(certificate)

            # Update cache
            self._certificate_cache[certificate.unique_id] = certificate
            self._cache_expires_at = datetime.utcnow() + self._cache_ttl

            logger.info(f"Stored certificate {certificate.display_name}")
            return True

        except Exception as e:
            logger.error(
                f"Error storing certificate {certificate.display_name}: {e}")
            raise CertificateStorageError(
                f"Failed to store certificate: {e}") from e

    async def update_certificate_status(self,
                                        certificate_id: str,
                                        new_status: CertificateStatus,
                                        reason: Optional[str] = None) -> bool:
        """Update certificate status"""
        try:
            certificate = await self.get_certificate(certificate_id)
            if not certificate:
                raise CertificateStorageError(
                    f"Certificate {certificate_id} not found")

            old_status = certificate.status
            certificate.update_status(new_status, reason)

            # Store updated certificate
            await self.store_certificate(certificate)

            logger.info(
                f"Updated certificate {certificate.display_name} status: {old_status} -> {new_status}")
            return True

        except Exception as e:
            logger.error(f"Error updating certificate status: {e}")
            raise CertificateStorageError(
                f"Failed to update status: {e}") from e

    async def get_expiring_certificates(self, days_threshold: int = 30) -> List[Certificate]:
        """Get certificates expiring within threshold"""
        return await self.list_certificates(filter_expiring_days=days_threshold)

    async def get_certificates_by_status(self, status: CertificateStatus) -> List[Certificate]:
        """Get certificates by status"""
        return await self.list_certificates(filter_status=status)

    async def monitor_certificate_health(self) -> Dict[str, Any]:
        """Monitor overall certificate health and return metrics"""
        try:
            all_certificates = await self.list_certificates()

            # Calculate metrics
            total_count = len(all_certificates)
            status_counts = {}
            expiring_counts = {7: 0, 14: 0, 30: 0, 90: 0}

            for cert in all_certificates:
                # Count by status
                status = cert.status.value
                status_counts[status] = status_counts.get(status, 0) + 1

                # Count expiring certificates
                days_until_expiry = cert.certificate_info.days_until_expiry
                for threshold in expiring_counts:
                    if days_until_expiry <= threshold:
                        expiring_counts[threshold] += 1

            health_metrics = {
                "timestamp": datetime.utcnow().isoformat(),
                "total_certificates": total_count,
                "status_breakdown": status_counts,
                "expiring_certificates": expiring_counts,
                "health_score": self._calculate_health_score(all_certificates)
            }

            logger.info(
                f"Certificate health check completed: {total_count} certificates monitored")
            return health_metrics

        except Exception as e:
            logger.error(f"Error monitoring certificate health: {e}")
            raise CertificateStorageError(
                f"Failed to monitor health: {e}") from e

    def _get_key_size_from_algorithm(self, algorithm: KeyAlgorithm) -> int:
        """Get key size from algorithm enum"""
        if algorithm.value.startswith("RSA-"):
            return int(algorithm.value.split("-")[1])
        elif algorithm == KeyAlgorithm.ECDSA_P256:
            return 256
        elif algorithm == KeyAlgorithm.ECDSA_P384:
            return 384
        return 2048  # Default

    def _calculate_health_score(self, certificates: List[Certificate]) -> float:
        """Calculate overall health score (0-100)"""
        if not certificates:
            return 100.0

        total = len(certificates)
        healthy = 0

        for cert in certificates:
            # Consider certificate healthy if:
            # - Status is ACTIVE
            # - Not expiring within 30 days
            # - Not expired
            if (cert.status == CertificateStatus.ACTIVE and
                cert.certificate_info.days_until_expiry > 30 and
                    not cert.certificate_info.is_expired):
                healthy += 1

        return round((healthy / total) * 100, 2)

    async def _get_certificate_from_keyvault(self, certificate_id: str) -> Optional[Certificate]:
        """Get certificate from Key Vault"""
        try:
            # Implementation would query Key Vault
            # For now, return None as placeholder
            return None
        except Exception as e:
            logger.warning(f"Failed to get certificate from Key Vault: {e}")
            return None

    async def _get_certificate_from_blob(self, certificate_id: str) -> Optional[Certificate]:
        """Get certificate from Blob Storage"""
        try:
            blob_client = await self.blob_service_client
            # Implementation would query blob storage
            # For now, return None as placeholder
            return None
        except Exception as e:
            logger.warning(f"Failed to get certificate from Blob Storage: {e}")
            return None

    async def _list_certificates_from_keyvault(self) -> List[Certificate]:
        """List certificates from Key Vault"""
        try:
            # Implementation would list from Key Vault
            return []
        except Exception as e:
            logger.warning(f"Failed to list certificates from Key Vault: {e}")
            return []

    async def _list_certificates_from_blob(self) -> List[Certificate]:
        """List certificates from Blob Storage"""
        try:
            # Implementation would list from blob storage
            return []
        except Exception as e:
            logger.warning(
                f"Failed to list certificates from Blob Storage: {e}")
            return []

    async def _store_certificate_in_keyvault(self, certificate: Certificate) -> bool:
        """Store certificate in Key Vault"""
        try:
            # Implementation would store in Key Vault
            logger.debug(
                f"Would store certificate {certificate.display_name} in Key Vault")
            return True
        except Exception as e:
            logger.error(f"Failed to store certificate in Key Vault: {e}")
            raise CertificateStorageError(
                f"Key Vault storage failed: {e}") from e

    async def _store_certificate_in_blob(self, certificate: Certificate) -> bool:
        """Store certificate metadata in Blob Storage"""
        try:
            # Implementation would store in blob storage
            logger.debug(
                f"Would store certificate {certificate.display_name} in Blob Storage")
            return True
        except Exception as e:
            logger.error(f"Failed to store certificate in Blob Storage: {e}")
            raise CertificateStorageError(f"Blob storage failed: {e}") from e

    async def cleanup_cache(self):
        """Clean up expired cache entries"""
        if self._cache_expires_at and datetime.utcnow() > self._cache_expires_at:
            self._certificate_cache.clear()
            self._cache_expires_at = None
            logger.debug("Certificate cache cleared")

    async def close(self):
        """Close all clients and cleanup resources"""
        if self._blob_service_client:
            await self._blob_service_client.close()

        self._certificate_cache.clear()
        logger.debug("Certificate manager closed")
