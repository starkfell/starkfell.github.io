<#

.SYNOPSIS
This script deploys a new Azure Automation Account and all required deployment Resources to a specific Azure Subscription.

.DESCRIPTION
This Script must be executed using an Account that is either a Co-Administrator or an Azure Organizational Account to the Subscription that
is being targeted. Additionally, Azure PowerShell 1.0 or higher is required.

Once this script is launched and the user is logged in, the following actions will occur:

- Resource Groups are created for:
  - An Azure Key Vault.
  - A Storage Account to hold deployment resources.
  - An Azure Automation Account.
- A GUID is generated to give all deployed resources a Unique Name or ID that require it.
- The Azure Key Vault Name is modified and appended with the first 4-digits from the generated GUID.
- A New Azure Key Vault is created.
- The Local Administrator Credentials are added to the Azure Key Vault.
- The Active Directory Domin Administrator Credentials are added to the Azure Key Vault.
- A New Azure Automation Account is created.
- The first 4-digits from the generated GUID are added to the Azure Automation Account as a Variable Asset called 'DeploymentID'.
- The Azure Automation Account Primary Key is added to the Azure Key Vault.
- The Azure Automation Account Registration URL is added to the Azure Key Vault.
- The 'AzureRunAsConnection' and 'AzureRunAsCertificate' are generated and added to the Azure Automation Account.
- The Azure Storage Account Name is modified and appended with the first 4-digits from the generated GUID.
- A New Azure Storage Account is created for storing all the Resources listed in the Storage Containers below.
- A New Storage Container is created for the Scripts.
- A New Storage Container is created for the DSC Resources.
- A New Storage Container is created for the ARM Templates.
- A New Storage Container is created for the ARM Template Deployments.
- The Scripts from the 'arm-powershell-scripts' directory are uploaded to the Storage Container for Scripts.
- The URL Location of the copy-tags-and-trigger-runbook.ps1 Script is added to the Azure Key Vault.
- The DSC Modules from the 'azure-automation-dsc-modules' directory are uploaded to the Storage Container for DSC Modules.
- The DSC Modules are added to the Azure Automation Account and then extracted.
- The ARM Template DSC Modules from the 'arm-deployment-dsc-modules' directory are uploaded to the Storage Container for DSC Modules.
- The URL Location of the 'LumaAzureAutomationRegistration.zip' DSC Module is added to the Azure Key Vault.
- The Files located in the '\arm-templates\staging' directory are copied to the '\arm-templates\production' directory.
- The ARM Template Parameters File(s) in the '\arm-templates\production' directory are modified to have the correct:
  - Key Vault Name
  - Key Vault Resource Group
  - Subscription ID.
- The ARM Template Files in the '\arm-templates\production' directory are uploaded to the Azure Storage Container for ARM Templates.
  - The default value of this Azure Storage Container is 'arm-templates'.
- The Contents of '\arm-templates\production' directory are deleted.
- The Active Directory Domain Administrator Credentials are added to the Azure Automation Account as a Credential Asset.
- The Azure Runbooks located in the 'azure-automation-runbooks' directory are imported into the Azure Automation Account.
- Webhooks for each of the Azure Runbooks are generated and then added to the Azure Key Vault.
  - The default expiration date of the Webhooks is 1 year.
- The DSC Configuration Files from the 'azure-automation-dsc-configs' are imported into the Azure Automation Account and then compiled.

This script has been designed to allow all of the resources that are deployed to work and not interfere with an existing 
Azure Subscription that already has an Azure Automation Account and Azure Key Vault in place.

.PARAMETER SubscriptionId
The ID of the Azure Subscription you are deploying to, i.e. - 838f045f5-e37a-5156-8e82-0c1ecd17a682

.PARAMETER CopyTagsAndTriggerRunbookPSScriptName
The Name of the PowerShell Script that is responsible for copying specified VM Tags to the VMs being deployed via ARM Template 
and then triggering the Azure Automation Runbook responsible for registering the VM with its respective DSC Node Configuration 
in the Azure Automation Account.

