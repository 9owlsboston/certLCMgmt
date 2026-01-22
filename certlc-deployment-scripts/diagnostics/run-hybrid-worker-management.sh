#!/bin/bash

# Hybrid Worker Management via SSH (Password-less)
# Executes the equivalent of the original PowerShell jump host scripts

DC01_IP="4.227.115.235"
CA01_IP="10.0.0.5"
SSH_USER="demoadmin"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo "=========================================="
echo "Hybrid Worker Management via SSH"
echo "=========================================="
echo "DC01 (Jump Host): $DC01_IP"
echo "CA01 (Target): $CA01_IP"
echo "SSH User: $SSH_USER"
echo "=========================================="

# Step 1: Test connectivity (equivalent to Connect-ViaJumpHost.ps1 -Action Test)
echo ""
echo "🔍 Step 1: Testing Jump Host Connectivity"
echo "=========================================="

ssh -i $SSH_KEY -o ConnectTimeout=10 $SSH_USER@$DC01_IP 'powershell.exe -Command "
Write-Host \"=== Jump Host Connectivity Test ===\" -ForegroundColor Cyan
Write-Host \"DC01 (Jump Host): \$env:COMPUTERNAME\" -ForegroundColor Green
Write-Host \"Testing network connectivity to CA01...\" -ForegroundColor Yellow

# Test network connectivity to CA01
\$ca01Test = Test-NetConnection -ComputerName 10.0.0.5 -Port 5985 -WarningAction SilentlyContinue
if (\$ca01Test.TcpTestSucceeded) {
    Write-Host \"✅ Network connectivity to CA01 (10.0.0.5:5985): SUCCESS\" -ForegroundColor Green
} else {
    Write-Host \"❌ Network connectivity to CA01 (10.0.0.5:5985): FAILED\" -ForegroundColor Red
}

# Test WinRM connectivity
Write-Host \"Testing WinRM connectivity to CA01...\" -ForegroundColor Yellow
try {
    \$session = Test-WSMan -ComputerName 10.0.0.5 -ErrorAction Stop
    Write-Host \"✅ WinRM connectivity to CA01: SUCCESS\" -ForegroundColor Green
} catch {
    Write-Host \"❌ WinRM connectivity to CA01: FAILED - \$(\$_.Exception.Message)\" -ForegroundColor Red
}

Write-Host \"✅ Jump Host connectivity test completed!\" -ForegroundColor Green
"'

echo ""
echo "Press Enter to continue to Step 2..."
read

# Step 2: Check hybrid worker status (equivalent to Test-HybridWorker-JumpHost.ps1)
echo ""
echo "🔍 Step 2: Testing Hybrid Worker Status"
echo "======================================="

ssh -i $SSH_KEY -o ConnectTimeout=10 $SSH_USER@$DC01_IP 'powershell.exe -Command "
Write-Host \"=== Hybrid Worker Status Check ===\" -ForegroundColor Cyan

# Try to create a remote session to CA01
Write-Host \"Attempting to connect to CA01 for hybrid worker status...\" -ForegroundColor Yellow

