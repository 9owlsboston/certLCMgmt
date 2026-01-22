# Hybrid Runbook Worker (HRW) Troubleshooting Guide

## Current Issue Summary
**Date**: November 1, 2025  
**Problem**: Hybrid Worker on ca01 server hasn't checked in since October 31, 2025 8:27 AM  
**Impact**: All certificate lifecycle jobs are being suspended immediately upon submission  
**Root Cause**: Hybrid Worker service connectivity failure on ca01 Windows server

## Infrastructure Overview
- **CA Server**: ca01 (IP: 10.0.0.5) - Windows Server with Certificate Authority role
- **Domain Controller**: dc01 (IP: 10.0.0.4) - Active Directory services
- **Hybrid Worker Group**: EnterpriseRootCA
- **Registered Worker ID**: f47ceb57-e588-5f42-8431-78e508a58d3d
- **Last Check-in**: October 31, 2025 8:27:29 AM

## Symptoms
1. **Job Suspension**: All automation jobs suspend immediately after starting
2. **No Worker Communication**: Hybrid worker hasn't communicated with Azure for >24 hours
3. **Certificate Operations Failing**: Cannot perform CA-integrated certificate operations
4. **Queue Processing Halted**: Storage queue processing for certificate renewals stopped

## Troubleshooting Methodology

### Phase 1: Service Status Verification
1. **Connect to ca01 server**
2. **Check Hybrid Worker service status**
3. **Verify service logs for errors**
4. **Check system resources and dependencies**

### Phase 2: Network Connectivity
1. **Test internet connectivity from ca01**
2. **Verify Azure Automation endpoint accessibility**
3. **Check firewall rules and proxy settings**
4. **Validate DNS resolution for Azure services**

### Phase 3: Authentication & Registration
1. **Verify Managed Identity or service principal authentication**
2. **Check certificate/key expiration**
3. **Validate Azure Automation account connectivity**
4. **Test worker registration status**

### Phase 4: Service Recovery
1. **Restart Hybrid Worker service**
2. **Clear temporary files and caches**
3. **Re-register worker if necessary**
4. **Validate job execution capability**

## Common Causes & Solutions

### Service Stopped/Crashed
**Symptoms**: Service not running, recent crash logs
**Solution**: Restart service, check for underlying system issues

### Network Connectivity Issues
**Symptoms**: DNS failures, timeout errors in logs
**Solution**: Verify internet access, check firewall rules, test Azure endpoints

### Authentication Expiration
**Symptoms**: 401/403 errors in logs, authentication failures
**Solution**: Refresh credentials, re-register with current authentication

### System Resource Exhaustion
**Symptoms**: Out of memory errors, disk space issues
**Solution**: Clean temporary files, restart services, add resources if needed

### Azure Service Disruption
**Symptoms**: Multiple workers offline, Azure status page issues
**Solution**: Wait for Azure resolution, monitor Azure status

## Recovery Procedures

### Quick Recovery (Service Restart)
1. Connect to ca01 via RDP or PowerShell remoting
2. Run service restart script
3. Monitor service logs for successful startup
4. Test with simple automation job

### Full Recovery (Re-registration)
1. Remove existing worker registration
2. Clean local worker files and registry
3. Re-install and configure Hybrid Worker
4. Register with Azure Automation account
5. Test end-to-end functionality

## Post-Recovery Validation
1. **Service Status**: Verify Hybrid Worker service is running and healthy
2. **Azure Connectivity**: Confirm worker shows as "Online" in Azure portal
3. **Job Execution**: Submit test automation job to verify functionality
4. **Certificate Operations**: Test certificate lifecycle operations
5. **Monitoring**: Set up alerts for future worker connectivity issues

## Prevention Measures
1. **Regular Health Checks**: Implement automated service monitoring
2. **Credential Rotation**: Set up automated credential renewal
3. **Resource Monitoring**: Monitor system resources on ca01
4. **Backup Worker**: Consider secondary hybrid worker for redundancy
5. **Alert System**: Configure alerts for worker offline conditions

## Emergency Contacts & Resources
- **Azure Support**: For Azure Automation service issues
- **System Administrator**: For ca01 server access and management
- **Certificate Authority Team**: For CA service coordination
- **Network Team**: For connectivity troubleshooting

## Related Documentation
- [Azure Hybrid Runbook Worker Documentation](https://docs.microsoft.com/en-us/azure/automation/automation-hybrid-runbook-worker)
- [Certificate Lifecycle Management Guide](../CERTIFICATE_DEPLOYMENT_REFERENCE.md)
- [Monitoring Solution Summary](MONITORING_SOLUTION_SUMMARY.md)

---
*Document created: November 1, 2025*  
*Last updated: November 1, 2025*  
*Version: 1.0*