---
layout: post
comments: true
title: "Getting started with the ACS Engine to deploy Kubernetes in Azure."
date: 2018-02-08
---

Over the past 6 months, I have had to use the acs-engine to deploy and maintain K8s Clusters in Azure that are running both Linux and Windows Nodes in the same cluster. This type of configuration is only possible to deploy using the acs-engine and isn't supported by Microsoft (Surprise!). The first time you use the acs-engine can be incredibly daunting as it is the complete opposite experience of deploying a Kubernetes cluster using acs or aks in the Azure CLI; instead of having everything managed for you, you are responsible for managing the configuration and deployment of the Cluster. As such, you can configure just about every aspect of your Kubernetes Cluster before deploying it.

While I recommend going through the **[Official Documenation](https://github.com/Azure/acs-engine)**. I wanted to provide a more succinct version for reference and to help speed up the on-boarding process for others getting started.

# Overview

This article covers the basics of deploying a new K8s Cluster in Azure using the following steps and the acs-engine.

* Installing Azure CLI 2.0
* Instll the latest version of kubectl
* Installing the ACS Engine
* Generating an SSH Key
* Create a Service Principal in the Azure Subscription
* Create a Cluster Definition File
* Create a new Resource Group for the Kubernetes Cluster
* Deploy the Kubernetes ARM Template to the Resource Group
* Verify connectivity to the Kubernetes Cluster

## Prerequisites

* Access to an existing Azure Subscription and Administrative Rights to the Subscription
* A Linux VM with the Azure CLI Installed
* 5 to 10 CPU Cores available in your Azure Subscription for Standard_D2_v2 VMs

The Name of the Service Principal and DNS Prefix for the documentation below is **azure-k8s-dev**.

The steps below *should* work on Bash on Ubuntu for Windows but haven't been tested.

## Installing Azure CLI 2.0

Run the following command to install Azure CLI 2.0.

```bash
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list && \
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893 && \
sudo apt-get install -y apt-transport-https && \
sudo apt-get update && sudo apt-get install -y azure-cli
```

## Install the latest version of kubectl

Run the following command to install the latest version of **kubectl**.

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
chmod +x ./kubectl && \
sudo mv ./kubectl /usr/local/bin/kubectl
```

## Install the ACS Engine

If you want to install the **[latest](https://github.com/Azure/acs-engine/releases/latest)** version of the acs-engine, which at the time of this writing is **v0.12.5**, run the following command.

```bash
wget https://github.com/Azure/acs-engine/releases/download/v0.12.5/acs-engine-v0.12.5-linux-amd64.tar.gz && \
tar -xzvf acs-engine-v0.12.5-linux-amd64.tar.gz && \
sudo cp acs-engine-v0.12.5-linux-amd64/acs-engine /usr/bin/acs-engine && \
sudo cp acs-engine-v0.12.5-linux-amd64/acs-engine /usr/local/bin/acs-engine
```

If you want to install a particular version of the acs-engine, visit https://github.com/Azure/acs-engine/tags.

## Generate an SSH Key

Below is a quick way to generate an SSH Key using Bash.

```bash
ssh-keygen -t rsa -b 2048 -C "azure-k8s-dev-access-key" -f ~/.ssh/azure-k8s-dev-access-key -N ''
```

## Create a Service Principal in the Azure Subscription

Run the commands below using the Azure CLI.

Login to your Azure Subscription.

```bash
az login -u account.name@microsoft.com
```

Set the Azure Subscription you want to work with.

```bash
az account set -s d5b31b94-d91c-4ef8-b9d0-30193e6308ee
```

Run the following command create a Service Principal in the Azure Subscription.

```bash
    az ad sp create-for-rbac \
    --role="Contributor" \
    --name="azure-k8s-dev" \
    --password="UseAzureKeyVault1!" \
    --scopes="/subscriptions/d5b31b94-d91c-4ef8-b9d0-30193e6308ee"
```

You should get a similar response back after a few seconds. Additionally, you should see the App in the **App Registrations** section in the [Azure Portal](https://portal.azure.com)

```bash
Retrying role assignment creation: 1/36
Retrying role assignment creation: 2/36
{
  "appId": "fc045a69-cc77-4331-aa07-e70b682a414e",
  "displayName": "azure-k8s-dev",
  "name": "http://azure-k8s-dev",
  "password": "UseAzureKeyVault1!",
  "tenant": "b7ede2be-6495-48d3-ace8-24d68a53cf2d"
}
```

## Create a Cluster Definition File

Several Cluster Definition File examples can be found in the **[ACS Engine GitHub Repository](https://github.com/Azure/acs-engine/tree/master/examples)**. The Cluster Definition File that we will be using here will be a modified version of an existing example.

The acs-engine Cluster Definition Files are JSON files that allow you to configure several options about your K8s Cluster. Below are the some of the more common options you will modify.

```text
orchestratorType         - Kubernetes (Other options include Swarm, Swarm Mode, and DCOS).
orchestratorVersion      - The version of Kubernetes to deploy, i.e. - 1.6.1, 1.7.2, 1.8.2, 1.9.1.
masterProfile            - The number of Master Nodes to deploy, the DNS Prefix to use, VM Size, type of Storage to use, OS Disk Size (GB).
agentPoolProfiles        - The name of the pool, number of Nodes to deploy, VM Size, type of Storage to use, OS Disk Size (GB), Availability Set Profile, OS Type.
linuxProfile             - the admin Username and SSH Key used to access the Linux Nodes.
windowsProfile           - the admin Username and Password used to access the Windows Nodes.
servicePrincipalProfile  - The Service Principal Client ID and Service Principal Password.
```

For the purposes of this walkthrough, we are going to deploy a **vanilla** Deployment of Kubernetes 1.9.2 using the following cluster defintion file.

```json
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes",
      "orchestratorRelease": "1.9"
    },
    "masterProfile": {
      "count": 1,
      "dnsPrefix": "",
      "vmSize": "Standard_D2_v2"
    },
    "agentPoolProfiles": [
      {
        "name": "linuxpool1",
        "count": 2,
        "vmSize": "Standard_D2_v2",
        "availabilityProfile": "AvailabilitySet"
      }
    ],
    "linuxProfile": {
      "adminUsername": "linuxadmin",
      "ssh": {
        "publicKeys": [
          {
            "keyData": ""
          }
        ]
      }
    },
    "servicePrincipalProfile": {
      "clientId": "",
      "secret": ""
    }
  }
}
```

You'll notice the following name-pair values in the definition above need to be filled in with their respective values.

```text
dnsPrefix = azure-k8s-dev
keyData   = {SSH_PUBLIC_KEY}
clientId  = appId
secret    = UseAzureKeyVault1!
```

```json
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes",
      "orchestratorRelease": "1.9"
    },
    "masterProfile": {
      "count": 1,
      "dnsPrefix": "azure-k8s-dev",
      "vmSize": "Standard_D2_v2"
    },
    "agentPoolProfiles": [
      {
        "name": "linuxpool1",
        "count": 2,
        "vmSize": "Standard_D2_v2",
        "availabilityProfile": "AvailabilitySet"
      }
    ],
    "linuxProfile": {
      "adminUsername": "linuxadmin",
      "ssh": {
        "publicKeys": [
          {
            "keyData": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQrDd2IyLZIYn02wrltHKwC3UXXkkO2Br1jiYdJ1yYA8Q2Wm7LJj4c2lnKD9c/VCtR2w5cBwTz9D/JGwFJtHEPUZXOq3CDxWcPRE8GfRK9f1OZlvFwuTHTEJaza8KRVRhrXX9Tjtl2a94R7uSXr7NIKFgopjGkJ9BgSlufh0lUiWoAg1/e7cNXi3tiewu6lI+bG1v5aKmgKfITpbe56YIBYNzQEnxjCQdIye5hafz3XoxVkGaKst072cByygERqFPV6QFcJ9CITMgL3SoI3/XTPdg+hKYFU2VL5Xc6Chi2q3WVM69IkxnGpZOES8nxWRfkEAX08zsWtjpVu18DlEm/ azure-k8s-dev-access-key"
          }
        ]
      }
    },
    "servicePrincipalProfile": {
      "clientId": "fc045a69-cc77-4331-aa07-e70b682a414e",
      "secret": "UseAzureKeyVault1!"
    }
  }
}
```

Save your final configuration in a file called **sample-deployment.json**.

*Note: The full list of customizable options you can modify can be found in the **[Cluster Definition Documentation](https://github.com/Azure/acs-engine/blob/master/docs/clusterdefinition.md)**.*

## Generate the deployment ARM Temaplates using the ACS Engine

Run the following command to generate the deployment ARM Templates.

```bash
acs-engine generate sample-deployment.json
```

The ARM Templates will generated in a few seconds and you should see the following response.

```bash
INFO[0000] Generating assets into _output/azure-k8s-dev...
```

The acs-engine generates the following folder structure based off of the **DNS Prefix** that is defined in the **masterProfile** in the cluster-definition file. Shown below is what the folder structure when the DNS Prefix is set to **azure-k8s-dev**, as was done in the previous steps.

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

First, make sure you are located in your **home** directory.

```bash
cd ~
```

Run the following command to deploy the Kubernetes ARM Template to the **azure-k8s-dev** Resource Group.

```bash
az group deployment create \
    --name "azure-k8s-dev-Deployment" \
    --resource-group "azure-k8s-dev" \
    --template-file "./_output/azure-k8s-dev/azuredeploy.json" \
    --parameters "./_output/azure-k8s-dev/azuredeploy.parameters.json"
