#!/usr/bin/env python3
"""
Certificate Lifecycle Management Demo

This script demonstrates basic usage of the Certificate Lifecycle Management package.
Run this after configuring your environment variables or config.yaml file.
"""

import asyncio
import os
import sys
from pathlib import Path

from certificate_lifecycle import (Certificate, CertificateManager,
                                   CertificateRequest, CertificateStatus,
                                   CertificateSubject, CertificateType,
                                   KeyAlgorithm, Settings)

# Add the src directory to Python path for development
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root / "src"))

# Import our package


async def demo_basic_usage():
    """Demonstrate basic certificate lifecycle operations"""
    print("🔐 Certificate Lifecycle Management Demo")
    print("=" * 50)

    try:
        # Initialize with minimal configuration for demo
        os.environ.setdefault("AZURE_SUBSCRIPTION_ID", "demo-subscription")
        os.environ.setdefault("AZURE_KEY_VAULT_URL",
                              "https://demo-vault.vault.azure.net/")

        settings = Settings()
        print(f"✅ Configuration loaded successfully")
        print(f"   - CA Provider: {settings.ca.provider}")
        print(f"   - Key Vault URL: {settings.azure.key_vault_url}")

        # Initialize certificate manager
        cert_manager = CertificateManager(settings)
        print(f"✅ Certificate Manager initialized")

        # Create a sample certificate request
        subject = CertificateSubject(
            common_name="demo.example.com",
            organization="Demo Organization",
            organizational_unit="IT Department",
            locality="Seattle",
            state="Washington",
            country="US"
        )

        cert_request = CertificateRequest(
            subject=subject,
            certificate_type=CertificateType.SERVER,
            key_algorithm=KeyAlgorithm.RSA_2048,
            validity_days=365,
            subject_alternative_names=[
                "www.demo.example.com", "api.demo.example.com"],
            ca_provider="lab",
            requestor="demo-user@example.com",
            business_justification="Development testing environment"
        )

        # Validate the request
        validation_errors = cert_request.validate()
        if validation_errors:
            print(f"❌ Certificate request validation failed:")
            for error in validation_errors:
                print(f"   - {error}")
            return

        print(f"✅ Certificate request created and validated")
        print(f"   - Subject: {subject.common_name}")
        print(f"   - Type: {cert_request.certificate_type.value}")
        print(f"   - Key Algorithm: {cert_request.key_algorithm.value}")
        print(f"   - Validity: {cert_request.validity_days} days")

        # Create certificate object (simulated)
        certificate = await cert_manager.create_certificate(cert_request)
        print(f"✅ Certificate object created")
        print(f"   - Unique ID: {certificate.unique_id}")
        print(f"   - Status: {certificate.status.value}")
        print(f"   - Display Name: {certificate.display_name}")

        # Simulate status updates
        await cert_manager.update_certificate_status(
            certificate.unique_id,
            CertificateStatus.ACTIVE,
            "Certificate issued successfully"
        )
        print(f"✅ Certificate status updated to ACTIVE")

        # Monitor certificate health
        health_metrics = await cert_manager.monitor_certificate_health()
        print(f"✅ Health monitoring completed")
        print(
            f"   - Total certificates: {health_metrics['total_certificates']}")
        print(f"   - Health score: {health_metrics['health_score']}%")

        # Cleanup
        await cert_manager.close()
        print(f"✅ Certificate manager closed")

        print("\n🎉 Demo completed successfully!")
        print("📝 Next steps:")
        print("   1. Configure your Azure credentials and Key Vault")
        print("   2. Set up certificate authority integration")
        print("   3. Deploy monitoring and automation runbooks")

    except Exception as e:
        print(f"❌ Demo failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    # Run the demo
    asyncio.run(demo_basic_usage())
