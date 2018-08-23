---
layout: post
comments: true
title: "Getting started with the ACS Engine to deploy Kubernetes in Azure"
date: 2018-02-19
---

Over the past 6 months, I have had to use the **[Azure Container Service Engine](https://github.com/Azure/acs-engine)** to deploy and maintain K8s Clusters in Azure running both Linux and Windows Nodes in the same Cluster. This type of configuration in Azure is currently only possible using the ACS Engine. First time users of the ACS Engine may find the process incredibly daunting as it is the complete opposite experience of deploying a K8s Cluster using acs or aks in the Azure CLI; instead of having everything managed for you, you are responsible for managing the configuration and deployment of the Cluster. As such you are able to configure almost every aspect of your K8s Cluster before deploying it.

Because the learning curve of the ACS Engine can be quite steep, I wanted to provide a reference guide allowing other individuals a quicker way to get started from scratch as well having it for future reference for myself. For the complete documentation on the Azure Container Service Engine, make sure to review the **[Official Documenation](https://github.com/Azure/acs-engine/tree/master/docs)**.

More posts will be coming in the near future detailing some of the customization options available to you in the Azure Container Service Engine.

# Overview

This article covers the basics of deploying a new K8s Cluster in Azure using the following steps and the acs-engine. These instructions were written for and tested on Ubuntu 16.04 using a standard linux user starting in their home directory. The instructions *should* work on Bash on Ubuntu for Windows but haven't been tested.

* Installing Azure CLI 2.0
* Instll the latest version of kubectl
* Installing the ACS Engine
* Generating an SSH Key
* Create a Service Principal in the Azure Subscription
* Create a Cluster Definition File
* Create a new Resource Group for the Kubernetes Cluster
* Deploy the Kubernetes ARM Template to the Resource Group
* Connect to the Kubernetes Cluster

## Prerequisites

* Access to an existing Azure Subscription and Administrative Rights to the Subscription
* A Linux VM with the Azure CLI Installed
* **curl** is required to be installed and **vim** is highly recommended
* 5 to 10 CPU Cores available in your Azure Subscription for Standard_D2_v2 VMs
* The Azure Subscription ID used in the documentation below, **d5b31b94-d91c-4ef8-b9d0-30193e6308ee**, needs to be replaced with your Azure Subscription ID.

The Name of the Service Principal and DNS Prefix for the documentation below is **azure-k8s-dev**.

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

If you want to install the **[latest](https://github.com/Azure/acs-engine/releases/latest)** version of the acs-engine, which at the time of this writing is **v0.20.3**, run the following command.

```bash
wget https://github.com/Azure/acs-engine/releases/download/v0.20.3/acs-engine-v0.20.3-linux-amd64.tar.gz && \
tar -xzvf acs-engine-v0.20.3-linux-amd64.tar.gz && \
sudo cp acs-engine-v0.20.3-linux-amd64/acs-engine /usr/bin/acs-engine && \
sudo cp acs-engine-v0.20.3-linux-amd64/acs-engine /usr/local/bin/acs-engine
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

You should get a similar response back after a few seconds. Additionally, the App will appear in the **App Registrations** section in the **[Azure Portal](https://portal.azure.com)**.

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

Make note of the the **AppId** as it will be used for the **clientId** field in the Cluster Definition File in the next section.

## Create a Cluster Definition File

Several Cluster Definition File examples can be found in the **[ACS Engine GitHub Repository](https://github.com/Azure/acs-engine/tree/master/examples)**. The Cluster Definition File that we will be using here will be a modified version of an existing example.

The acs-engine Cluster Definition Files are JSON files that allow you to configure several options about your K8s Cluster. Below are the some of the more common options you will modify.

```text
orchestratorType         - Kubernetes (Other options include Swarm, Swarm Mode, and DCOS).
orchestratorVersion      - The version of Kubernetes to deploy, i.e. - 1.7.2, 1.8.2, 1.9.1, 1.9.3, 1.10.6.
masterProfile            - The number of Master Nodes to deploy, the DNS Prefix to use, VM Size, type of Storage to use, OS Disk Size (GB).
agentPoolProfiles        - The name of the pool, number of Nodes to deploy, VM Size, type of Storage to use, OS Disk Size (GB), Availability Set Profile, OS Type.
linuxProfile             - the admin Username and SSH Key used to access the Linux Nodes.
windowsProfile           - the admin Username and Password used to access the Windows Nodes.
servicePrincipalProfile  - The Service Principal Client ID and Service Principal Password.
```

For the purposes of this walkthrough, we are going to deploy a **vanilla** Deployment of Kubernetes 1.10.6 using the following Cluster Definition File. Copy and paste the contents below into a file called **deploy-k8s-1.10.6.json**.

```json
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes",
      "orchestratorRelease": "1.10"
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

Once you have added in the respective values of the name-pairs listed above, the **deploy-k8s-1.10.6.json** file should appear similar to what is shown below.

```json
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes",
      "orchestratorRelease": "1.10"
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

Save your changes to the **deploy-k8s-1.10.6.json** file and close it.

*Note: The full list of customizable options you can modify can be found in the **[Cluster Definition Documentation](https://github.com/Azure/acs-engine/blob/master/docs/clusterdefinition.md)**.*

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

## Connect to the Kubernetes Cluster

In order to connect to the K8s Cluster, we have to point kubectl to the kubeconfig file to use. Run the following command to set the location of the kubeconfig file; because we deployed the K8s cluster in Western Europe, we are pointing to the respective kubeconfig file.

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
k8s-linuxpool1-30657238-0   Ready     agent     15m       v1.9.3
k8s-linuxpool1-30657238-1   Ready     agent     18m       v1.9.3
k8s-master-30657238-0       Ready     master    18m       v1.9.3
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

## Deploying Kubernetes using the ACS Engine with RBAC authentication

Document: Microsoft Azure Container Service Engine - Kubernetes AAD integration Walkthrough: https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/aad.md#loginpageerror

* Standard Deployment of main stuff above
* Use this guide to deploy the **k8s-apisrv-app** and **k8s-cli-app** Azure AD applications - https://docs.microsoft.com/en-us/azure/aks/aad-integration
  * k8s-apisrv-app: serverAppID = Application ID
  * k8s-cli-app: clientAppID = Application ID
  * Tenant ID = Azure Subscription Tenant ID
* Use the **deploy-k8s-1.10.6-aad-rbac.json** deployment configuration

```json
{
  "apiVersion": "vlabs",
  "properties": {
    "orchestratorProfile": {
      "orchestratorType": "Kubernetes",
      "orchestratorRelease": "1.10"
    },
    "aadProfile": {
      "serverAppID": "b047190f-7e53-4c29-8ffb-a3951a2140e7",
      "clientAppID": "4619319a-3cab-4fa7-a4a7-d6f80b424028",
      "tenantID": "7f24e4c5-12f1-4047-afa1-c15d6927e745"
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
            "keyData": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClz3c4WwiEo1Gymum8IMwlHDd6m0kwUOKJUak1jgsfXPDZAo6Fdy+yAq845+cLEDMLObaTtrutZ6l9bsBSFGqjvAmJdQI84pP3iG7Nmo6vaiBO4gU2X2h2kN/kk645q2CTg9yOrsL3xE1vXuzFDL/tzA7FPPPsUz2nOyq4WdPNZOU2hR0pZi7JztMlfJ1edapRjYNyA35Jwp3RUX99bONYeSFQY4ySFXI273A/gwcuVVo88kVOSeb4ngjoknuiZIA55Y5c7Q+nSTJzmNVbBtsGGcc9xJ/znHJpX3Vy/mSxSYQCQyxb1JREqHW6tniFKMTeWMFRbsR30f8IuY/23FY3 azure-k8s-dev-access-key"
          }
        ]
      }
    },
    "servicePrincipalProfile": {
      "clientId": "d0fa09da-9edc-4a43-8395-676a99c620a9",
      "secret": "UseAzureKeyVault1!"
    }
  }
}
```

* Generate ACS Deployment Files from ****deploy-k8s-1.10.6-aad-rbac.json**.
* Deploy Kubernetes.
* Run the rest of these commands:

```bash
export KUBECONFIG=~/devopsautocloud/_output/azure-k8s-dev/kubeconfig/kubeconfig.westeurope.json