.PARAMETER LumaAzureAutomationRegistrationDSCModuleName
The Name of the DSC Module that is responsible for registering VMs being deployed via ARM Template with the Azure Automation
Account as a DSC Node.

.PARAMETER AzureAutomationResourceGroupName
The Name of the Resource Group where the Azure Automation Account will reside.

.PARAMETER AzureAutomationAccountName
The Name of the Azure Automation Account.

.PARAMETER AzureAutomationPricingTier
The Azure Automation Pricing Tier you want to use. The two options are 'Free' and 'Basic'.

.PARAMETER AzureAutomationCertificatePassword
The Password you want to use to create the AzureRunAsConnection Assets in the Azure Automation Account. 

.PARAMETER KeyVaultResourceGroupName
The Name of the Resource Group that will be storing the Azure Key Vault.

.PARAMETER KeyVaultName
The Name of the Azure Key Vault.

.PARAMETER LocalAdminUsername
The Local Administrator Username that will be used by default in VM Deployments. This value is added to the Azure Key Vault.

.PARAMETER LocalAdminPassword
The Local Administrator Password that will be used by default in VM Deployments. This value is added to the Azure Key Vault.

.PARAMETER ADDomainAdminUsername
The Active Directory Domain Administrator Username that will be used by default in VM Deployments. This value is added to the Azure Key Vault.

.PARAMETER ADDomainAdminPassword
The Active Directory Domain Administrator Password that will be used by default in VM Deployments. This value is added to the Azure Key Vault.

.PARAMETER Location
The Location where all resources will be deployed, i.e. westeurope, northeurope, eastus, etc...

.NOTES
Filename:   deploy-azure-automation-for-nano-server.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

.EXAMPLE          
./deploy-azure-automation-for-nano-server.ps1 `
-SubscriptionId 84f065f5-e37a-4127-9c82-0b1ecd57a652 `
-AzureAutomationResourceGroupName nano-automation `
-AzureAutomationAccountName nano-automation `
-AzureAutomationPricingTier Free `
-AzureAutomationCertificatePassword AlwaysOn! `
-KeyVaultResourceGroupName nano-key-vault `
-KeyVaultName nanokeyvault `
-LocalAdminUsername winadmin `
-LocalAdminPassword AlwaysOn! `
-NanoServerCertificateName nanoservers.lumagate.com `
-NanoServerCertificatePassword AlwaysOn! `
-Location westeurope

#>

param
(
    [Parameter(Mandatory)]
    [String]$SubscriptionId,

    [Parameter(Mandatory)]
    [String]$AzureAutomationResourceGroupName,

    [Parameter(Mandatory)]
    [String]$AzureAutomationAccountName,

    [Parameter(Mandatory)]
    [String]$AzureAutomationPricingTier,

    [Parameter(Mandatory)]
    [String]$AzureAutomationCertificatePassword,

    [Parameter(Mandatory)]
    [String]$KeyVaultResourceGroupName,

    [Parameter(Mandatory)]
    [String]$KeyVaultName,

    [Parameter(Mandatory)]
    [String]$LocalAdminUsername,

    [Parameter(Mandatory)]
    [String]$LocalAdminPassword,

    [Parameter(Mandatory)]
    [String]$NanoServerCertificateName,

    [Parameter(Mandatory)]
    [String]$NanoServerCertificatePassword,

	[Parameter(Mandatory)]
    [String]$Location
)


