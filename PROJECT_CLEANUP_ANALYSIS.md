# Project Cleanup Recommendations

## 📁 Current Project Structure Analysis

### ✅ **KEEP - Active & Essential**

#### Core Working Scripts
- `certlc-deployment-scripts/` - **MAIN WORKING DIRECTORY** 
  - Contains our fixed automation scripts
  - Testing folder with validated tools
  - Core configuration and runbooks

#### Documentation & Analysis
- `AUTOMATION_ANALYSIS_SUMMARY.md` - **OUR ANALYSIS RESULTS**
- `README.md` - Project documentation
- `docs/` - Documentation folder

#### Linux Migration Work
- `linux-python-certlc/` - **FUTURE LINUX IMPLEMENTATION**
- `certificate-lifecycle-scripts/` - Original automation deployment

### ⚠️ **ARCHIVE - Troubleshooting History**

#### Arc/Hybrid Worker Recovery Scripts (Move to archive/)
- `arc-agent-reconnect.ps1`
- `automate-arc-reconnect.sh` 
- `automate-full-recovery.sh`
- `automated-recovery.sh`
- `check-hybrid-worker-status*` (3 files)
- `create-arc-script-on-ca01.ps1`
- `escalated-hybrid-worker-fix.sh`
- `fix-hybridv2-worker.sh`
- `manual-hybridv2-fix.sh`
- `monitor-hybrid-worker.sh`
- `simple-arc-fix.ps1`
- `simple-arc-recovery.sh`
- `troubleshoot-hybrid-worker.sh`
- `windows-arc-recovery.ps1`
- `windows-native-recovery.sh`

#### Network/SSH Troubleshooting (Move to archive/)
- `check-ca01-services.sh`
- `diagnose-ssh-auth.sh`
- `enable-winrm-ca01.ps1`
- `install-ssh-key-ca01.ps1`
- `setup-authorized-keys.ps1`
- `setup-ssh-chain.sh`

#### Misc Files (Move to archive/)
- `dc01-commands.txt`
- `one-click-recovery.sh`
- `portal-status-guide.sh`
- `quick-fix.ps1`

#### Historical Documentation (Move to archive/)
- `Adobe-2025-10-28.md`
- `CERTIFICATE_DEPLOYMENT_REFERENCE.md`
- `DIRECTORY_RENAME_SUMMARY.md`
- `ENVIRONMENT_VARIABLES_GUIDE.md`
- `PROJECT_REORGANIZATION_SUMMARY.md`

## 🗂️ **Recommended Cleanup Structure**

```
/home/velen/cx/adobe/certLCMgmt/
├── README.md                           # Keep
├── AUTOMATION_ANALYSIS_SUMMARY.md     # Keep - Our Results
├── certlc-deployment-scripts/          # Keep - Main Working Directory
├── linux-python-certlc/              # Keep - Future Migration
├── certificate-lifecycle-scripts/     # Keep - Original Deployment
├── docs/                              # Keep - Documentation
└── archive-troubleshooting/           # NEW - Move old scripts here
    ├── arc-recovery/
    ├── ssh-network/
    ├── historical-docs/
    └── misc/
```

## 🎯 **Impact Assessment**

### What We Actually Need Going Forward:
1. **`certlc-deployment-scripts/`** - Our working automation
2. **`linux-python-certlc/`** - Future Linux migration  
3. **`AUTOMATION_ANALYSIS_SUMMARY.md`** - Our findings
4. **Core docs and README**

### What Can Be Archived:
- **25+ troubleshooting scripts** from the Hybrid Worker investigation
- **Historical documentation** from earlier iterations
- **Network/SSH scripts** that were debugging dead ends

## ✅ **Recommendation**

**YES** - Clean up is recommended. We can archive ~80% of the root directory files since:

1. **Analysis Complete**: We've solved the automation issues
2. **Working Solution**: `certlc-deployment-scripts/` contains everything functional
3. **Clear Path Forward**: Linux migration or webhook fix are the next steps
4. **Historical Value**: Archive maintains troubleshooting history for reference

**Would you like me to create the archive structure and move the files?**