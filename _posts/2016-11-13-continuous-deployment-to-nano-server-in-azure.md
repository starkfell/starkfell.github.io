---
layout: post
title: "Continuous Deployment to Nano Server in Azure."
date: 2016-11-17
---

# Introduction

There are several documented ways online on how to deploy Nano Server to Hyper-V Hosts or to Azure. Additionally, there is documentation on how to deploy a .NET Core Application to a Nano Server.
This article will demonstrate how to deploy a .NET Core Application to a Nano Server in Azure from GitHub using Azure Automation.

## Overview

This article will cover the following:

* Deploying Azure Automation Resources using PowerShell
* Deploying a Nano Server in Azure from GitHub
* Deploying IIS and ASP.NET Core to the Nano Server
* Creating a Runbook to push changes from GitHub to the Nano Server


## Deploy Azure Automation Resources using PowerShell Script

The Azure Resources that need to be in place for this scenario will be deployed using **setup-deployment-env-for-nano-server-in-azure.ps1**.

This script is responsible for the following:

* Creating two Resource Groups, one for Azure Key Vault and one for an Azure Automation Account
* Creating an Azure Key Vault
* Creating an Azure Automation Account
* Adding the Nano Server Local Administrator Credentials to the Key Vault
* Creating a Self-Signed Certifiate for Nano Server and storing it in the Key Vault

Full details about the Script can be reviewed within the script itself.

Copy the file to your Host and run it using the Syntax and Example below:

Syntax:

```powershell
./setup-deployment-env-for-nano-server-in-azure.ps1 `
-SubscriptionId <SUBSCRIPTION_ID> `
-AzureAutomationResourceGroupName <AZURE_AUTOMATION_RESOURCE_GROUP_NAME> `
-AzureAutomationAccountName <AZURE_AUTOMATION_ACCOUNT_NAME> `
-AzureAutomationPricingTier <AZURE_AUTOMATION_PRICING_TIER> `
-AzureAutomationCertificatePassword <AZURE_AUTOMATION_CERTIFICATE_PASSWORD> `
-KeyVaultResourceGroupName <AZURE_KEY_VAULT_RESOURCE_GROUP_NAME> `
-KeyVaultName <AZURE_KEY_VAULT_NAME> `
-NanoServerLocalAdminUsername <NANO_SERVER_LOCAL_ADMINISTRATOR_USERNAME> `
-NanoServerLocalAdminPassword <NANO_SERVER_LOCAL_ADMINISTRATOR_PASSWORD> `
-NanoServerCertificateName <NANO_SERVER_CERTIFICATE_NAME> `
-NanoServerCertificatePassword <NANO_SERVER_CERTIFICATE_PASSWORD> `
```

Example:

```powershell
./setup-deployment-env-for-nano-server-in-azure.ps1 `
-SubscriptionId 87d031cb-5fde-412d-b09c-c44c16131488 `
-AzureAutomationResourceGroupName nano-automation `
-AzureAutomationAccountName nano-automation `
-AzureAutomationPricingTier Free `
-AzureAutomationCertificatePassword NanoMation1! `
-KeyVaultResourceGroupName nano-key-vault `
-KeyVaultName nanokeyvault `
-NanoServerLocalAdminUsername winadmin `
-NanoServerLocalAdminPassword NanoMation1! `
-NanoServerCertificateName nanoservers.lumadeep.com `
-NanoServerCertificatePassword NanoMation1! `
```

The output from the script should have two entries at the bottom when it completes successfully:

```powershell
Azure Key Vault Resource ID:                           /subscriptions/87d031cb-5fde-412d-b09c-c44c16131488/resourceGroups/nano-key-vault/providers/Microsoft.KeyVault/vaults/nanokeyvault7780.
Nano Server Self-Signed Certificate Secret Identifier: https://nanokeyvault7780.vault.azure.net:443/secrets/nanoservers-lumadeep-com-cert/1f21b4be49dd49a1a05d4eca5400c609.
```


## Deploy a Nano Server in Azure from GitHub

Browse to the **[Deploy Nano Server and VNet into Azure](https://github.com/starkfell/starkfell.github.io/tree/master/arm-templates/deploy-vnet-and-nano-server)** ARM Template 
and clicko on the **Deploy to Azure** button.

If you are not already logged into your Azure Subscription, you will be prompted to do so.

Once you have logged into your Azure Subscription, the Custom deployment blade will appear.

<img src="{{ site.github.url }}/media/continuous-deployment-to-nano-server-in-azure-001.jpg" alt="" />

![continuous-deployment-to-nano-server-in-azure-001](media/continuous-deployment-to-nano-server-in-azure-001.jpg)

Under the **BASICS** section, do the following:

* Choose the Azure Subscription you want to deploy to.
* Choose the Name of the Resource Group you want to deploy to or create a new one.
* Choose the Location you want to deploy to.

Under the **SETTINGS** section, the Parmater Values that are recommended that you change are:

* Client ID
* Nano Serveradmin Password

The Parameter Values that you need to provide are:

* Nano Server Key Vault Id
* Nano Server Certificate Url

Refer to the output from the **setup-deployment-env-for-nano-server.ps1** PowerShell script for their respective values.

The rest of the predefined values should work under most circumstances; however, they can be modified if required.

Once you are finished, scroll down to the bottom of the blade and put a checkmark in the **I agree to the terms and conditions stated above** checkbox.
Afterwards, click on the **Purchase** button to kick off the deployment.

![continuous-deployment-to-nano-server-in-azure-002](media/continuous-deployment-to-nano-server-in-azure-002.jpg)

Once the deployment is finished, verify you can use PowerShell remoting to access the Nano Server.

