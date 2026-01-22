Write-Host "Quick Arc Agent Fix" -ForegroundColor Green
$agent = "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe"
if (Test-Path $agent) {
    Write-Host "Disconnecting..." -ForegroundColor Yellow
    & $agent disconnect --force-local-only
    Write-Host "Reconnecting..." -ForegroundColor Yellow  
    & $agent connect --resource-group "rg-demo-certlc" --tenant-id "b7e530b3-a1e1-465c-b820-dfddb9e77e7d" --location "westus3" --subscription-id "f8c6ec45-4437-4670-80b1-cc3cb09c3ce0"
    Write-Host "Restarting services..." -ForegroundColor Yellow
    Restart-Service himds -Force
    Write-Host "Done!" -ForegroundColor Green
} else {
    Write-Host "Arc agent not found!" -ForegroundColor Red
}
