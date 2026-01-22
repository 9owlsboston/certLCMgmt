# Configuration Loader for Hybrid Worker Scripts
# This script loads configuration from .env file

function Get-CertLCConfig {
    param(
        [Parameter(Mandatory=$false)]
        [string]$EnvFilePath = "../.env"
    )
    
    $config = @{}
    
    # Check if .env file exists
    if (-not (Test-Path $EnvFilePath)) {
        Write-Warning ".env file not found at $EnvFilePath"
        return $null
    }
    
    try {
        # Read .env file
        $envContent = Get-Content $EnvFilePath -ErrorAction Stop
        
        foreach ($line in $envContent) {
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                continue
            }
            
            # Parse key=value pairs
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                
                $config[$key] = $value
            }
        }
        
        Write-Host "✅ Configuration loaded from .env file" -ForegroundColor Green
        Write-Host "Resource Group: $($config['RESOURCE_GROUP'])" -ForegroundColor Gray
        Write-Host "Subscription: $($config['SUBSCRIPTION_ID'])" -ForegroundColor Gray
        Write-Host "Automation Account: $($config['AUTOMATION_ACCOUNT_NAME'])" -ForegroundColor Gray
        
        return $config
    }
    catch {
        Write-Error "Failed to load configuration from .env file: $($_.Exception.Message)"
        return $null
    }
}

# Export the function
Export-ModuleMember -Function Get-CertLCConfig