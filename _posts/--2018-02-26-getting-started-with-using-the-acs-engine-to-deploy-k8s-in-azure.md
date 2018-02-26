---
layout: post
comments: true
title: "Dealing with Windows Server Nodes in Kubernetes"
date: 2018-02-19
---

So, you have been using Windows Server Nodes in your Kubernetes Cluster in Azure for a while now. You decide to upgrade your Cluster by redeploying the entire Cluster using the ACS Engine. Low and behold, you attempt your deployment only to find out that your Windows containers no longer deploy to the Cluster. Congratulations, you have become the victim of the Windows Server, version 1709 update that was recently pushed out.


Because the learning curve of the ACS Engine can be quite steep, I wanted to provide a reference guide allowing other individuals a quicker way to get started from scratch as well having it for future reference for myself. For the complete documentation on the Azure Container Service Engine, make sure to review the **[Official Documenation](https://github.com/Azure/acs-engine/tree/master/docs)**.

More posts will be coming in the near future detailing some of the customization options available to you in the Azure Container Service Engine.

# Overview

This article covers some of the challenges when working with Windows Server Nodes in an Azure K8s Cluster.

* Windows Server, version 1709
* https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility

## Prerequisites

* Make sure to have already completed the instructions in the previous blog post, **[Getting started with the ACS Engine to deploy Kubernetes in Azure](getting-started-with-using-the-acs-engine-to-deploy-k8s-in-azure/)**, up to and including **Create a Service Principal in the Azure Subscription**.
* Access to an existing Azure Subscription and Administrative Rights to the Subscription
* A Linux VM with the Azure CLI Installed
* **curl** is required to be installed and **vim** is highly recommended
* 5 to 10 CPU Cores available in your Azure Subscription for Standard_D2_v2 VMs
* The Azure Subscription ID used in the documentation below, **d5b31b94-d91c-4ef8-b9d0-30193e6308ee**, needs to be replaced with your Azure Subscription ID.

The Name of the Service Principal and DNS Prefix for the documentation below is **azure-k8s-dev**.

## asdf
