# Certificate Lifecycle Management - Deployment Commands

## Required Parameters

Before deploying, you need to provide these **mandatory** parameters:

- `DomainAdminPassword` - Password for the Active Directory domain administrator
- `CaAdminPassword` - Password for the certificate authority administrator  
- `UNIQUESTRING` - Unique string for naming resources (use your initials + random numbers)

## Azure CLI Deployment

### 1. Set Variables
```bash
# Set your deployment variables
RESOURCE_GROUP="rg-certlc-demo"
LOCATION="eastus"
DEPLOYMENT_NAME="certlc-deployment-$(date +%Y%m%d-%H%M%S)"
# NOTE: These commands originally referenced ARM templates from the Microsoft repository
# To use these commands, first clone the official repository:
# git clone https://github.com/Azure-Samples/certificate-lifecycle-management.git

TEMPLATE_FILE="./certificate-lifecycle-management/.armtemplate/fulllabdeploy.json"
UNIQUE_STRING="abc123"  # Replace with your unique string
DOMAIN_ADMIN_PASSWORD="YourSecurePassword123!"  # Replace with secure password
CA_ADMIN_PASSWORD="YourSecurePassword456!"      # Replace with secure password
RECIPIENT_EMAIL="your.email@company.com"        # Replace with your email
```

### 2. Create Resource Group (if needed)
```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### 3. Validate Deployment (Recommended)
```bash
az deployment group validate \
    --resource-group $RESOURCE_GROUP \
    --template-file $TEMPLATE_FILE \
    --parameters \
        DomainAdminPassword=$DOMAIN_ADMIN_PASSWORD \
        CaAdminPassword=$CA_ADMIN_PASSWORD \
        UNIQUESTRING=$UNIQUE_STRING \
        Recipient=$RECIPIENT_EMAIL
```

### 4. Preview Changes (What-If)
```bash
az deployment group what-if \
    --resource-group $RESOURCE_GROUP \
    --template-file $TEMPLATE_FILE \
    --parameters \
        DomainAdminPassword=$DOMAIN_ADMIN_PASSWORD \
        CaAdminPassword=$CA_ADMIN_PASSWORD \
        UNIQUESTRING=$UNIQUE_STRING \
        Recipient=$RECIPIENT_EMAIL
```

### 5. Deploy
```bash
az deployment group create \
    --name $DEPLOYMENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --template-file $TEMPLATE_FILE \
    --parameters \
        DomainAdminPassword=$DOMAIN_ADMIN_PASSWORD \
        CaAdminPassword=$CA_ADMIN_PASSWORD \
        UNIQUESTRING=$UNIQUE_STRING \
        Recipient=$RECIPIENT_EMAIL
```

## PowerShell Deployment

### 1. Set Variables
```powershell
# Set your deployment variables
$ResourceGroupName = "rg-certlc-demo"
$Location = "East US"
$DeploymentName = "certlc-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
# NOTE: Update path to point to cloned Microsoft repository
$TemplateFile = "./certificate-lifecycle-management/.armtemplate/fulllabdeploy.json"
$UniqueString = "abc123"  # Replace with your unique string
$DomainAdminPassword = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
$CaAdminPassword = ConvertTo-SecureString "YourSecurePassword456!" -AsPlainText -Force
$RecipientEmail = "your.email@company.com"  # Replace with your email
```

### 2. Create Resource Group (if needed)
```powershell
New-AzResourceGroup -Name $ResourceGroupName -Location $Location
```

### 3. Validate Deployment
```powershell
Test-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFile `
    -DomainAdminPassword $DomainAdminPassword `
    -CaAdminPassword $CaAdminPassword `
    -UNIQUESTRING $UniqueString `
    -Recipient $RecipientEmail
```

### 4. Deploy
```powershell
New-AzResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFile `
    -DomainAdminPassword $DomainAdminPassword `
    -CaAdminPassword $CaAdminPassword `
    -UNIQUESTRING $UniqueString `
    -Recipient $RecipientEmail
```

## Resources Created

This template will create:
- **Virtual Network** with Domain Controller and Certificate Authority VMs
- **Key Vault** for certificate storage
- **Event Grid** for certificate expiration notifications
- **Storage Account** for queuing certificate information
- **Automation Account** with runbooks and hybrid worker
- **Log Analytics Workspace** for monitoring
- **Azure Workbook** for certificate lifecycle dashboard

## Important Notes

1. **Deployment Time**: Expect ~30 minutes for complete deployment
2. **Unique Naming**: Use a unique string for globally unique resources
3. **Passwords**: Use strong passwords meeting Azure complexity requirements
4. **Permissions**: Requires Owner role on the subscription
5. **Region**: Choose a region that supports all required services

## Post-Deployment

After deployment completes:
1. Check the Azure Portal for all created resources
2. Verify VMs are running and domain services are configured
3. Test certificate renewal workflow
4. Review the Azure Workbook dashboard for certificate status