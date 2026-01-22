#!/bin/bash

# Direct SSH Hybrid Worker Management
# Uses direct SSH commands since PowerShell remoting subsystem may not be configured

# Load configuration
if [ -f "../.env" ]; then
    source ../.env
    echo "✅ Configuration loaded from .env file"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Automation Account: $AUTOMATION_ACCOUNT_NAME"
else
    echo "❌ .env file not found"
    exit 1
fi

DC01_PUBLIC_IP="4.227.115.235"
CA01_PRIVATE_IP="10.0.0.5"
SSH_USER="demoadmin"

echo "=========================================="
echo "Direct SSH Hybrid Worker Management"
echo "=========================================="
echo "DC01 (Jump Host): $DC01_PUBLIC_IP"
echo "CA01 (Target): $CA01_PRIVATE_IP"
echo "SSH User: $SSH_USER"
echo "Resource Group: $RESOURCE_GROUP"
echo "=========================================="

# Function to execute PowerShell commands via SSH
execute_powershell_via_ssh() {
    local host=$1
    local command=$2
    local description=$3
    
    echo ""
    echo "🔄 $description"
    echo "   Host: $host"
    echo "   Command: $command"
    echo ""
    
    # Execute PowerShell command via SSH
    ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 "$SSH_USER@$host" "powershell.exe -Command \"$command\""
}

# Function to check hybrid worker status on CA01 via DC01
check_hybrid_worker_status() {
    echo "🔍 Checking hybrid worker status on CA01..."
    
    # Create PowerShell command to execute on CA01 via DC01
    local ps_command='
    $targetHost = "10.0.0.5"
    $credential = Get-Credential -Message "Enter credentials for CA01"
    
    $session = New-PSSession -ComputerName $targetHost -Credential $credential
    
    if ($session) {
        $result = Invoke-Command -Session $session -ScriptBlock {
            Write-Host "=== Hybrid Worker Service Status ===" -ForegroundColor Cyan
            
            # Check for hybrid worker related services
            $services = Get-Service | Where-Object { 
                $_.Name -like "*hybrid*" -or 
                $_.Name -like "*automation*" -or 
                $_.DisplayName -like "*hybrid*" -or
                $_.DisplayName -like "*automation*"
            }
            
            if ($services) {
                foreach ($service in $services) {
                    $status = if ($service.Status -eq "Running") { "✅" } else { "❌" }
                    Write-Host "$status $($service.Name): $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running") { "Green" } else { "Red" })
                }
            } else {
                Write-Host "⚠️  No hybrid worker services found" -ForegroundColor Yellow
            }
            
            # Check for Azure related services
            Write-Host "`n=== Azure Related Services ===" -ForegroundColor Cyan
            $azureServices = Get-Service | Where-Object { $_.Name -like "*azure*" -or $_.DisplayName -like "*azure*" }
            foreach ($service in $azureServices) {
                $status = if ($service.Status -eq "Running") { "✅" } else { "❌" }
                Write-Host "$status $($service.Name): $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running") { "Green" } else { "Red" })
            }
        }
        
        Remove-PSSession $session
    } else {
        Write-Host "❌ Failed to create remote session to CA01" -ForegroundColor Red
    }
    '
    
    execute_powershell_via_ssh "$DC01_PUBLIC_IP" "$ps_command" "Checking hybrid worker status on CA01 via DC01"
}

# Function to restart hybrid worker services
restart_hybrid_worker_services() {
    echo "🔄 Restarting hybrid worker services on CA01..."
    
    local ps_command='
    $targetHost = "10.0.0.5"
    $credential = Get-Credential -Message "Enter credentials for CA01"
    
    $session = New-PSSession -ComputerName $targetHost -Credential $credential
    
    if ($session) {
        $result = Invoke-Command -Session $session -ScriptBlock {
            Write-Host "=== Restarting Hybrid Worker Services ===" -ForegroundColor Cyan
            
            # List of potential hybrid worker service names
            $serviceNames = @(
                "HybridWorkerService",
                "Microsoft Monitoring Agent", 
                "HealthService",
                "Azure Automation Hybrid Worker"
            )
            
            foreach ($serviceName in $serviceNames) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    try {
                        Write-Host "🔄 Restarting $serviceName..." -ForegroundColor Yellow
                        Restart-Service -Name $serviceName -Force -ErrorAction Stop
                        Write-Host "✅ Successfully restarted $serviceName" -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Failed to restart $serviceName`: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "ℹ️  Service $serviceName not found" -ForegroundColor Gray
                }
            }
            
            # Also try to find and restart any service with "hybrid" in the name
            $hybridServices = Get-Service | Where-Object { $_.Name -like "*hybrid*" -or $_.DisplayName -like "*hybrid*" }
            foreach ($service in $hybridServices) {
                if ($service.Name -notin $serviceNames) {
                    try {
                        Write-Host "🔄 Restarting $($service.Name)..." -ForegroundColor Yellow
                        Restart-Service -Name $service.Name -Force -ErrorAction Stop
                        Write-Host "✅ Successfully restarted $($service.Name)" -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Failed to restart $($service.Name)`: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
        
        Remove-PSSession $session
    } else {
        Write-Host "❌ Failed to create remote session to CA01" -ForegroundColor Red
    }
    '
    
    execute_powershell_via_ssh "$DC01_PUBLIC_IP" "$ps_command" "Restarting hybrid worker services on CA01 via DC01"
}

# Function to test connectivity
test_connectivity() {
    echo "🔍 Testing connectivity..."
    
    echo "Testing SSH to DC01..."
    if ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=5 "$SSH_USER@$DC01_PUBLIC_IP" "echo 'SSH to DC01 successful'" 2>/dev/null; then
        echo "✅ DC01 SSH connection successful"
    else
        echo "❌ DC01 SSH connection failed"
        return 1
    fi
    
    echo "Testing PowerShell availability on DC01..."
    local ps_test=$(ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 "$SSH_USER@$DC01_PUBLIC_IP" "powershell.exe -Command \"Write-Host 'PowerShell test successful'; \$PSVersionTable.PSVersion.ToString()\"" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✅ PowerShell available on DC01"
        echo "   $ps_test"
    else
        echo "❌ PowerShell test failed on DC01"
        return 1
    fi
    
    echo "Testing network connectivity from DC01 to CA01..."
    local network_test='Test-NetConnection -ComputerName 10.0.0.5 -Port 5985 | Select-Object ComputerName, RemoteAddress, TcpTestSucceeded | Format-List'
    execute_powershell_via_ssh "$DC01_PUBLIC_IP" "$network_test" "Testing network connectivity to CA01"
}

# Main menu
show_menu() {
    echo ""
    echo "📋 SSH Hybrid Worker Management Options:"
    echo "1. Test connectivity (equivalent to Connect-ViaJumpHost.ps1 -Action Test)"
    echo "2. Check hybrid worker status (equivalent to Test-HybridWorker-JumpHost.ps1)"
    echo "3. Restart hybrid worker services (equivalent to Manage-HybridWorkerService-JumpHost.ps1 -Action Restart)"
    echo "4. All steps (recommended)"
    echo "5. Exit"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1) test_connectivity ;;
        2) check_hybrid_worker_status ;;
        3) restart_hybrid_worker_services ;;
        4) 
            echo "🚀 Executing all steps..."
            test_connectivity
            echo ""
            echo "Press Enter to continue to hybrid worker status check..."
            read
            check_hybrid_worker_status
            echo ""
            echo "Press Enter to continue to service restart..."
            read
            restart_hybrid_worker_services
            ;;
        5) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option"; show_menu ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Start the script
show_menu