# Logging into an Azure Subscription.
Add-AzureRMAccount `
    -Verbose:$false `
    -ErrorAction SilentlyContinue `
    -ErrorVariable LoginError | Out-Null

If (!$LoginError)
{
    Write-Output "Successfully logged into Azure (ARM)."
}

If ($LoginError)
{
	Write-Output "Failed to log into Azure (ARM)."
    Write-Output $LoginError.Exception
    exit 2
}

# Selecting the Azure Subscription to work with.
Select-AzureRmSubscription -SubscriptionId $SubscriptionId | OUt-Null
If ($?)
{
    Write-Output "Successfully set to work with Subscription ID: $SubscriptionId."
}

If (!$?)
{
	Write-Error -Message "Failed to associate with Subscription ID: $SubscriptionId."
    exit 2
}

# Creating a New Azure Resource Group for the Azure Key Vault.
New-AzureRmResourceGroup -Name $KeyVaultResourceGroupName -Location $Location -WarningAction SilentlyContinue | Out-Null
If ($?)
{
    Write-Output "Successfully created a new Resource Group for the Azure Key Vault: $KeyVaultResourceGroupName."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Resource Group for the Azure Key Vault."
    exit 2
}

# Creating a New Azure Resource Group for the Azure Automation Account.
New-AzureRmResourceGroup -Name $AzureAutomationResourceGroupName -Location $Location -WarningAction SilentlyContinue | Out-Null
If ($?)
{
    Write-Output "Successfully created a new Resource Group for the Azure Automation Account: $AzureAutomationResourceGroupName."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Resource Group for the Azure Automation Account."
    exit 2
}

# Generating a Guid and utilizing the first four characters to append to all of the resources being deployed that require a Unique Name or ID.
$Guid = [guid]::NewGuid().ToString()
$Guid = $Guid.Substring(0,$_.length+4)
If ($?)
{
    Write-Output "Successfully generated new Guid and retrieved the first 4 characters from it."
}

If (!$?)
{
	Write-Error -Message "Failed to generate a new Guid and retrieve the first 4 characters from it."
    exit 2
}

# Changing the new Azure Key Vault Name to have the first four characters generated from the Guid appended to the end of it. 
$KeyVaultName = "$KeyVaultName" + "$Guid"
If ($?)
{
    Write-Output "New Azure Key Vault Name created: $KeyVaultName."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Azure Key Vault Name from the generated guid: $KeyVaultName."
    exit 2
}

# Checking if the Key Vault already exists before attempting to create a new one.
$CheckForExistingVault = Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroupName -ErrorAction SilentlyContinue

If ($CheckForExistingVault)
{
	Write-Output "$KeyVaultName already exists in $KeyVaultResourceGroupName. Skipping Key Vault creation."
}

If (!$CheckForExistingVault)
{
	Write-Output "$KeyVaultName not found in $KeyVaultResourceGroupName. Creating new Key Vault."

	# Creating the new Azure Key Vault and enabling it for Standard and Template Deployments.
	New-AzureRmKeyVault `
        -VaultName $KeyVaultName `
        -ResourceGroupName $KeyVaultResourceGroupName `
        -Location $Location `
        -EnabledForDeployment `
        -EnabledForTemplateDeployment `
        -Sku Premium | Out-Null

	If ($?)
	{
		Write-Output "Successfully created new Azure Key Vault: $KeyVaultName."
        Start-Sleep -Seconds 5
	}

	If (!$?)
	{
		Write-Error -Message "Failed to create new Azure Key Vault: $KeyVaultName."
		exit 2
	}		
}

# Converting the Local Administrator Credentials Key Vault Name to lowercase.
$LocalAdminUsernameSecretName = ($LocalAdminUsername).ToLower()

# Converting Local Administrator Credentials to Secure Strings before adding them into the Azure Key Vault.
$LocalAdminUsernameSecretValue = ConvertTo-SecureString -String $LocalAdminUsername -AsPlainText -Force
$LocalAdminPasswordSecretValue = ConvertTo-SecureString -String $LocalAdminPassword -AsPlainText -Force

# Adding the Local Administrator Credentials into the Azure Key Vault.
Set-AzureKeyVaultSecret `
    -VaultName $KeyVaultName `
    -Name "$($LocalAdminUsernameSecretName)-username" `
    -SecretValue $LocalAdminUsernameSecretValue | Out-Null

If ($?)
{
    Write-Output "$($LocalAdminUsernameSecretName)-username Successfully Added to Azure Key Vault: $KeyVaultName."
}

If (!$?)
{
	Write-Error -Message "Failed to add $($LocalAdminUsernameSecretName)-username to Azure Key Vault: $KeyVaultName."
    exit 2
}

