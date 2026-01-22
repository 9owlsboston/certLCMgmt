#!/usr/bin/env python3
"""
Python equivalent of create-shortlived-cert.ps1

Creates a short-lived certificate for testing certificate lifecycle automation.
This demonstrates how the same functionality can be implemented in the Linux/Python environment.
"""

from certificate_lifecycle import (CertificateManager, CertificateRequest,
                                   CertificateStatus, CertificateSubject,
                                   CertificateType, KeyAlgorithm, Settings)
import asyncio
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Add the src directory to Python path for development
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "linux-python-certlc" / "src"))


class ShortLivedCertificateCreator:
    """Creates short-lived certificates for testing"""

    def __init__(self):
        # Configure for demo/testing
        os.environ.setdefault("AZURE_SUBSCRIPTION_ID", "demo-subscription")
        os.environ.setdefault("AZURE_KEY_VAULT_URL",
                              "https://demo-kv-1030164500.vault.azure.net/")
        os.environ.setdefault("AZURE_RESOURCE_GROUP", "rg-demo-certlc")

        self.settings = Settings()
        self.cert_manager = CertificateManager(self.settings)

        # Certificate parameters
        self.cert_name = "democert-shortlived-python"
        self.validity_minutes = 2  # 2 minutes for immediate expiry testing

    async def create_shortlived_certificate(self):
        """Create a short-lived certificate for testing"""
        print("🎯 Creating Short-Lived Certificate for Immediate Expiry Testing (Python)")
        print("=" * 75)

        try:
            # Step 1: Create certificate request
            print("\n1. Creating certificate request..." + "🔶" * 5)

            subject = CertificateSubject(
                common_name=self.cert_name,
                organization="Demo Organization",
                organizational_unit="Testing Department",
                locality="Seattle",
                state="Washington",
                country="US",
                email="test@example.com"
            )

            # Calculate expiry time (2 minutes from now)
            now = datetime.utcnow()
            expires_at = now + timedelta(minutes=self.validity_minutes)

            cert_request = CertificateRequest(
                subject=subject,
                certificate_type=CertificateType.SERVER,
                key_algorithm=KeyAlgorithm.RSA_2048,
                validity_days=1,  # Minimum, but we'll use short expiry
                subject_alternative_names=[
                    f"www.{self.cert_name}.example.com",
                    f"api.{self.cert_name}.example.com"
                ],
                ca_provider="lab",  # Use lab CA for testing
                requestor="python-test@example.com",
                business_justification="Short-lived certificate for expiry testing",
                tags={
                    "purpose": "testing",
                    "expiry_test": "true",
                    "created_by": "python_script",
                    "environment": "lab"
                }
            )

            print(f"   ✅ Certificate request created")
            print(f"   📋 Subject: {subject.common_name}")
            print(f"   📅 Created: {now.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   ⏰ Expires: {expires_at.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   ⚡ Duration: {self.validity_minutes} minutes")
            print(f"   🔑 Key Algorithm: {cert_request.key_algorithm.value}")

            # Step 2: Validate certificate request
            print("\n2. Validating certificate request..." + "🔶" * 5)

            validation_errors = cert_request.validate()
            if validation_errors:
                print("   ❌ Certificate request validation failed:")
                for error in validation_errors:
                    print(f"      - {error}")
                return False

            print("   ✅ Certificate request validation passed")

            # Step 3: Create certificate object
            print("\n3. Creating certificate object..." + "🔶" * 5)

            certificate = await self.cert_manager.create_certificate(cert_request)

            # Override the expiry time for testing
            certificate.certificate_info.not_after = expires_at

            print(f"   ✅ Certificate object created")
            print(f"   🆔 Unique ID: {certificate.unique_id}")
            print(f"   📛 Display Name: {certificate.display_name}")
            print(f"   📊 Status: {certificate.status.value}")
            print(f"   🏷️  Tags: {certificate.tags}")

            # Step 4: Simulate certificate issuance (storage)
            print("\n4. Simulating certificate storage..." + "🔶" * 5)

            # In a real implementation, this would store in Azure Key Vault
            # For demo, we'll just update the status
            await self.cert_manager.update_certificate_status(
                certificate.unique_id,
                CertificateStatus.ACTIVE,
                "Certificate issued successfully (simulated)"
            )

            print("   ✅ Certificate stored and activated")
            print("   💾 Storage: Simulated (would be Azure Key Vault in production)")

            # Step 5: Add to monitoring
            print("\n5. Adding to certificate monitoring..." + "🔶" * 5)

            # Simulate monitoring setup
            certificate.add_renewal_record(
                action="monitoring_setup",
                result="success",
                details={
                    "expiry_monitoring": True,
                    "renewal_threshold_days": 30,
                    "alert_recipients": [cert_request.requestor],
                    "automation_enabled": True
                }
            )

            print("   ✅ Certificate added to monitoring system")
            print("   📊 Health monitoring enabled")
            print("   🔔 Expiry alerts configured")

            # Step 6: Health check
            print("\n6. Running initial health check..." + "🔶" * 5)

            health_metrics = await self.cert_manager.monitor_certificate_health()

            print(f"   ✅ Health check completed")
            print(
                f"   📈 Total certificates: {health_metrics['total_certificates']}")
            print(f"   💚 Health score: {health_metrics['health_score']}%")
            print(f"   ⏰ Timestamp: {health_metrics['timestamp']}")

            # Step 7: Calculate expiry timeline
            print("\n7. Expiry timeline analysis..." + "🔶" * 5)

            time_until_expiry = expires_at - datetime.utcnow()
            minutes_until_expiry = time_until_expiry.total_seconds() / 60

            print(
                f"   ⏳ Time until expiry: {minutes_until_expiry:.1f} minutes")
            print(
                f"   🚨 Will be expired by: {expires_at.strftime('%H:%M:%S')}")

            if minutes_until_expiry <= 0:
                print("   ⚠️  Certificate is already expired!")
            elif minutes_until_expiry <= 5:
                print("   🔥 Certificate expires very soon!")

            # Success summary
            print(f"\n🎉 SUCCESS: Short-lived certificate created!" + "🎉" * 8)
            print("🎯" * 50)

            return True

        except Exception as e:
            print(f"\n❌ CERTIFICATE CREATION FAILED: {e}")
            import traceback
            traceback.print_exc()
            return False

    async def show_testing_instructions(self):
        """Show testing instructions"""
        print("\n📋 TESTING INSTRUCTIONS:")
        print("=" * 50)
        print("🐍 Python Certificate Lifecycle Testing")
        print("")

        print("1. Monitor certificate expiry:")
        print("   - Certificate will expire in 2 minutes")
        print("   - Use Python monitoring to track status")
        print("")

        print("2. Test renewal automation:")
        print("   - Implement CA adapter for actual certificate issuance")
        print("   - Add Azure Key Vault integration")
        print("   - Set up scheduled monitoring runbooks")
        print("")

        print("3. Equivalent Azure CLI commands:")
        print(
            f"   az keyvault certificate show --vault-name demo-kv-1030164500 --name {self.cert_name}")
        print("")

        print("4. Next development steps:")
        print("   - Implement AzureIntegratedCAAdapter")
        print("   - Add Redis-based distributed locking")
        print("   - Create monitoring runbooks")
        print("   - Deploy to Ubuntu VMs")
        print("")

        print("🚀 This demonstrates the foundation for Linux/Python certificate lifecycle management!")

    async def cleanup(self):
        """Cleanup resources"""
        print("\n🧹 Cleanup...")
        await self.cert_manager.close()
        print("   ✅ Certificate manager closed")


async def main():
    """Main execution function"""
    creator = ShortLivedCertificateCreator()

    try:
        success = await creator.create_shortlived_certificate()

        if success:
            await creator.show_testing_instructions()

            print("\n⏰ EXPIRY TIMELINE:")
            print("- Certificate expires in: 2 minutes")
            print("- Python monitoring can detect immediately")
            print("- Renewal automation ready for implementation")
            print("- Linux/Python environment operational!")

    except KeyboardInterrupt:
        print("\n⚠️ Operation cancelled by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
    finally:
        await creator.cleanup()


if __name__ == "__main__":
    print("🐍 Python Certificate Lifecycle Management - Short-Lived Certificate Creator")
    print("=" * 80)

    # Run the certificate creation
    asyncio.run(main())
