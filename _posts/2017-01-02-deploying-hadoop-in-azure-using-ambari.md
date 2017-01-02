---
layout: post
comments: true
title: "Deploying Hadoop in Azure using Ambari"
date: 2017-01-02
---

This article covers how to deploy a Hadoop Cluster in Azure using Apache Ambari from an ARM Template.

# Overview

Setting up an HDInsight Cluster in Azure is easy to do using the Marketplace Offering in the Azure Portal. If you are already familiar with Hadoop, you can have a cluster setup and ready
for Production use in less than 30 minutes.

However, if you are just trying to get started to use Hadoop; the default configuration of deploying a Hadoop Cluster in Azure can be quite expensive, roughly $3.50/hr. (This can be reduced to $1.75/hr
by changing the default configuration from 4 worker nodes to 1.). Additionally, the smallest Azure VMs that you can deploy in HDInsight are A3 or DS3 Servers.

Another option available to you to learn Hadoop is to deploy the Hortonworks Sandbox with HDP 2.4 VM in the Azure Marketplace. This will install almost all of the currently available Hadoop services onto
a single stand-alone VM.


In my case, I wanted the ability to deploy Hadoop in Azure on Linux VMs on any size of my choosing and to be able to control the entire deployment of Hadoop and Hadoop related services using Apache Ambari.
This means that you have several options available to you if you decide to test out Hadoop using the ARM Template below, such as:

* Deploying Hadoop to VMs smaller than A3 or DS1v2.
* Deploy Hadoop into a multi-node environment.
* Deploying minimal Hadoop features.
* Deploying only the Hadoop features you want.


While the ability to deploy a Hadoop Cluster to a set of A1 or DS1v2 VMs isn't recommended, it allows you to the opportunity to figure out several different ways to *break* Hadoop; and from my personal
experience, *breaking* a product is a great way to learn it.


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

Before deployuing the ARM Template below, make sure you have enough Azure Core Resources available before deploying.

# Deploy the new Hadoop Infrastructure to Azure using an ARM Template

Clicking on the **Deploy to Azure** button below will deploy the following

* Single Ambari Server VM
* Multiple Hadoop Server VMs

Once the Infrastructure is deployed, the following actions will take place on the Ambari Server VM

* DNS will be installed and the provided Domain Name in the ARM Template will be registered
* The Ambari Server repo is downloaded and installed on the Ambari VM.
* All deployed Servers will have their **/etc/hosts** file modified to contain the IP Address, FQDN, and Hostname of all deployed Servers
* iptables and Transparent Huge Pages is disabled on all Servers

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstarkfell%2Fstarkfell.github.io%2Fmaster%2Farm-templates%2Fdeploy-hadoop%2Fvs-project%2Fdeploy-hadoop%2FTemplates%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

All of the deployed VMs are externally accesssible via SSH on Port 22.

Below is a list of links you will find useful in accessing the deployed Hadoop Resources.


# Deploying the Hadoop Cluster using Ambari


# Closing