eval $(ssh-agent -s) ; ssh-add ~/.ssh/azure-k8s-dev-access-key

ssh -i _output/azure-k8s-dev/azureuser_rsa linuxadmin@azure-k8s-dev.westeurope.cloudapp.azure.com \
kubectl create clusterrolebinding \
aad-default-cluster-admin-binding \
--clusterrole=cluster-admin \
--user 'https://sts.windows.net/7f24e4c5-12f1-4047-afa1-c15d6927e745/#b4b933ce-8e82-47f5-8d27-4c81285824dc'

```








## Connect to the Kubernetes Dashboard

In certain circumstances you'll want to make the Kubernetes Dashboard available. Follow the instructions below to make it available from the Ubuntu Host you are working from.

*WARNING: This isn't a comprehensive guide on how to securely configure the Kubernetes Dashboard in a Production Environment; you will need to take additional steps not documented here in order to achieve this.*

Kubernetes does not have use accounts; instead access is granted directly using service accounts. To simplify access to the Kubernetes Dashboard, we are going to create a service account called **k8s-admin** in the **kube-system** namespace and grant them access to the Cluster Role **cluster-admin**. For all intents and purposes, this is granting **k8s-admin** admin access to the K8s Cluster.

Copy and paste the contents below into a file called **k8s-admin-service-account.yaml**.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: k8s-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: k8s-admin
  namespace: kube-system
```

