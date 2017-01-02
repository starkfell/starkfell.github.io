---
layout: post
comments: true
title: "Deploying Hadoop in Azure using Ambari"
date: 2017-01-02
---

This article covers how to deploy a Hadoop Cluster running on CentOS 6.8 in Azure using Apache Ambari from an ARM Template.

# Overview

There are existing options available in the Azure Marketplace for deploying Hadoop in Azure. The first option for Production purposes is HDInsight. By running the a deployment from the Azure Marketplace
you can have a cluster setup and ready in less than 30 minutes. Additionally, there is another option avilable from Hortonworks for learning purposes in the Azure Marketplace, Hortonworks Sandbox with
HDP 2.4.This will install almost all of the currently available Hadoop services onto a single stand-alone VM.

In my case, I wanted the ability to deploy Hadoop in Azure on Linux VMs of any size of my choosing and to be able to control the entire deployment of Hadoop and Hadoop related services using Apache Ambari.
The reason I wanted to go to this level of effort was so that I could learn Hadoop all the way from an Administration standpoint to Development.

## Introduction to Apache Amabri

Apache Ambari enables system administrators to provision, manage and monitor a Hadoop cluster as well as to integrate with an existing enterprise infrastructure. By using Ambari, you can control the deployment,
management, and removal of the following Hadoop related services in a Hadoop Cluster.

* HDFS
* YARN + MapReduce2
* Tez
* Hive
* HBase
* Pig
* Sqoop
* Oozie
* ZooKeeper
* Falcon
* Storm
* Flume
* Accumulo
* Ambari Infra
* Ambari Metrics
* Atlas
* Kafka
* Knox
* Log Search
* SmartSense
* Spark
* Spark2
* Zeppelin Notebook
* Mahout
* Slider

# Prerequisites

Before deploying the ARM Template below, make sure you have enough VM cores available in your Subscription before deploying.
This ARM Template should be used **only** for learning and testing purposes.

# Deploy the new Hadoop Infrastructure to Azure using an ARM Template

Clicking on the **Deploy to Azure** button below will deploy the following

* Single Ambari Server VM
* Multiple Hadoop Server VMs

Once the Infrastructure is deployed, the following actions will take place on the Ambari Server VM

* The Ambari Server repo is downloaded and installed on the Ambari VM.
* All deployed Servers will have their **/etc/hosts** file modified to contain the IP Address, FQDN, and Hostname of all deployed Servers.
* The FQDN for each Server will be based upon the location where the ARM Template is deployed to, i.e. - West Europe = westeurope.cloudapp.azure.com.
* iptables and Transparent Huge Pages is disabled on all Servers

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstarkfell%2Fstarkfell.github.io%2Fmaster%2Farm-templates%2Fdeploy-hadoop%2Fvs-project%2Fdeploy-hadoop%2FTemplates%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

Some of the options available to you if you decide to test out Hadoop using this ARM Template include:

* Deploying Hadoop to VMs smaller than A3 or DS3v2.
* Deploy Hadoop into a multi-node environment.
* Deploying minimal Hadoop features.
* Deploying only the Hadoop features you want.

While the ability to deploy a Hadoop Cluster to a set of A1 or DS1v2 VMs isn't recommended, it is still possible. Having the opportunity to figure out several different ways to deploy Hadoop by accidentally
breaking it was one of my primary reasons for writing this ARM Template. From my personal experience, *breaking* a product is a great way to learn it (as long as it isn't in Production).

## Accessing the deployed VMs

All of the deployed VMs are externally accesssible via SSH on Port 22 from their respective Public IP Addresses.

Below is a list of default links for accessing the deployed Hadoop Resources.




# Deploying the Hadoop Cluster using Ambari

Once the ARM Template Deployment is complete, use the following syntax access the Amabari Web UI.

```powershell
http://<AMBARI_SERVER_NAME>.<LOCATION>.cloudapp.azure.com:8080
```

For the rest of this section, the Ambari Web UI will be **http://rei-ambarisrv-iy.westeurope.cloudapp.azure.com:8080**

![deploying-hadoop-in-azure-using-ambari-000]({{ site.github.url }}/media/deploying-hadoop-in-azure-using-ambari-000.jpg)

Next, login to the Ambari Server using the following credentials:

```powershell
username: admin
password: admin
```

Next, click on the **Launch Install Wizard** button under the Create a Cluster section.

![deploying-hadoop-in-azure-using-ambari-001]({{ site.github.url }}/media/deploying-hadoop-in-azure-using-ambari-001.jpg)


Next, type in a name for the Hadoop Cluster and click Next.

[]()

Next, make sure **HDP-2.5.3.0** is already selected, scroll down to the bottom of the page and click Next.

[]()

Next, copy in the FQDN values of the Hadoop Servers that you deployed and the SSH Private Key that you retrieved earlier from the Ambari Server. Afterwards,
click on the **Register and Confirm** button.

The Hadoop Hosts will be registered and checked for any potential issues, the entire process should only take a couple minutes.

[]()

After the registration is completed, ignore the warnings and click on Next.

[]()

In the Choose Services section, you have the option to add or remove any of the services you want to install on the Cluster; better still, if you choose a combination that
is missing a dependency, you will be prompted what you are missing and to add it. For the purpose of this walkthrough, scroll down to the bottom of the page and click Next.

[]()

In the Assign Masters section, you have the option to assign the master components to whichever server you want them to reside on. Leave the configuration as is by default,
scroll down to the bottom of the page and click Next.

[]()

In the Assign Slaves and Clients section, leave the default values as is and click Next.

[]()

In the Customize Services section, any of the Services that have a red number beside them require your attention. In all of the cases of this walkthrough, each of the matching
services requires that you type in a password. Do this for each service as required, scroll down to the bottom of the page and click Next.

*Note: After clicking on Next, if you recieve any configuration warnings, choose to proceed anyway.*

[]()

Review the configuration and then click on Deploy.

[]()

The selected Services will then be installed and started; on average, the entire process takes 30 minutes.

[]()




# Closing

