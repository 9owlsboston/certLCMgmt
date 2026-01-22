# Archive - Troubleshooting History

This directory contains troubleshooting scripts and documentation from the Certificate Lifecycle Management automation investigation (November 2025).

## 📁 Directory Structure

### `arc-recovery/`
Scripts related to Azure Arc agent and Hybrid Worker connectivity issues:
- Arc agent reconnection scripts
- Hybrid Worker status checks and fixes
- Windows recovery automation
- Connection monitoring tools

### `ssh-network/`
Network connectivity and SSH troubleshooting scripts:
- SSH key setup and authentication
- CA01 service checks
- WinRM configuration
- Network diagnostics

### `historical-docs/`
Documentation from previous project iterations:
- Original project organization summaries
- Environment variable guides
- Certificate deployment references
- Adobe meeting notes

### `misc/`
Miscellaneous troubleshooting artifacts:
- DC01 command references
- Portal status guides
- Quick fix scripts
- Ad-hoc recovery tools

## 🎯 Archive Purpose

These files represent the investigative work that led to identifying and fixing the certificate lifecycle automation issues:

1. **Threshold configuration** (CertRenewalThresholdDays)
2. **Hybrid Worker routing** (webhook configuration)
3. **System validation** (end-to-end testing)

## ✅ Resolution Summary

**Root Causes Identified:**
- Automation variable `CertRenewalThresholdDays` not set (defaulted to 30 days)
- Webhook `clc-webhook` missing Hybrid Worker target (`EnterpriseRootCA`)

**System Status:**
- Event Grid: ✅ Working (publishing events)
- Automation Account: ✅ Working (receiving webhooks)
- Hybrid Worker: ✅ Working (CA01 online, processing renewals)
- Certificate Processing: ✅ Working (Submit-Certificate operations successful)

**Automation is 90% functional** - only webhook routing needs final configuration.

---
*Archived: November 3, 2025*
*Investigation completed with working automation validation*