Run the following command to add the **k8s-admin** service account to the K8s Cluster.

```bash
kubectl apply -f k8s-admin-service-account.yaml
```

Next, run the following command to access the Kubernetes Dashboard via Proxy from your Ubuntu Host.

```bash
kubectl proxy --address 0.0.0.0 --port 8080 --accept-hosts '.*' &
```

Next, browse to the Kubernetes Dashboard.

Syntax: localhost

```bash
http://localhost:8080/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```

As soon as you browse to the URL, you should be presented with a Login screen.

In order to login with a Bearer Token, you need to retrieve the token from the **k8s-admin** service account. Run the following command to do so.

```bash
kubectl -n kube-system describe secret | grep k8s-admin -A10 | awk '/token:/ {print $2}'
```

Next, select the **Token** option and copy and paste the token for the **k8s-admin** service account and then click the **Sign In** button.

*Note: You will only be able to access the Kubernetes Dashboard using **kubectl proxy** from localhost and 127.0.0.1. If you attempt to login from a different IP or Domain (privately or publically) nothing will happen after clicking Sign in button on login page. A way to circumvent this, along with authentication altogether, is presented in the next section. The contributors to the Kubernetes Dashboard were so adamant about this being a feature and not a bug, that they included it TWICE in the [documentation](https://github.com/kubernetes/dashboard/wiki/Accessing-Dashboard---1.7.X-and-above).*

[Kubernetes Dashboard Installation](https://github.com/kubernetes/dashboard/wiki/Installation#recommended-setup)

### Insecure Access to Kubernetes Dashboard

You can add the **kubernetes-dashboard** service account to the **cluster-admin** Cluster Role. This will allow you to skip the Kubernetes Dashboard Login page.

Copy and paste the contents below into a file called **insecure-dashboard-access.yaml**.

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
```

Run the following command to apply the configuration change.

```bash
kubectl apply -f k8s-admin-service-account.yaml
```

## Recommended Kubernetes Dashboard Setup




## Closing

This article covered the basics of how to quickly setup and deploy a Kubernetes Cluster running in Azure using the Azure Container Service Engine and verify it is working.