```

This command should run for approximately 10 to 15 minutes. When the command completes, you should get back a very long list of output which I have ommitted here as its too long. It's much easier to track and verify the deployment succeeded in the [Azure Portal](https://portal.azure.com) in the **azure-k8s-dev** Resource Group.

## Verify connectivity to the Kubernetes Cluster

In order to verify connectivity to the K8s Cluster, we have to let kubectl which kubeconfig file to use. Run the following command to set the location of the kubeconfig file; because we deployed the K8s cluster in Western Europe, we are pointing to the respective kubeconfig file.

```bash
export KUBECONFIG=~/_output/azure-k8s-dev/kubeconfig/kubeconfig.westeurope.json
```

Next, run the following command to verify that you can connect to the Kubernetes Cluster and display the clusters information.

```bash
kubectl cluster-info
```

You should get back the following output.

```bash
Kubernetes master is running at https://azure-k8s-dev.westeurope.cloudapp.azure.com
Heapster is running at https://azure-k8s-dev.westeurope.cloudapp.azure.com/api/v1/namespaces/kube-system/services/heapster/proxy
KubeDNS is running at https://azure-k8s-dev.westeurope.cloudapp.azure.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
kubernetes-dashboard is running at https://azure-k8s-dev.westeurope.cloudapp.azure.com/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy
tiller-deploy is running at https://azure-k8s-dev.westeurope.cloudapp.azure.com/api/v1/namespaces/kube-system/services/tiller-deploy:tiller/proxy
```

Next, run the following command to display the Nodes in the Cluster.

```bash
kubectl get nodes
```

You should get back the following output.

```bash
NAME                        STATUS    ROLES     AGE       VERSION
k8s-linuxpool1-30657238-0   Ready     agent     15m       v1.9.1
k8s-linuxpool1-30657238-1   Ready     agent     18m       v1.9.1
k8s-master-30657238-0       Ready     master    18m       v1.9.1
```

Lastly, run the following command to display all of the current pods running in the cluster.

```bash
kubectl get pods --all-namespaces
```

You should get back the following output. The Pod names will be slightly different for you.

```bash
NAMESPACE     NAME                                            READY     STATUS    RESTARTS   AGE
kube-system   heapster-668b9fdf67-zx7v4                       2/2       Running   0          19m
kube-system   kube-addon-manager-k8s-master-30657238-0        1/1       Running   0          19m
kube-system   kube-apiserver-k8s-master-30657238-0            1/1       Running   0          18m
kube-system   kube-controller-manager-k8s-master-30657238-0   1/1       Running   0          18m
kube-system   kube-dns-v20-55498dbf49-94hr8                   3/3       Running   0          19m
kube-system   kube-dns-v20-55498dbf49-mm8jk                   3/3       Running   0          19m
kube-system   kube-proxy-h87xw                                1/1       Running   0          19m
kube-system   kube-proxy-nhlh8                                1/1       Running   0          19m
kube-system   kube-proxy-ss9cv                                1/1       Running   0          17m
kube-system   kube-scheduler-k8s-master-30657238-0            1/1       Running   0          19m
kube-system   kubernetes-dashboard-868965c888-2jpxn           1/1       Running   0          19m
kube-system   tiller-deploy-589f6788d7-5gk95                  1/1       Running   0          19m
```

## Other

The agentPoolProfiles section allows you to define multiple Pools of whatever OS type you want; this is how you can run Linux and Windows Nodes in a single K8s Cluster in Azure.

An **agentPoolProfiles** sample is shown below:

```json
      "agentPoolProfiles": [
        {
          "name": "linuxpool",
          "count": 2,
          "vmSize": "Standard_D2_v2",
          "storageProfile": "ManagedDisks",
          "osDiskSizeGB": 128,
          "availabilityProfile": "AvailabilitySet"
        },
        {
          "name": "windowspool",
          "count": 2,
          "vmSize": "Standard_D2_v2",
          "storageProfile": "ManagedDisks",
          "osDiskSizeGB": 128,
          "availabilityProfile": "AvailabilitySet",
          "osType": "Windows"
        }
      ],
```