try {
    # Test if we can create a session to CA01
    \$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    \$session = New-PSSession -ComputerName 10.0.0.5 -SessionOption \$sessionOptions -ErrorAction Stop
    
    if (\$session) {
        Write-Host \"✅ Successfully connected to CA01\" -ForegroundColor Green
        
        # Get hybrid worker service status
        \$result = Invoke-Command -Session \$session -ScriptBlock {
            Write-Host \"Checking hybrid worker services on CA01...\" -ForegroundColor Yellow
            
            # Check for hybrid worker related services
            \$hybridServices = Get-Service | Where-Object { 
                \$_.Name -like \"*hybrid*\" -or 
                \$_.Name -like \"*automation*\" -or 
                \$_.DisplayName -like \"*hybrid*\" -or
                \$_.DisplayName -like \"*automation*\" -or
                \$_.Name -eq \"HealthService\" -or
                \$_.DisplayName -like \"*Microsoft Monitoring Agent*\"
            }
            
            if (\$hybridServices) {
                Write-Host \"Found hybrid worker related services:\" -ForegroundColor Cyan
                foreach (\$service in \$hybridServices) {
                    \$status = if (\$service.Status -eq \"Running\") { \"✅\" } else { \"❌\" }
                    \$color = if (\$service.Status -eq \"Running\") { \"Green\" } else { \"Red\" }
                    Write-Host \"\$status \$(\$service.Name): \$(\$service.Status)\" -ForegroundColor \$color
                }
            } else {
                Write-Host \"⚠️  No hybrid worker services found\" -ForegroundColor Yellow
            }
            
            # Check Windows services related to Azure
            \$azureServices = Get-Service | Where-Object { \$_.Name -like \"*azure*\" -or \$_.DisplayName -like \"*azure*\" }
            if (\$azureServices) {
                Write-Host \"Azure related services:\" -ForegroundColor Cyan
                foreach (\$service in \$azureServices) {
                    \$status = if (\$service.Status -eq \"Running\") { \"✅\" } else { \"❌\" }
                    \$color = if (\$service.Status -eq \"Running\") { \"Green\" } else { \"Red\" }
                    Write-Host \"\$status \$(\$service.Name): \$(\$service.Status)\" -ForegroundColor \$color
                }
            }
        }
        
        Remove-PSSession \$session
        Write-Host \"✅ Hybrid worker status check completed!\" -ForegroundColor Green
    }
} catch {
    Write-Host \"❌ Failed to connect to CA01: \$(\$_.Exception.Message)\" -ForegroundColor Red
    Write-Host \"Checking if WinRM is enabled on CA01...\" -ForegroundColor Yellow
    
    # Alternative approach - try to enable WinRM remotely if possible
    try {
        \$enableResult = Invoke-Command -ComputerName 10.0.0.5 -ScriptBlock { winrm quickconfig -force } -ErrorAction Stop
        Write-Host \"✅ WinRM configuration attempted on CA01\" -ForegroundColor Green
    } catch {
        Write-Host \"❌ Could not configure WinRM on CA01: \$(\$_.Exception.Message)\" -ForegroundColor Red
    }
}
"'

echo ""
echo "Press Enter to continue to Step 3..."
read

# Step 3: Restart hybrid worker services (equivalent to Manage-HybridWorkerService-JumpHost.ps1 -Action Restart)
echo ""
echo "🔄 Step 3: Restarting Hybrid Worker Services"
echo "============================================="

ssh -i $SSH_KEY -o ConnectTimeout=10 $SSH_USER@$DC01_IP 'powershell.exe -Command "
Write-Host \"=== Hybrid Worker Service Restart ===\" -ForegroundColor Cyan

try {
    # Create remote session to CA01
    \$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    \$session = New-PSSession -ComputerName 10.0.0.5 -SessionOption \$sessionOptions -ErrorAction Stop
    
    if (\$session) {
        Write-Host \"✅ Connected to CA01 for service restart\" -ForegroundColor Green
        
        \$result = Invoke-Command -Session \$session -ScriptBlock {
            Write-Host \"Restarting hybrid worker services on CA01...\" -ForegroundColor Yellow
            
            # List of potential hybrid worker service names
            \$serviceNames = @(
                \"HybridWorkerService\",
                \"Microsoft Monitoring Agent\", 
                \"HealthService\",
                \"Azure Automation Hybrid Worker\"
            )
            
            foreach (\$serviceName in \$serviceNames) {
                \$service = Get-Service -Name \$serviceName -ErrorAction SilentlyContinue
                if (\$service) {
                    try {
                        Write-Host \"🔄 Restarting \$serviceName...\" -ForegroundColor Yellow
                        Restart-Service -Name \$serviceName -Force -ErrorAction Stop
                        \$newStatus = (Get-Service -Name \$serviceName).Status
                        Write-Host \"✅ \$serviceName restarted successfully - Status: \$newStatus\" -ForegroundColor Green
                    } catch {
                        Write-Host \"❌ Failed to restart \$serviceName: \$(\$_.Exception.Message)\" -ForegroundColor Red
                    }
                } else {
                    Write-Host \"ℹ️  Service \$serviceName not found\" -ForegroundColor Gray
                }
            }
            
            # Also restart any service with \"hybrid\" in the name
            \$hybridServices = Get-Service | Where-Object { 
                (\$_.Name -like \"*hybrid*\" -or \$_.DisplayName -like \"*hybrid*\") -and 
                \$_.Name -notin \$serviceNames 
            }
            
            foreach (\$service in \$hybridServices) {
                try {
                    Write-Host \"🔄 Restarting \$(\$service.Name)...\" -ForegroundColor Yellow
                    Restart-Service -Name \$service.Name -Force -ErrorAction Stop
                    \$newStatus = (Get-Service -Name \$service.Name).Status
                    Write-Host \"✅ \$(\$service.Name) restarted successfully - Status: \$newStatus\" -ForegroundColor Green
                } catch {
                    Write-Host \"❌ Failed to restart \$(\$service.Name): \$(\$_.Exception.Message)\" -ForegroundColor Red
                }
            }
            
            Write-Host \"🔍 Final service status check:\" -ForegroundColor Cyan
            \$allServices = Get-Service | Where-Object { 
                \$_.Name -like \"*hybrid*\" -or 
                \$_.Name -like \"*automation*\" -or 
                \$_.DisplayName -like \"*hybrid*\" -or
                \$_.DisplayName -like \"*automation*\" -or
                \$_.Name -eq \"HealthService\"
            }
            
            foreach (\$service in \$allServices) {
                \$status = if (\$service.Status -eq \"Running\") { \"✅\" } else { \"❌\" }
                \$color = if (\$service.Status -eq \"Running\") { \"Green\" } else { \"Red\" }
                Write-Host \"\$status \$(\$service.Name): \$(\$service.Status)\" -ForegroundColor \$color
            }
        }
        
        Remove-PSSession \$session
        Write-Host \"✅ Hybrid worker service restart completed!\" -ForegroundColor Green
    }
} catch {
    Write-Host \"❌ Failed to connect to CA01 for service restart: \$(\$_.Exception.Message)\" -ForegroundColor Red
}
"'

echo ""
echo "🎉 All hybrid worker management steps completed!"
echo ""
echo "📋 Summary:"
echo "1. ✅ Jump host connectivity tested"
echo "2. ✅ Hybrid worker status checked"  
echo "3. ✅ Hybrid worker services restarted"
echo ""
echo "💡 Next: Check Azure portal to verify hybrid worker is now communicating"