Set-AzureKeyVaultSecret `
    -VaultName $KeyVaultName `
    -Name "$($LocalAdminUsernameSecretName)-password" `
    -SecretValue $LocalAdminPasswordSecretValue | Out-Null

If ($?)
{
    Write-Output "$($LocalAdminUsernameSecretName)-password Successfully Added to Azure Key Vault: $KeyVaultName."
}

If (!$?)
{
	Write-Error -Message "Failed to add $($LocalAdminUsernameSecretName)-password to Azure Key Vault: $KeyVaultName."
    exit 2
}

# Create a new Azure Automation Account.
New-AzureRmAutomationAccount -ResourceGroupName $AzureAutomationResourceGroupName -Name $AzureAutomationAccountName -Plan $AzureAutomationPricingTier -Location $Location | Out-Null
If ($?)
{
    Write-Output "Successfully created a new Azure Automation Account: $AzureAutomationAccountName."
    Start-Sleep -Seconds 5
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Azure Automation Account."
    exit 2
}

# Adding the 4 characters generated from the Guid to the Azure Automation Account as a Variable Asset called 'DeploymentID'.
New-AzureRmAutomationVariable `
    -AutomationAccountName $AzureAutomationAccountName `
    -ResourceGroupName $AzureAutomationResourceGroupName `
    -Name "DeploymentID" `
    -Encrypted $false `
    -Description "This is the value generated from a GUID that was used to deploy the Azure Automation Account and its related resources." `
    -Value $Guid

If ($?)
{
    Write-Output "Successfully added the 'DeploymentID' Variable with a value of [$Guid] to the Assets of the Azure Automation Account: $AzureAutomationAccountName."
}

If (!$?)
{
	Write-Error -Message "Failed to add the 'DeploymentID' Variable with a value of [$Guid] to the Assets of the Azure Automation Account: $AzureAutomationAccountName."
    exit 2
}

# Converting the Azure Automation Account Primary Key into a Secure String.
$PrimaryKey = (Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $AzureAutomationResourceGroupName -AutomationAccountName $AzureAutomationAccountName).PrimaryKey
$SecurePrimaryKey = ConvertTo-SecureString -String $PrimaryKey -AsPlainText -Force

# Adding the Azure Automation Account Primary Key to the Azure Key Vault.
Set-AzureKeyVaultSecret `
    -VaultName $KeyVaultName `
    -Name "$($AzureAutomationAccountName)-primary-key" `
    -SecretValue $SecurePrimaryKey | Out-Null

If ($?)
{
    Write-Output "$($AzureAutomationAccountName)-primary-key Successfully Added to Azure Key Vault: $KeyVaultName."
}

If (!$?)
{
	Write-Error -Message "Failed to add $($AzureAutomationAccountName)-primary-key to Azure Key Vault: $KeyVaultName."
    exit 2
}

# Converting the Azure Automation Account Registration URL into a Secure String.
$RegistrationURL = (Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $AzureAutomationResourceGroupName -AutomationAccountName $AzureAutomationAccountName).Endpoint
$SecureRegistrationURL = ConvertTo-SecureString -String $RegistrationURL -AsPlainText -Force

