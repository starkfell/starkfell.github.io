---
layout: post
comments: true
title: "Deploying Kubernetes 1.10.6 with Azure Active Directory Integration using the ACS Engine"
date: 2018-08-23
---

Most of the instructions available online on this topic do not provide a way to create the required Server and Client AD Applications using the Azure CLI. In my experience, incorrectly creating these two applications through the Azure Portal is what causes AAD Integration with Kubernetes to fail. By using the Azure CLI, the potential for failure is reduced from forgetting to click on a button to a copy paste issue. Hopefully the information detailed below will help you out if you are either getting started with AAD Integration with K8s or are working on automating the deployment of your existing K8s Clusters in Azure.

# Overview

If you are looking for the quickest way to deploy a Kubernetes Cluster in Azure with AAD Integration, check out the [Integrate Azure Active Directory with AKS - Preview](https://docs.microsoft.com/en-us/azure/aks/aad-integration) article under Microsoft's official documentation.

This article covers: how to deploy a new Kubernetes Cluster (1.10.6) in Azure with AAD Integration using the acs-engine, how to add an Azure AD User to the K8s Cluster, and finally how to authenticate and connect to the K8s Cluster as them. Additionally, this walkthrough was written for and tested on Ubuntu 16.04 and Ubuntu 18.04 (minimum installations) using a standard linux user from within their */home* directory. The instructions *should* work on Bash on Ubuntu for Windows but haven't been tested. The steps involved are listed below:

* Installing Azure CLI 2.0
* Instll the latest version of kubectl
* Installing the ACS Engine
* Generating an SSH Key
* Create a Service Principal in the Azure Subscription
* Download the Manifest Files for creating the Azure AD Applcations
* Download the Kubernetes Cluster Definition File
* Create the Server AD Application
* Create the Client AD Application
* Update the Kubernetes Deployment Cluster File
* Create a new Resource Group for the Kubernetes Cluster
* Deploy the Kubernetes ARM Template to the Resource Group
* Verify kubeconfig configuration
* Add an Azure AD User to the cluster-admin Role in the Kubernetes Cluster
* Connect to the Kubernetes Cluster as the Azure AD User

## Prerequisites

* Access to an existing Azure Subscription and Administrative Rights to the Subscription
* **curl** and **jq** need to be installed and **vim** is highly recommended
* 5 to 10 CPU Cores available in your Azure Subscription for Standard_D2_v2 VMs
* The Azure Subscription ID used in the documentation below, **d5b31b94-d91c-4ef8-b9d0-30193e6308ee**, needs to be replaced with your Azure Subscription ID.
* The default username of all the Linux Nodes in the K8s Cluster is **linuxadmin**.
* The default password of the Kubernetes Service Principal is **UseAzureKeyVault1!**.

*Note: This walkthrough uses local variables extensively so that the majority of commands can simply be copy/pasted directly into a SSH session with minimal interaction. If you decide to copy and paste everything in this guide without reading through it first, you should have a working K8s Cluster with AAD Integration; however, if something breaks unexpectedly, that's on you.*

## Installing Azure CLI 2.0

Run the following command to install Azure CLI 2.0.

```bash
AZ_REPO=$(lsb_release -cs) && \
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
sudo tee /etc/apt/sources.list.d/azure-cli.list && \
curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - && \
sudo apt-get install -y apt-transport-https && \
sudo apt-get update && \
sudo apt-get install -y azure-cli
```

## Install the latest version of kubectl

Run the following command to install the latest version of **kubectl**.

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
chmod +x ./kubectl && \
sudo mv ./kubectl /usr/local/bin/kubectl
```

## Install the ACS Engine

If you want to install the **[latest](https://github.com/Azure/acs-engine/releases/latest)** version of the acs-engine, which at the time of this writing is **v0.20.9**, run the following command.

```bash
wget https://github.com/Azure/acs-engine/releases/download/v0.20.9/acs-engine-v0.20.9-linux-amd64.tar.gz && \
tar -xzvf acs-engine-v0.20.9-linux-amd64.tar.gz && \
sudo cp acs-engine-v0.20.9-linux-amd64/acs-engine /usr/bin/acs-engine && \
sudo cp acs-engine-v0.20.9-linux-amd64/acs-engine /usr/local/bin/acs-engine
```

If you want to install a particular version of the acs-engine, visit **https://github.com/Azure/acs-engine/tags**.

## Generate an SSH Key

Run the command below to generate an SSH Key using **ssh-keygen**. The Name of the SSH Key is named after the Service Principal and DNS Prefix being used in this walkthrough, **azure-k8s-dev**.

```bash
ssh-keygen -t rsa -b 2048 -C "azure-k8s-dev-access-key" -f ~/.ssh/azure-k8s-dev-access-key -N ''
```

## Create a Service Principal in the Azure Subscription

Run the commands below using the Azure CLI.

Login to your Azure Subscription.

```bash
az login
```

Set the Azure Subscription you want to work with.

```bash
az account set -s d5b31b94-d91c-4ef8-b9d0-30193e6308ee
```

Store the Azure Subscription you set as a local variable.

```bash
AZ_SUB=$(az account show --query id --output tsv)
```

Store the password used for creating the Kubernetes Service Principal as a local variable.

```bash
K8S_SP_CLIENT_PASSWORD=$(echo "UseAzureKeyVault1!")
```

Run the following command create the Kubernetes Service Principal in the Azure Subscription.

```bash
az ad sp create-for-rbac \
--role="Contributor" \
--name="azure-k8s-dev" \
--password="$K8S_SP_CLIENT_PASSWORD" \
--scopes="/subscriptions/$AZ_SUB"
```

You should get a similar response back after a few seconds. Additionally, the App will appear in the **App Registrations** section in the **[Azure Portal](https://portal.azure.com)**.

```bash
Retrying role assignment creation: 1/36
Retrying role assignment creation: 2/36
{
  "appId": "ac033a69-cc77-4331-aa07-e70b692a414e",
  "displayName": "azure-k8s-dev",
  "name": "http://azure-k8s-dev",
  "password": "UseAzureKeyVault1!",
  "tenant": "c7fde1be-6495-40d3-ace8-45d68b52cf2d"
}
```

Make note of the the **AppId** as it will be used for the **clientId** field in the Cluster Definition File in the next section.

## Download the Manifest Files for creating the Azure AD Applcations

You can manually deploy the required Web App and Native Azure Applications as described in the [Integrate Azure Active Directory with AKS - Preview](https://docs.microsoft.com/en-us/azure/aks/aad-integration) article under Microsoft's official documentation. However, it's very easy to miss a step which will require you to troubleshoot the Apps or start over.

Instead, I have pre-configured two JSON Manifest files with the required permissions that need to be set. Additionally, we will be programmatically modifying and then deploying them to the Azure Apps.

Run the following command to download the Manifest Files for the two Azure Apps that we will be deploying.

```bash
wget https://raw.githubusercontent.com/starkfell/starkfell.github.io/master/acs-engine-files/k8s-apisrv-manifest.json -O k8s-apisrv-manifest.json && \
wget https://raw.githubusercontent.com/starkfell/starkfell.github.io/master/acs-engine-files/k8s-apicli-template-manifest.json -O k8s-apicli-template-manifest.json
```

## Download the Kubernetes Cluster Definition File

The Kubernetes Cluster Definition file used here is pre-configured for our purposes; feel free to review it and use it later for your purposes.

Run the following command to download the Cluster Definition File for Kubernetes we will be using.

```bash
wget https://raw.githubusercontent.com/starkfell/starkfell.github.io/master/acs-engine-files/deploy-k8s-1.10.6-template.json -O deploy-k8s-1.10.6-template.json
```

## Create the Server AD Application

Run the following command to create the Server Application. This application is used to obtain a users Azure AD group membership.

```bash
az ad app create \
--display-name k8s-apisrv-dev \
--identifier-uris http://k8s-apisrv-dev \
--homepage http://k8s-apisrv-dev \
--native-app false
```

Run the following command to create a Service Principal for the Server Application.

```bash
az ad sp create \
--id http://k8s-apisrv-dev
```

Run the following command to set the **groupMembershipClaims** property to **All**. This can also be set to **SecurityGroup**.

```bash
az ad app update \
--id http://k8s-apisrv-dev \
--set groupMembershipClaims=All
```

Run the following command to update the Manifest of the Server Applcation with the values in the **k8s-apisrv-manifest.json** file.

```bash
az ad app update \
--id http://k8s-apisrv-dev \
--required-resource-accesses k8s-apisrv-manifest.json
```

The contents of the **k8s-apisrv-manifest.json** file will grant the Server Application access to the following APIs in your Subscription.

```text
Windows Azure Active Directory
- Delegated Permissions
  - Sign in and read user profile
Microsoft Graph
- Application Permissions
  - Read directory data
- Delegrated Permissions
  - Sign in and read user profile
  - Read directory data
```

Next, run the following command to save the K8s API Server Application **Application ID** and **OAUTH2 Permissions ID** as local variables for later use.

```bash
K8S_APISRV_APP_ID=$(az ad app show --id http://k8s-apisrv-dev --query appId --output tsv) && \
K8S_APISRV_OAUTH2_PERMISSIONS_ID=$(az ad app show --id http://k8s-apisrv-dev --query oauth2Permissions[].id --output tsv)
```

## Create the Client AD Application

Run the following command to deploy the Client Application in your Azure Subscription.

```bash
DEPLOY_K8S_APICLI_APP=$(az ad app create --display-name k8s-apicli-dev --reply-urls http://k8s-apicli-dev --homepage http://k8s-apicli-dev --native-app true)
```

Next, save the K8s API Client Application **Application ID** as a variable for use later.

```bash
K8S_APICLI_APP_ID=$(echo $DEPLOY_K8S_APICLI_APP | jq .appId | tr -d '"')
```

Next, create a Service Principal for the Client Application.

```bash
az ad sp create \
--id $K8S_APICLI_APP_ID
```

## Update the Kubernetes Deployment Cluster File

Next, run the following command to replace the **{K8S_APISRV_APP_ID}** and **{K8S_APISRV_OAUTH2_PERMISSIONS_ID}** variables in the **k8s-apicli-manifest.json** file with the **Application ID** and **OAUTH2 Permissions ID** Server Application variables from earlier.

```bash
cat k8s-apicli-template-manifest.json > k8s-apicli-manifest.json && \
sed -i -e "s/{K8S_APISRV_APP_ID}/$K8S_APISRV_APP_ID/" k8s-apicli-manifest.json && \
sed -i -e "s/{K8S_APISRV_OAUTH2_PERMISSIONS_ID}/$K8S_APISRV_OAUTH2_PERMISSIONS_ID/" k8s-apicli-manifest.json
```

The contents of the **k8s-apicli-template-manifest.json** file will grant the Client Application access to the Server Application created earlier.

```text
Windows Azure Active Directory
- Delegated Permissions
  - Sign in and read user profile
k8s-apisrv-dev
- Delegated Permissions
  - Access k8s-apisrv-dev
```

Run the following command to update the Manifest of the Server Applcation with the values in the **k8s-apicli-manifest.json** file.

```bash
az ad app update \
--id $K8S_APICLI_APP_ID \
--required-resource-accesses k8s-apicli-manifest.json
```

The **deploy-k8s-1.10.6-template.json** deployment file requires several varibles to replaced before it can be used to generate the ARM Template Files to deploy the Kubernetes Cluster.

Run the following command to retrieve the rest of the information required for the **deploy-k8s-1.10.6-template.json** deployment file and store them in local variables.

```bash
AZURE_SUB_TENANT_ID=$(az account show --query tenantId --output tsv) && \
DNS_PREFIX=$(echo "azure-k8s-dev") && \
ADMIN_USERNAME=$(echo "linuxadmin") && \
SSH_PUBLIC_KEY=$(cat ~/.ssh/azure-k8s-dev-access-key.pub) && \
K8S_SP_CLIENT_ID=$(az ad app show --id http://azure-k8s-dev --query appId --output tsv)
```

Next, run the following command to replace the variables in the **deploy-k8s-1.10.6-template.json** deployment file with their respective values.

```bash
cat deploy-k8s-1.10.6-template.json > deploy-k8s-1.10.6.json && \
sed -i -e "s/{K8S_APISRV_APP_ID}/$K8S_APISRV_APP_ID/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{K8S_APICLI_APP_ID}/$K8S_APICLI_APP_ID/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{AZURE_SUB_TENANT_ID}/$AZURE_SUB_TENANT_ID/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{DNS_PREFIX}/$DNS_PREFIX/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{ADMIN_USERNAME}/$ADMIN_USERNAME/" deploy-k8s-1.10.6.json && \
ESCAPED_SSH_PUBLIC_KEY=$(echo $SSH_PUBLIC_KEY | sed 's@/@\\/@g') && \
sed -i -e "s/{SSH_PUBLIC_KEY}/$ESCAPED_SSH_PUBLIC_KEY/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{K8S_SP_CLIENT_ID}/$K8S_SP_CLIENT_ID/" deploy-k8s-1.10.6.json && \
sed -i -e "s/{K8S_SP_CLIENT_PASSWORD}/$K8S_SP_CLIENT_PASSWORD/" deploy-k8s-1.10.6.json
```

## Generate the deployment ARM Templates using the ACS Engine

Run the following command to generate the deployment ARM Templates.

```bash
acs-engine generate deploy-k8s-1.10.6.json
```

The ARM Templates will generated in a few seconds and you should see the following response.

```bash
INFO[0000] Generating assets into _output/azure-k8s-dev...
```

The acs-engine generates the following folder structure based off of the **dnsPrefix** that we previously set in the **masterProfile** section of the Cluster Definition file. Shown below is what the folder structure when the DNS Prefix is set to **azure-k8s-dev**, as was done in the previous steps.

```text
_output/azure-k8s-dev --> apimodel.json
_output/azure-k8s-dev --> apiserver.crt
_output/azure-k8s-dev --> apiserver.key
_output/azure-k8s-dev --> azuredeploy.json
_output/azure-k8s-dev --> azuredeploy.parameters.json
_output/azure-k8s-dev --> ca.crt
_output/azure-k8s-dev --> ca.key
_output/azure-k8s-dev --> client.crt
_output/azure-k8s-dev --> client.key
_output/azure-k8s-dev --> kubectlClient.crt
_output/azure-k8s-dev --> kubectlClient.key
_output/azure-k8s-dev --> kubeconfig
                          kubeconfig --> kubeconfig.australiaeast.json
                          kubeconfig --> kubeconfig.australiasoutheast.json
                          kubeconfig --> kubeconfig.brazilsouth.json
                          kubeconfig --> kubeconfig.canadacentral.json
                          kubeconfig --> kubeconfig.canadaeast.json
                          kubeconfig --> kubeconfig.centralindia.json
                          kubeconfig --> kubeconfig.centraluseuap.json
                          kubeconfig --> kubeconfig.centralus.json
                          kubeconfig --> kubeconfig.chinaeast.json
                          kubeconfig --> kubeconfig.chinanorth.json
                          kubeconfig --> kubeconfig.eastasia.json
                          kubeconfig --> kubeconfig.eastus2euap.json
                          kubeconfig --> kubeconfig.eastus2.json
                          kubeconfig --> kubeconfig.eastus.json
                          kubeconfig --> kubeconfig.germanycentral.json
                          kubeconfig --> kubeconfig.germanynortheast.json
                          kubeconfig --> kubeconfig.japaneast.json
                          kubeconfig --> kubeconfig.japanwest.json
                          kubeconfig --> kubeconfig.koreacentral.json
                          kubeconfig --> kubeconfig.koreasouth.json
                          kubeconfig --> kubeconfig.northcentralus.json
                          kubeconfig --> kubeconfig.northeurope.json
                          kubeconfig --> kubeconfig.southcentralus.json
                          kubeconfig --> kubeconfig.southeastasia.json
                          kubeconfig --> kubeconfig.southindia.json
                          kubeconfig --> kubeconfig.uksouth.json
                          kubeconfig --> kubeconfig.ukwest.json
                          kubeconfig --> kubeconfig.usgoviowa.json
                          kubeconfig --> kubeconfig.usgovvirginia.json
                          kubeconfig --> kubeconfig.westcentralus.json
                          kubeconfig --> kubeconfig.westeurope.json
                          kubeconfig --> kubeconfig.westindia.json
                          kubeconfig --> kubeconfig.westus2.json
                          kubeconfig --> kubeconfig.westus.json
```

## Create a new Resource Group for the Kubernetes Cluster

Run the following command to deploy a new Resource Group.

```bash
az group create \
--name azure-k8s-dev \
--location westeurope
```

You should get the following response back.

```bash
{
  "id": "/subscriptions/d5b31b94-d91c-4ef8-b9d0-30193e6308ee/resourceGroups/azure-k8s-dev",
  "location": "westeurope",
  "managedBy": null,
  "name": "azure-k8s-dev",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null
}
```

## Deploy the Kubernetes ARM Template to the Resource Group

Run the following command to deploy the Kubernetes ARM Template to the **azure-k8s-dev** Resource Group.

```bash
az group deployment create \
--name "azure-k8s-dev-Deployment" \
--resource-group "azure-k8s-dev" \
--template-file "./_output/azure-k8s-dev/azuredeploy.json" \
--parameters "./_output/azure-k8s-dev/azuredeploy.parameters.json"
```

This command should run for approximately 10 to 15 minutes. When the command completes, you should get back a very long list of output which I have ommitted from here due to its length. It's much easier to track and verify the deployment succeeded in the [Azure Portal](https://portal.azure.com) in the **azure-k8s-dev** Resource Group.

## Verify kubeconfig configuration

In order to connect to the K8s Cluster, we have to point kubectl to the kubeconfig file to use. Run the following command to set the location of the kubeconfig file; because we deployed the K8s cluster in Western Europe, we are pointing to the respective kubeconfig file.

```bash
export KUBECONFIG=~/_output/azure-k8s-dev/kubeconfig/kubeconfig.westeurope.json
```

Next, run the following command to show the current configuration of the kubeconfig file.

```bash
kubectl config view
```

You should get back a similar response.

```text
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: REDACTED
    server: https://azure-k8s-dev.westeurope.cloudapp.azure.com
  name: azure-k8s-dev
contexts:
- context:
    cluster: azure-k8s-dev
    user: azure-k8s-dev-admin
  name: azure-k8s-dev
current-context: azure-k8s-dev
kind: Config
preferences: {}
users:
- name: azure-k8s-dev-admin
  user:
    auth-provider:
      config:
        apiserver-id: {K8S_APISRV_APP_ID}
        client-id: {K8S_APICLI_APP_ID}
        environment: AzurePublicCloud
        tenant-id: {AZURE_SUB_TENANT_ID}
      name: azure
```

Make sure that the **apiserver-id**, **client-id**, and **tenant-id** all match the respective values of the Azure Client and Server Applications you created previously; as well as the Azure Subscription Tenant ID.

## Add an Azure AD User to the cluster-admin Role in the Kubernetes Cluster

Next, run the following command to add the **azure-k8s-dev-access-key** SSH Private Key to the SSH Agent which will allow us to login to the Kubernetes Master.

```bash
eval $(ssh-agent -s) ; ssh-add ~/.ssh/azure-k8s-dev-access-key
```

Next, we need to add a user to the **cluster-admin** role on the Kubernetes Cluster. The format required to add a user is:

```text
https://sts.windows.net/{AZURE_SUB_TENANT_ID}/#{AZURE_USER_ID}
```

The Azure Subscription Tenant ID is stored in the **$AZURE_SUB_TENANT_ID** local variable that we used earlier.

In order to locate you User ID, you have a couple of options. From the Azure Portal, you can go to Azure Active Directory --> Users --> Your Username --> and then look for the **Object ID** in your profile. It will be a 36 character GUID in the format of *xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx*.

The other option is to run the following command below and replacing **{AZURE_USERNAME}** with your Azure AD User.

```bash
az ad user list | grep {AZURE_USERNAME} -A10 | grep objectId
```

You should get a similar response back:

```bash
"objectId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx",
```

For our purposes we are going to add the Azure AD User to a local variable called **AZURE_USERNAME**. Replace **{AZURE_USERNAME}** with the name of the User.

```bash
AZURE_USERNAME="{AZURE_USERNAME}"
```

Next, run the following command to save the **objectId** of your Azure AD User into a local variable.

```bash
AZURE_USER_ID=$(az ad user list | grep $AZURE_USERNAME -A10 | grep objectId | awk '{print $2}' | tr -d "," | tr -d '"')
```

Next, run the following command to login to the Kubernetes Cluster Master and add the Azure AD User to the **cluster-admin** Role on the K8s Cluster.

```bash
ssh -i _output/$DNS_PREFIX/azureuser_rsa linuxadmin@$DNS_PREFIX.westeurope.cloudapp.azure.com \
kubectl create clusterrolebinding \
aad-default-cluster-admin-binding \
--clusterrole=cluster-admin \
--user "https://sts.windows.net/$AZURE_SUB_TENANT_ID/#$AZURE_USER_ID"
```

After running the command, you may be asked if you want to continue connecting; type **yes** and hit Enter. Afterwards, you should get back the following response:

```text
clusterrolebinding.rbac.authorization.k8s.io "aad-default-cluster-admin-binding" created
```

## Connect to the Kubernetes Cluster as the Azure AD User

Next, run the following command to show the Kubernetes Cluster Information.

```bash
kubectl cluster-info
```

As soon as the K8s Cluster information starts to appear, you will prompted to login to the Azure Portal Device Login page.

```text
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code XXXXXXXX to authenticate.
```

Open up a web browser and login to the Azure Portal and use the code you were given to authenticate. Once you are logged in, you will be prompted to Continue logging into the **k8s-apicli-dev** Application. Next, you will need to login as the Azure AD User you added earlier to the **cluster-admin** Role in the Kubernetes Cluster. Next, you will get a Permissions Request from **k8s-apicli-dev** asking for permission to **Sign you in and read your profile** and **Access k8s-apisrv-dev (k8s-apisrv-dev)**. Hit Accept. Finally you will be prompted that you are signed in and can close the web browser.

Next, run the following command to verify you can access the resources in the K8s Cluster.

Next, run the following command to list the K8s Nodes in the Cluster.

```bash
kubctl get nodes
```

You shoul get back a similar response response.

```text
NAME                        STATUS    ROLES     AGE       VERSION
k8s-linuxpool1-30657238-0   Ready     agent     42m       v1.10.6
k8s-linuxpool1-30657238-1   Ready     agent     42m       v1.10.6
k8s-master-30657238-0       Ready     master    42m       v1.10.6
```

You should now be able to run any and all commands in the K8s Cluster as the Azure AD User you logged in as.

If you run the **kubectl config view** command again, you will see the access and refresh tokens of the Azure AD User you are logged in as:

```bash
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: REDACTED
    server: https://azure-k8s-dev.westeurope.cloudapp.azure.com
  name: azure-k8s-dev
contexts:
- context:
    cluster: azure-k8s-dev
    user: azure-k8s-dev-admin
  name: azure-k8s-dev
current-context: azure-k8s-dev
kind: Config
preferences: {}
users:
- name: azure-k8s-dev-admin
  user:
    auth-provider:
      config:
        access-token: {AZURE_AUTH_ACCESS_TOKEN}
        apiserver-id: {K8S_APISRV_APP_ID}
        client-id: {K8S_APICLI_APP_ID}
        expires-in: "3599"
        expires-on: "1535024394"
        refresh-token: {AZURE_AUTH_REFRESH_TOKEN}
        tenant-id: {AZURE_SUB_TENANT_ID}
      name: azure
```

## Closing

This article covered how to deploy a new Kubernetes Cluster (1.10.6) in Azure with AAD Integration using the acs-engine, how to add an Azure AD User to the K8s Cluster, and finally how to authenticate and connect to the K8s Cluster as them.

## Additional Reading

Below is some additional documentation that I recommend going through if you want to learn more about adding additional Azure AD Users or Azure AD Groups.

[Microsoft Azure Container Service Engine - Kubernetes AAD integration Walkthrough](https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/aad.md)
