# Azure PowerShell Module Installation Script for DC01
# Run this as Administrator on DC01 to install required Azure modules

Write-Host "🔧 Installing Azure PowerShell Modules on DC01" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Gray

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green

# Step 1: Check PowerShell version
Write-Host "`n1. Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "   PowerShell Version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Gray

if ($psVersion.Major -lt 5) {
    Write-Host "   ❌ PowerShell 5.0 or higher required" -ForegroundColor Red
    Write-Host "   Please update PowerShell and try again" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "   ✅ PowerShell version compatible" -ForegroundColor Green
}

# Step 2: Set execution policy if needed
Write-Host "`n2. Checking execution policy..." -ForegroundColor Yellow
$executionPolicy = Get-ExecutionPolicy
Write-Host "   Current execution policy: $executionPolicy" -ForegroundColor Gray

if ($executionPolicy -eq "Restricted") {
    Write-Host "   ⚠️  Execution policy is Restricted, setting to RemoteSigned..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "   ✅ Execution policy updated" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Failed to update execution policy: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   ✅ Execution policy allows module installation" -ForegroundColor Green
}

# Step 3: Configure PowerShell Gallery as trusted repository
Write-Host "`n3. Configuring PowerShell Gallery..." -ForegroundColor Yellow
try {
    $gallery = Get-PSRepository -Name "PSGallery"
    if ($gallery.InstallationPolicy -ne "Trusted") {
        Write-Host "   ⚠️  Setting PowerShell Gallery as trusted repository..." -ForegroundColor Yellow
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Write-Host "   ✅ PowerShell Gallery configured as trusted" -ForegroundColor Green
    } else {
        Write-Host "   ✅ PowerShell Gallery already trusted" -ForegroundColor Green
    }
}
catch {
    Write-Host "   ❌ Failed to configure PowerShell Gallery: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Install Azure PowerShell modules
Write-Host "`n4. Installing Azure PowerShell modules..." -ForegroundColor Yellow
Write-Host "   ⏳ This may take several minutes..." -ForegroundColor Gray

$modulesToInstall = @(
    @{Name = "Az.Accounts"; Description = "Azure authentication"},
    @{Name = "Az.KeyVault"; Description = "Key Vault operations"},
    @{Name = "Az.Profile"; Description = "Azure profile management"}
)

$installSuccess = $true

foreach ($moduleInfo in $modulesToInstall) {
    $moduleName = $moduleInfo.Name
    $description = $moduleInfo.Description
    
    Write-Host "`n   📦 Installing $moduleName ($description)..." -ForegroundColor Gray
    
    try {
        # Check if already installed
        $existingModule = Get-Module -Name $moduleName -ListAvailable
        if ($existingModule) {
            Write-Host "      ℹ️  $moduleName already installed (Version: $($existingModule[0].Version))" -ForegroundColor Yellow
            Write-Host "      🔄 Updating to latest version..." -ForegroundColor Gray
            Update-Module -Name $moduleName -Force -ErrorAction Stop
            Write-Host "      ✅ $moduleName updated successfully" -ForegroundColor Green
        } else {
            Install-Module -Name $moduleName -Force -AllowClobber -ErrorAction Stop
            Write-Host "      ✅ $moduleName installed successfully" -ForegroundColor Green
        }
        
        # Verify installation
        $installedModule = Get-Module -Name $moduleName -ListAvailable | Select-Object -First 1
        if ($installedModule) {
            Write-Host "      📋 Version: $($installedModule.Version)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "      ❌ Failed to install $moduleName`: $($_.Exception.Message)" -ForegroundColor Red
        $installSuccess = $false
    }
}

# Step 5: Import modules to verify they work
Write-Host "`n5. Testing installed modules..." -ForegroundColor Yellow

foreach ($moduleInfo in $modulesToInstall) {
    $moduleName = $moduleInfo.Name
    
    try {
        Write-Host "   🔍 Testing $moduleName..." -ForegroundColor Gray
        Import-Module $moduleName -Force -ErrorAction Stop
        
        # Test module functionality
        if ($moduleName -eq "Az.Accounts") {
            $commands = Get-Command -Module $moduleName | Measure-Object
            Write-Host "      ✅ $moduleName loaded ($($commands.Count) commands available)" -ForegroundColor Green
        } elseif ($moduleName -eq "Az.KeyVault") {
            $commands = Get-Command -Module $moduleName | Measure-Object
            Write-Host "      ✅ $moduleName loaded ($($commands.Count) commands available)" -ForegroundColor Green
        } else {
            Write-Host "      ✅ $moduleName loaded successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "      ❌ Failed to load $moduleName`: $($_.Exception.Message)" -ForegroundColor Red
        $installSuccess = $false
    }
}

# Step 6: Final verification
Write-Host "`n6. Final verification..." -ForegroundColor Yellow

try {
    # Test that Get-AzContext is now available
    $contextCommand = Get-Command "Get-AzContext" -ErrorAction Stop
    Write-Host "   ✅ Azure authentication commands available" -ForegroundColor Green
    
    # Test that Key Vault commands are available
    $kvCommand = Get-Command "Get-AzKeyVault" -ErrorAction Stop
    Write-Host "   ✅ Azure Key Vault commands available" -ForegroundColor Green
    
    Write-Host "`n🎉 SUCCESS: Azure PowerShell modules installed and ready!" -ForegroundColor Green -BackgroundColor Black
    
}
catch {
    Write-Host "   ❌ Verification failed: $($_.Exception.Message)" -ForegroundColor Red
    $installSuccess = $false
}

# Summary and next steps
Write-Host "`n📋 INSTALLATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Gray

if ($installSuccess) {
    Write-Host "✅ All Azure PowerShell modules installed successfully!" -ForegroundColor Green
    
    Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Authenticate to Azure:" -ForegroundColor White
    Write-Host "   Connect-AzAccount" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Run the diagnostic script again to verify everything works:" -ForegroundColor White
    Write-Host "   .\diagnose-dc01-issues.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Once diagnostics pass, run the certificate creation script:" -ForegroundColor White
    Write-Host "   .\create-shortlived-cert.ps1" -ForegroundColor Gray
    
    Write-Host "`n🔧 AUTHENTICATION COMMAND:" -ForegroundColor Cyan
    Write-Host "Connect-AzAccount" -ForegroundColor Yellow -BackgroundColor Black
    
} else {
    Write-Host "❌ Some modules failed to install" -ForegroundColor Red
    Write-Host "`n🔧 TROUBLESHOOTING STEPS:" -ForegroundColor Yellow
    Write-Host "1. Check internet connectivity" -ForegroundColor White
    Write-Host "2. Verify Windows Update is not blocking PowerShell Gallery" -ForegroundColor White
    Write-Host "3. Try manual installation:" -ForegroundColor White
    Write-Host "   Install-Module -Name Az -Force -AllowClobber" -ForegroundColor Gray
    Write-Host "4. Check Windows firewall/proxy settings" -ForegroundColor White
}

Write-Host "`n💡 TIP: After authentication, all Azure commands will be available!" -ForegroundColor Cyan
Write-Host "    You'll be able to manage Key Vault, create certificates, and more." -ForegroundColor Gray