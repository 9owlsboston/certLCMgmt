#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Sets the CertRenewalThresholdDays automation variable to enable testing with short-lived certificates
.DESCRIPTION
    This script creates or updates the CertRenewalThresholdDays automation variable in the Azure Automation Account.
    Setting this to 1 day allows our 2-minute test certificates to qualify for renewal processing.
.PARAMETER ThresholdDays
    Number of days before expiry to trigger renewal (default: 1 for testing)
#>

param(
    [int]$ThresholdDays = 1
)

# Import configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Try to load Config-Loader module
$configLoaderPath = "$projectRoot/Config-Loader.psm1"
if (Test-Path $configLoaderPath) {
    Import-Module $configLoaderPath -Force
} else {
    Write-Host "⚠️ Config-Loader.psm1 not found, loading .env manually..." -ForegroundColor Yellow
    
    # Load .env file manually
    $envPath = "$projectRoot/.env"
    if (Test-Path $envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                # Remove quotes from the value
                $value = $matches[2].Trim('"').Trim("'")
                [Environment]::SetEnvironmentVariable($matches[1], $value, "Process")
            }
        }
        Write-Host "✅ Environment variables loaded from .env" -ForegroundColor Green
    } else {
        Write-Host "❌ .env file not found at $envPath" -ForegroundColor Red
        Write-Host "Please ensure you have a .env file with AUTOMATION_ACCOUNT_NAME and RESOURCE_GROUP" -ForegroundColor Yellow
        exit 1
    }
}

try {
    Write-Host "🔧 Setting up renewal threshold for testing..." -ForegroundColor Cyan
    Write-Host "Target: $($env:AUTOMATION_ACCOUNT_NAME) in $($env:RESOURCE_GROUP)"
    Write-Host "Setting CertRenewalThresholdDays to: $ThresholdDays days"
    Write-Host ""

    # Validate required environment variables
    if (-not $env:AUTOMATION_ACCOUNT_NAME) {
        throw "AUTOMATION_ACCOUNT_NAME environment variable is not set"
    }
    if (-not $env:RESOURCE_GROUP) {
        throw "RESOURCE_GROUP environment variable is not set"
    }

    # Check if variable exists first
    Write-Host "📋 Checking existing automation variables..." -ForegroundColor Yellow
    try {
        $existingVar = Get-AzAutomationVariable -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -Name "CertRenewalThresholdDays" -ErrorAction Stop
        Write-Host "✅ Variable exists with current value: $($existingVar.Value)" -ForegroundColor Green
        
        # Update existing variable
        Write-Host "🔄 Updating existing variable..." -ForegroundColor Yellow
        Set-AzAutomationVariable -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -Name "CertRenewalThresholdDays" -Value $ThresholdDays -Encrypted $false
        Write-Host "✅ Variable updated successfully!" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*was not found*") {
            Write-Host "ℹ️ Variable doesn't exist, creating new one..." -ForegroundColor Yellow
            
            # Create new variable
            New-AzAutomationVariable -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -Name "CertRenewalThresholdDays" -Value $ThresholdDays -Encrypted $false
            Write-Host "✅ Variable created successfully!" -ForegroundColor Green
        }
        else {
            throw $_
        }
    }

    # Verify the setting
    Write-Host ""
    Write-Host "🔍 Verifying configuration..." -ForegroundColor Cyan
    $verifyVar = Get-AzAutomationVariable -AutomationAccountName $env:AUTOMATION_ACCOUNT_NAME -ResourceGroupName $env:RESOURCE_GROUP -Name "CertRenewalThresholdDays"
    Write-Host "Current value: $($verifyVar.Value) days" -ForegroundColor Green
    Write-Host "Encrypted: $($verifyVar.Encrypted)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎯 IMPACT ANALYSIS:" -ForegroundColor Magenta
    Write-Host "- Certificates expiring within $ThresholdDays day(s) will now qualify for renewal" -ForegroundColor White
    Write-Host "- Our 2-minute test certificates should now trigger the renewal process" -ForegroundColor White
    Write-Host "- The runbook will no longer exit early due to threshold checks" -ForegroundColor White
    
    Write-Host ""
    Write-Host "📝 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Create a new short-lived test certificate" -ForegroundColor White
    Write-Host "2. Monitor automation jobs for successful execution" -ForegroundColor White
    Write-Host "3. Verify certificate renewal occurs within the expiry window" -ForegroundColor White
    
    Write-Host ""
    Write-Host "✅ Automation variable configuration completed!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error setting automation variable:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "- Ensure you're authenticated to Azure (Connect-AzAccount)" -ForegroundColor White
    Write-Host "- Verify you have Automation Contributor role on the resource group" -ForegroundColor White
    Write-Host "- Check that the automation account name and resource group are correct" -ForegroundColor White
    exit 1
}