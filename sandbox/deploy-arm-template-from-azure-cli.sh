#!/bin/bash

azure login

azure config mode arm 

# Resource Group Name
AZURE_RESOURCE_GROUP="deploy-windows-from-linux"

# retrieve the ARM Template from GitHub
wget -O azuredeploy.json https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-simple-windows/azuredeploy.json
wget -O azuredeploy.parameters.json https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-simple-windows/azuredeploy.parameters.json

# Creating a new Resource Group.
azure group create -n $AZURE_RESOURCE_GROUP -l $LOCATION

# Generating a random set of alpha-numeric characters (4) to append to the name of the Deployment.
DEPLOYMENT_NUMBER=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1 | cut -c 1-4)

# Deploying the ARM Template to the new Resource Group.
azure group deployment create -f azuredeploy.json -e azuredeploy.parameters.json -g -n "$AZURE_RESOURCE_GROUP-$DEPLOYMENT_NUMBER" &>> $LOG_FILE








