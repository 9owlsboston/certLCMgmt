# Enhanced Runbook - Fixed Certificate Lifecycle Management
# Addresses OID extraction, template fallbacks, and error handling

param(
    [Parameter(Mandatory=$false)]
    [object] $WebhookData
)

# Enhanced function with better error handling and template fallbacks
function Enhanced-CertLCWorkflow {
    param (
        $WebhookData,
        $queuedMessage
    )

    $continue = $true
  
    if ($WebhookData) {
        Write-Output "=== Enhanced Certificate Lifecycle Workflow Starting ==="
        
        $body = (ConvertFrom-Json -InputObject $WebhookData[0])
        
        # VARIABLE FROM WEBHOOK QUERY
        $VaultName = $body.data.VaultName
        $ObjectName = $body.data.ObjectName

        Write-Output "VaultName = $VaultName"
        Write-Output "ObjectName = $ObjectName"

        # Import PSPKI module
        Write-Output "Import PSPKI module"
        try {
            Import-Module PSPKI -Force
        } catch {
            Write-Output "Warning: PSPKI module not available, continuing with basic functionality"
        }

        # Get certificate from key vault
        $cert = $null
        try {
            $cert = Get-AzKeyVaultCertificate -VaultName $VaultName -name $ObjectName
            $SubjectName = $cert.Certificate.Subject
            $IssuerName = $cert.Certificate.Issuer
            $Recipient = $cert.Tags.recipient
            Write-Output "Certificate retrieved successfully"
            Write-Output "SubjectName = $SubjectName"
            Write-Output "IssuerName = $IssuerName"
        } catch {
            Write-Output "Error getting certificate from Key Vault: $($_.Exception.Message)"
            $continue = $false
        }
        
        if ($cert -eq $null) {
            Write-Output "Error: Certificate is null from Key Vault $VaultName"           
            $continue = $false
        }

        # Enhanced OID extraction with multiple fallbacks
        $oid = $null
        if ($continue) {
            Write-Output "=== Enhanced OID Extraction ==="
            
            # Method 1: Try standard template extensions
            $templateExtensions = $cert.Certificate.Extensions | Where-Object { 
                $_.Oid.Value -eq "1.3.6.1.4.1.311.20.2" -or $_.Oid.Value -eq "1.3.6.1.4.1.311.21.7" 
            }
            
            if ($templateExtensions) {
                Write-Output "Found template extension, extracting OID..."
                foreach ($ext in $templateExtensions) {
                    $temp = $ext.Format(0)
                    Write-Output "Extension data: $temp"
                    
                    # Try various extraction patterns
                    if ($temp -match '\((.*?)\)') {
                        $oid = $matches[1]
                        Write-Output "OID extracted from parentheses: $oid"
                        break
                    }
                    elseif ($temp -match 'Template=([\d.]+)') {
                        $oid = $matches[1]
                        Write-Output "OID extracted from Template= pattern: $oid"
                        break
                    }
                    elseif ($temp -split "," -and ($temp -split ",")[0] -split "=" -and ($temp -split ",")[0] -split "=").Count -gt 1) {
                        $split = $temp -split ","
                        $template = $split[0]
                        $templateSplit = $template -split "="
                        if ($templateSplit.Count -gt 1) {
                            $oid = $templateSplit[1]
                            Write-Output "OID extracted from split method: $oid"
                            break
                        }
                    }
                }
            } else {
                Write-Output "No template extensions found in certificate"
            }
            
            # Method 2: Check if certificate has known template names in subject
            if ([string]::IsNullOrEmpty($oid)) {
                Write-Output "Attempting template detection from certificate properties..."
                
                # Common template patterns
                if ($SubjectName -match "webserver|web|iis|www") {
                    $oid = "WebServer"
                    Write-Output "Template detected from subject (web): $oid"
                }
                elseif ($SubjectName -match "machine|computer|workstation") {
                    $oid = "Machine"
                    Write-Output "Template detected from subject (machine): $oid"
                }
                elseif ($SubjectName -match "user|person") {
                    $oid = "User"
                    Write-Output "Template detected from subject (user): $oid"
                }
            }
            
            # Method 3: Use automation variable for default template
            if ([string]::IsNullOrEmpty($oid)) {
                Write-Output "Using default template from automation variables..."
                try {
                    $defaultTemplate = Get-AutomationVariable -Name 'DefaultCertificateTemplate' -ErrorAction SilentlyContinue
                    if ($defaultTemplate) {
                        $oid = $defaultTemplate
                        Write-Output "Default template from automation variable: $oid"
                    }
                } catch {
                    Write-Output "Could not retrieve default template variable"
                }
            }
            
            # Method 4: Hard-coded fallback
            if ([string]::IsNullOrEmpty($oid)) {
                $oid = "WebServer"
                Write-Output "Using hard-coded fallback template: $oid"
            }
            
            Write-Output "=== Final OID Decision: $oid ==="
        }

        # Enhanced certificate request with better error handling
        if ($continue) {
            Write-Output "=== Certificate Request Process ==="
            
            # Check if existing CSR is present
            $result = Get-AzKeyVaultCertificateOperation -VaultName $VaultName -Name $ObjectName | Where-Object {$_.Status -eq "inProgress"}
            $CSR = $result.CertificateSigningRequest

            if ($CSR -eq $null) {
                Write-Output "Generating new CSR in Key Vault..."
                try {
                    $Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName $SubjectName -IssuerName "Unknown" -ReuseKeyOnRenewal
                    $result = Add-AzKeyVaultCertificate -VaultName $VaultName -Name $ObjectName -CertificatePolicy $Policy
                    $CSR = $result.CertificateSigningRequest
                    Write-Output "CSR generated successfully"
                } catch {
                    Write-Output "Error generating CSR in Key Vault: $($_.Exception.Message)"
                    $continue = $false
                }
            } else {
                Write-Output "Using existing CSR"
            }
        }

        # Enhanced CA interaction
        if ($continue) {
            Write-Output "=== Internal CA Commands ==="
            
            try {
                $CAServer = Get-AutomationVariable -Name 'CAServer'
                if ([string]::IsNullOrEmpty($CAServer)) {
                    $CAServer = "ca01.demo.com"  # Fallback
                    Write-Output "Using fallback CA server: $CAServer"
                } else {
                    Write-Output "Using configured CA server: $CAServer"
                }
            } catch {
                $CAServer = "ca01.demo.com"
                Write-Output "Using default CA server: $CAServer"
            }

            # Create a temporary file
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $CSR

            # Enhanced certificate request with proper error handling
            try {
                Write-Output "Connecting to CA: $CAServer"
                $CA = Get-CertificationAuthority -ComputerName $CAServer
                
                Write-Output "Submitting certificate request with template: $oid"
                $requestCommand = "Submit-CertificateRequest -CA $CAServer -Path $tempFile -Attribute `"CertificateTemplate:$oid`""
                Write-Output "Request command: $requestCommand"
                
                $certificateRequest = Submit-CertificateRequest -CA $CA -Path $tempFile -Attribute "CertificateTemplate:$($oid)"
                $certificate = $certificateRequest.Certificate
                
                if ($certificate) {
                    Write-Output "✅ Certificate issued successfully"
                    Write-Output "Certificate details: $certificateRequest"
                } else {
                    Write-Output "❌ Certificate issuance returned null"
                    $continue = $false
                }
                
            } catch {
                Write-Output "❌ Error issuing certificate from PKI: $($_.Exception.Message)"
                Write-Output "CA Server: $CAServer"
                Write-Output "Template: $oid"
                Write-Output "Temp file: $tempFile"
                $continue = $false
            }
        }

        # Enhanced certificate import and cleanup
        if ($continue) {
            Write-Output "=== Certificate Import Process ==="
            
            try {
                # Export certificate to temporary file
                Export-Certificate -Cert $certificate -FilePath $tempFile
                Write-Output "Certificate exported to temporary file"

                # Import the new certificate to Key Vault
                $newCert = Import-AzKeyVaultCertificate -VaultName $VaultName -Name $ObjectName -FilePath $tempFile 
                Write-Output "✅ Certificate imported to Key Vault successfully"
                
                # Clean up temporary file
                Remove-Item -Path $tempFile -Force
                Write-Output "Temporary file cleaned up: $tempFile"
                
            } catch {
                Write-Output "❌ Error importing certificate to Key Vault: $($_.Exception.Message)"
                $continue = $false
            }
        }

        # Enhanced notification system with fallbacks
        if ($continue) {
            Write-Output "=== Email Notification Process ==="
            
            if ([string]::IsNullOrEmpty($Recipient)) {
                try {
                    $Recipient = Get-AutomationVariable -Name 'DefaultEmailRecipient' -ErrorAction SilentlyContinue
                    Write-Output "Using default email recipient: $Recipient"
                } catch {
                    $Recipient = "admin@MngEnv829153.onmicrosoft.com"
                    Write-Output "Using fallback email recipient: $Recipient"
                }
            }
            
            if (-not [string]::IsNullOrEmpty($Recipient)) {
                try {
                    # Update certificate tags
                    $tag = @{recipient = $Recipient}
                    $newCert | Update-AzKeyVaultCertificate -Tag $tag
                    
                    # Email configuration
                    $MailDate = Get-Date -format "dd/MM/yyyy"
                    
                    try {
                        $SmtpServer = Get-AutomationVariable -Name 'SMTPserver'
                        if ([string]::IsNullOrEmpty($SmtpServer)) {
                            $SmtpServer = "ca01.demo.com"
                        }
                    } catch {
                        $SmtpServer = "ca01.demo.com"
                    }
                    
                    Write-Output "SMTP Server: $SmtpServer"
                    Write-Output "Recipient: $Recipient"
                    
                    $EmailFrom = "Certificate LifeCycle Automation <clc@demo.com>"
                    $Recipient = $Recipient.Replace(";",",")
                    $Recipient = $Recipient.Split(",")
                    $EmailSubject = "Certificate $ObjectName renewed successfully"
                    
                    # Simple email body
                    $EmailBody = @"
Certificate Lifecycle Automation - Certificate Update Notification

Updated Certificate: $ObjectName
New Expiration Time: $($newCert.certificate.NotAfter.ToString("dd/MM/yyyy HH:mm:ss"))
Renewal Date: $MailDate

This certificate has been successfully renewed through the automated certificate lifecycle management system.
"@
                    
                    # Send email with enhanced error handling
                    try {
                        Send-MailMessage -To $Recipient -From $EmailFrom -Subject $EmailSubject -Body $EmailBody -SmtpServer $SmtpServer
                        Write-Output "✅ Email notification sent successfully"
                    } catch {
                        Write-Output "⚠️ Email notification failed, but certificate renewal completed: $($_.Exception.Message)"
                        # Don't fail the entire process for email issues
                    }
                    
                } catch {
                    Write-Output "⚠️ Email notification setup failed: $($_.Exception.Message)"
                }
            } else {
                Write-Output "No email recipient configured, skipping notification"
            }
        }

        # Remove message from queue if applicable
        if ($queuedMessage) {
            try {
                $queuedMessage.Result.DeleteMessage()
                Write-Output "Queue message removed successfully"
            } catch {
                Write-Output "Warning: Could not remove queue message: $($_.Exception.Message)"
            }
        }

        if ($continue) {
            Write-Output "🎉 Certificate lifecycle workflow completed successfully!"
            Write-Output "Certificate: $ObjectName"
            Write-Output "Key Vault: $VaultName"
            Write-Output "Template: $oid"
            Write-Output "CA Server: $CAServer"
        } else {
            Write-Output "❌ Certificate lifecycle workflow encountered errors"
        }
        
        Write-Output "=== Enhanced Certificate Lifecycle Workflow Complete ==="
    } else {
        Write-Output "❌ No webhook data provided"
    }
}

# Main execution logic (unchanged from original)
$environmentVariable = Get-ChildItem env:
$HybridWorker = ($environmentVariable | Where-Object { $_.name -like 'Fabric_*' } ).count -eq 0

$ErrorActionPreference = "Continue"

if ($HybridWorker) {   
    Write-Output "Running on Hybrid Worker with Enhanced Certificate Lifecycle Management"
    
    $continue = $true

    # Connect to Azure
    Write-Output "Connect to Azure"
    try {
        Connect-AzAccount -Identity
    } catch {
        Write-Output "Error connecting to Azure: $($_.Exception.Message)"
        $continue = $false
    }

    if ($continue) {
        # Get Storage Account Queue Context
        try {
            $storageAccountName = Get-AutomationVariable -Name 'StorageAccount'
            $resourceGroup = Get-AutomationVariable -Name 'resourceGroup'
            $queueName = "certlc"

            $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
            Write-Output "Storage context established: $storageAccountName"
        } catch {
            Write-Output "Warning: Storage account setup failed: $($_.Exception.Message)"
            # Continue anyway for direct webhook processing
        }
    }
    
    if ($continue) {
        # Check for direct webhook data first
        if ($WebhookData) {
            Write-Output "Processing direct webhook data"
            Enhanced-CertLCWorkflow -WebhookData $WebhookData
        } else {
            # Fallback to queue processing
            Write-Output "No direct webhook data, checking queue..."
            
            if ($ctx) {
                try {
                    Start-Sleep -Seconds 5
                    $queue = Get-AzStorageQueue -Name $queueName -Context $ctx
                    $invisibleTimeout = [System.TimeSpan]::FromSeconds(1)
                    Write-Output "Queued messages: $($queue.ApproximateMessageCount)"

                    for ($i = 1; $i -le $queue.ApproximateMessageCount; $i++) {
                        $queuedMessage = $queue.CloudQueue.GetMessageAsync($invisibleTimeout,$null,$null)
                        $webhookDataFromQueue = $queuedMessage.Result.AsString
                        Write-Output "Processing queued webhook data: $webhookDataFromQueue"
                        Enhanced-CertLCWorkflow -WebhookData $webhookDataFromQueue -queuedMessage $queuedMessage
                    }
                } catch {
                    Write-Output "Queue processing failed: $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Output "Enhanced Certificate Lifecycle Management - End"
} else {
    Write-Output "ERROR: This script must be run from an Azure Automation Hybrid Worker"        
    Write-Output "To install a Hybrid Worker please read:"
    Write-Output "https://docs.microsoft.com/azure/automation/automation-hybrid-runbook-worker#install-the-hybrid-runbook-worker"
}