# Adding the Azure Automation Account Registration URL to the Azure Key Vault.
Set-AzureKeyVaultSecret `
    -VaultName $KeyVaultName `
    -Name "$($AzureAutomationAccountName)-registration-url" `
    -SecretValue $SecureRegistrationURL | Out-Null

If ($?)
{
    Write-Output "$($AzureAutomationAccountName)-registration-url Successfully Added to Azure Key Vault: $KeyVaultName."
}

If (!$?)
{
	Write-Error -Message "Failed to add $($AzureAutomationAccountName)-registration-url to Azure Key Vault: $KeyVaultName."
    exit 2
}

# Creating an End Date, GUID, and generating a naming convention for the new Self-Signed Certificate being created.
$CurrentDate = Get-Date
$EndDate = $CurrentDate.AddMonths(12)
$KeyId = (New-Guid).Guid
$CertPath = Join-Path $env:TEMP ($AzureAutomationAccountName + ".pfx")

# Creating a new Self-Signed Certificate.
$Cert = New-SelfSignedCertificate `
    -DnsName $AzureAutomationAccountName `
    -CertStoreLocation cert:\LocalMachine\My `
    -KeyExportPolicy Exportable `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider"

If ($?)
{
    Write-Output "New Self-Signed Certificate Created Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Self-Signed Certificate."
    exit 2
}

# Changing the Azure Automation Certificate Password to a Secure String.
$SecuredCertificatePassword = ConvertTo-SecureString $AzureAutomationCertificatePassword -AsPlainText -Force

# Exporting the Self-Signed Certificate with the Azure Automation Certificate Password.
Export-PfxCertificate `
    -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) `
    -FilePath $CertPath `
    -Password $SecuredCertificatePassword `
    -Force

If ($?)
{
    Write-Output "Exported the new Self-Signed Certificate Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to export the new Self-Signed Certificate."
    exit 2
}

# Creating a new X509 Certificate.
$PFXCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @($CertPath, $AzureAutomationCertificatePassword)

If ($?)
{
    Write-Output "New X509 Certificate Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new X509 Certificate."
    exit 2
}

# Converting the X509 Certificate Raw Data to Base64.
$KeyValue = [System.Convert]::ToBase64String($PFXCert.GetRawCertData())

# Creating the Key Credentials used to create a new Azure AD Application.
$KeyCredential           = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADKeyCredential
$KeyCredential.StartDate = $CurrentDate
$KeyCredential.EndDate   = $EndDate
$KeyCredential.KeyId     = $KeyId
$KeyCredential.Type      = "AsymmetricX509Cert"
$KeyCredential.Usage     = "Verify"
$KeyCredential.Value     = $KeyValue

# Use the Key Credentials to create a new Azure AD Application.
$Application = New-AzureRmADApplication `
    -DisplayName $AzureAutomationAccountName `
    -HomePage ("http://" + $AzureAutomationAccountName) `
    -IdentifierUris ("http://" + $KeyId) `
    -KeyCredentials $KeyCredential

If ($?)
{
    Write-Output "New Azure AD Application Successfully using the Key Credentials from the X509 Certificate."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Azure AD Application Successfully using the Key Credentials from the X509 Certificate."
    exit 2
}

# Creating a new Azure AD Service Principal.
New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId

If ($?)
{
    Write-Output "New Azure AD Service Principal created Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Azure AD Service Principcal."
    exit 2
}

# Retrieving the new Azure AD Service Principal.
Get-AzureRmADServicePrincipal | Where-Object {$_.ApplicationId -eq $Application.ApplicationId}

# Adding the new AD Service Principcal to the Contributor Role.
Write-Output "Assigning the AD Service Principal to the Contributor Role and waiting for it to become active."
$NewRole = $null
$Retries = 0;

While (($NewRole -eq $null) -and ($Retries -le 6))
{
    # Allowing time for the Service Principal Application to become Active.
    Start-Sleep 5
    New-AzureRMRoleAssignment `
        -RoleDefinitionName Contributor `
        -ServicePrincipalName $Application.ApplicationId `
        -ErrorAction SilentlyContinue

    Start-Sleep 10
    $NewRole = Get-AzureRMRoleAssignment `
        -ServicePrincipalName $Application.ApplicationId `
        -ErrorAction SilentlyContinue

    $Retries++;
} 

Write-Output "AD Service Principcal successfully assigned to the Contributor Role and verified as active."

# Get the Tenant ID for this Subscription.
$SubscriptionInfo = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
$TenantID = $SubscriptionInfo | Select TenantId -First 1

# Create a new Azure Automation Certificate.
New-AzureRmAutomationCertificate `
    -ResourceGroupName $AzureAutomationResourceGroupName `
    -AutomationAccountName $AzureAutomationAccountName `
    -Path $CertPath `
    -Name AzureRunAsCertificate `
    -Password $SecuredCertificatePassword `
    -Exportable | Out-Null

If ($?)
{
    Write-Output "New Azure Automation Certificate Successfully created and added to the Azure Automation Account: $AzureAutomationAccountName."
}

