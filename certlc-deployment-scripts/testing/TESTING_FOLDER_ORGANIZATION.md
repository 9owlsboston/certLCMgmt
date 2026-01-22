# Testing Folder Organization
*Cleaned up on November 3, 2025*

## Current Structure

### 📂 current-scripts/
**ACTIVE TESTING SCRIPTS** - Use these for certificate lifecycle testing:

- **create-shortlived-cert-windows.ps1** - Certificate creator with conflict resolution
  - Creates certificates with December expiry (Azure Key Vault minimum)
  - Handles naming conflicts automatically
  - Windows-compatible with embedded configuration

- **set-threshold-simple.ps1** - 30-day renewal threshold setter
  - Sets CertRenewalThresholdDays=30 for immediate testing
  - Includes Azure module loading
  - Fixed PowerShell syntax

- **cleanup-pending-certs.ps1** - Certificate cleanup utility
  - Removes stuck/pending certificates from Key Vault
  - Interactive deletion with confirmation
  - Safe cleanup with error handling

- **monitor-automation-realtime.ps1** - Real-time automation monitoring
  - Monitors automation jobs every 30 seconds
  - Detects certificate changes in Key Vault
  - Shows automation activity in real-time

### 📂 monitoring/
**MONITORING & VALIDATION SCRIPTS**:

- check-automation-status.ps1 - Automation Account status checker
- check-event-grid-routing.ps1 - Event Grid routing validator
- monitor-renewal.ps1 - Certificate renewal monitor
- monitor-realtime-renewal.ps1 - Real-time renewal tracking
- test-hybrid-worker-execution.ps1 - Hybrid Worker functionality test

### 📂 archive-old/
**ARCHIVED SCRIPTS** - Historical/duplicate versions:

- Old threshold setters (syntax error versions)
- Diagnostic scripts from troubleshooting phase
- Alternative certificate creators
- Configuration and installation utilities

### 📂 archive/
**PREVIOUS ARCHIVE** - Earlier troubleshooting artifacts

## Usage Workflow

### 1. Certificate Creation
```powershell
.\current-scripts\create-shortlived-cert-windows.ps1
```

### 2. Set Testing Threshold
```powershell
.\current-scripts\set-threshold-simple.ps1
```

### 3. Monitor Automation
```powershell
.\current-scripts\monitor-automation-realtime.ps1
```

### 4. Cleanup (if needed)
```powershell
.\current-scripts\cleanup-pending-certs.ps1
```

## Cleanup Summary

**Before:** 33 files (many duplicates and troubleshooting artifacts)
**After:** 4 core scripts + organized monitoring and archive folders

**Files Archived:** 20+ old/duplicate scripts
**Files Organized:** 5 monitoring scripts
**Current Active:** 4 essential testing scripts

The testing folder is now clean and focused on the current working automation testing workflow.