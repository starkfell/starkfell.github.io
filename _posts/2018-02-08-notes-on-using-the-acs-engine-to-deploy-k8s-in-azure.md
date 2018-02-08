---
layout: post
comments: true
title: "Notes on using the acs-engine to deploy K8s in Azure - In Progress."
date: 2018-02-08
---

Over the past 6 months, I have had to use the acs-engine to deploy and maintain K8s Clusters in Azure that are running both Linux and Windows Nodes in the same cluster. This type of configuration is only possible to deploy using the acs-engine and isn't supported by Microsoft (Surprise!). The first time you use the acs-engine can be incredibly daunting as it is the complete opposite experience of deploying a Kubernetes cluster using acs or aks in the Azure CLI; instead of having everything managed for you, you are responsible for managing the configuration and deployment of the Cluster. As such, you can configure just about every aspect of your Kubernetes Cluster before deploying it.

While I recommend going through the **[Official Documenation](https://github.com/Azure/acs-engine)**. I wanted to provide a more succinct version for reference and to help speed up the on-boarding process for others getting started.

# Overview

This article covers the basics of deploying a new K8s Cluster in Azure using the following steps and the acs-engine.

* Installing the ACS Engine
* Generating an SSH Key
* Create a Service Principal in the Azure Subscription

## Prerequisites

* Access to an existing Azure Subscription and Administrative Rights to the Subscription
* A Linux VM with the Azure CLI Installed
* 5 to 10 CPU Cores available in your Azure Subscription for Standard_D2_v2 VMs.

The Name of the Service Principal and DNS Prefix for the documentation below is **azure-k8s-dev**.

The steps below *should* work on Bash on Ubuntu for Windows but haven't been tested.

## Install the ACS Engine

## Generate an SSH Key

Below is a quick way to generate an SSH Key using Bash.

```bash
ssh-keygen -t rsa -b 2048 -C "azure-k8s-dev-access-key" -f ~/.ssh/azure-k8s-dev-access-key -N ''
```

## Create a Service Principal in the Azure Subscription

Use the following code to create a Service Principal in the Azure Subscription using bash.

```bash
    az ad sp create-for-rbac \
    --role="Contributor" \
    --name="azure-k8s-dev" \
    --password="UseAzureKeyVault1!" \
    --scopes="/subscriptions/d5b31b94-d91c-4ef8-b9d0-30193e6308ee"
```

## Create or Edit a Cluster Definition File

Several Cluster Definition File examples can be found in the **[ACS Engine GitHub Repository](https://github.com/Azure/acs-engine/tree/master/examples)**.

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

the agentPoolProfiles section allows you to define multiple Pools of whatever OS type you want; this is how you can run Linux and Windows Nodes in a single K8s Cluster in Azure.

An sample definition is shown below:

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

The full list of customizable options you can modify can be found in the **[Cluster Definition Documentation](https://github.com/Azure/acs-engine/blob/master/docs/clusterdefinition.md)**.

The acs-engine generates the following folder based off of the **DNS Prefix** that is defined in the **masterProfile** in the cluster-definition file. Shown below is what the folder structure would like if the DNS Prefix was called **azure-k8s-dev**.

```text
azure-k8s-dev --> apimodel.json
azure-k8s-dev --> apiserver.crt
azure-k8s-dev --> apiserver.key
azure-k8s-dev --> azuredeploy.json
azure-k8s-dev --> azuredeploy.parameters.json
azure-k8s-dev --> ca.crt
azure-k8s-dev --> ca.key
azure-k8s-dev --> client.crt
azure-k8s-dev --> client.key
azure-k8s-dev --> kubectlClient.crt
azure-k8s-dev --> kubectlClient.key
azure-k8s-dev --> kubeconfig
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