If (!$?)
{
	Write-Error -Message "Failed to create and add a New Azure Automation Certificate to the Azure Automation Account: $AzureAutomationAccountName."
    exit 2
}

# Create a new Azure Automation Connection in the Azure Automation Account using the newly created Service Principal.
$ConnectionAssetName = "AzureRunAsConnection"

# Connection Field Values that relate to the newly created Service Principcal.
$ConnectionFieldValues = @{"ApplicationId" = $Application.ApplicationId; 
                            "TenantId" = $TenantID.TenantId; 
                            "CertificateThumbprint" = $Cert.Thumbprint; 
                            "SubscriptionId" = $SubscriptionId}

# Creating the new Azure Automation Connection.
New-AzureRmAutomationConnection `
    -ResourceGroupName $AzureAutomationResourceGroupName `
    -AutomationAccountName $AzureAutomationAccountName `
    -Name $ConnectionAssetName `
    -ConnectionTypeName AzureServicePrincipal `
    -ConnectionFieldValues $ConnectionFieldValues | Out-Null

If ($?)
{
    Write-Output "New Azure Automation Connection Succesfully created and added to the Azure Automation Account: $AzureAutomationAccountName."
}

If (!$?)
{
	Write-Error -Message "Failed to create and add a new Azure Automation Connection to the Azure Automation Account: $AzureAutomationAccountName."
    exit 2
}

# Creating an End Date, GUID, and generating a naming convention for the new Nano Server Self-Signed Certificate being created.
$CurrentDate = Get-Date
$EndDate = $CurrentDate.AddMonths(12)
$KeyId = (New-Guid).Guid
$NanoCertPath = Join-Path $env:TEMP ($NanoServerCertificateName + ".pfx")

# Creating a new Self-Signed Certificate for Nano Server.
$NanoCert = New-SelfSignedCertificate `
    -DnsName $NanoServerCertificateName `
    -CertStoreLocation cert:\LocalMachine\My `
    -KeyExportPolicy Exportable `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider"

If ($?)
{
    Write-Output "New Self-Signed Certificate Created Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to create a new Self-Signed Certificate."
    exit 2
}

# Changing the Nano Server Certificate Password to a Secure String.
$SecuredCertificatePassword = ConvertTo-SecureString $NanoServerCertificatePassword -AsPlainText -Force

# Exporting the Self-Signed Certificate with the Nano Server Certificate Password.
Export-PfxCertificate `
    -Cert ("Cert:\localmachine\my\" + $NanoCert.Thumbprint) `
    -FilePath $NanoCertPath `
    -Password $SecuredCertificatePassword `
    -Force

If ($?)
{
    Write-Output "Exported the new Nano Server Self-Signed Certificate Successfully."
}

If (!$?)
{
	Write-Error -Message "Failed to export the new Nano Server Self-Signed Certificate."
    exit 2
}

# Retrieving the contents of the Nano Server Certificate.
$FileName = $NanoCertPath
$FileContentBytes = Get-Content $FileName -Encoding Byte
$FileContentEncoded = [System.Convert]::ToBase64String($FileContentBytes)

# Converting the Nano Server Certificate data into a JSON Object.
$JSONObject = 
@"
{
"data": "$FileContentEncoded",
"dataType" :"pfx",
"password": "$NanoServerCertificatePassword"
}
"@

$JSONObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($JSONObject)
$JSONEncoded = [System.Convert]::ToBase64String($JSONObjectBytes)

# Converting the Nano Server Certificate JSON Object into a secure string.
$NanoServerCertificateSecretValue = ConvertTo-SecureString -String $JSONEncoded -AsPlainText -Force

# Adding the Nano Server Certificate to the Azure Key Vault as a Secret so it can be used in ARM Template Deployments.
Set-AzureKeyVaultSecret `
    -VaultName $KeyVaultName `
    -Name "$($NanoServerCertificateName.replace(".","-"))-cert" `
    -SecretValue $NanoServerCertificateSecretValue | Out-Null

# End of Script.
Write-Output "Deployment of the Azure Automation Account and all related Resources is Complete!"