---
layout: post
title: "Practical Guide to Nested ARM Templates in Azure."
date: 2016-10-02
---

# Introduction

One area that I have found limited documentation on in regards to ARM Template Deployment is a practical guide on how to use Nested Templates 
and how to pass output from Nested Templates to other Templates. This will the topic of discussion for this post.

## Getting Started

Below is my Nested ARM Template:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "clientID": {
      "type": "string",
      "metadata": {
        "description": "Prefix for the environment (2-5 characters)"
      }
    },
    "apiVersion": {
      "type": "string",
      "metadata": {
        "description": "The Azure Resource Manager API Version to use during the Deployment."
      }
    },
    "existingVNetResourceGroup": {
      "type": "string",
      "metadata": {
        "description": "Name of the existing VNet Resource Group that the SQL Server(s) are using."
      }
    },
    "existingVNetName": {
      "type": "string",
      "metadata": {
        "description": "Name of the existing VNet that the SQL Server(s) are using."
      }
    },
    "existingSQLSubnetName": {
      "type": "string",
      "metadata": {
        "description": "Name of the existing Subnet that the SQL Server(s) are using."
      }
    },
    "sqlsrvInstances": {
      "type": "int",
      "metadata": {
        "description": "The number of SQL Server(s) being deployed."
      }
    },
    "sqlsrvLBPublicIPAddress": {
      "type": "string",
      "metadata": {
        "description": "This is the FQDN for RDP Access into the VM through the Load Balancer."
      }
    },
    "sqlsrvLBName": {
      "type": "string",
      "metadata": {
        "description": "SQL Server(s) Load Balancer Name."
      }
    },
    "sqlAlwaysOnLBName": {
      "type": "string",
      "metadata": {
        "description": "SQL Server(s) Always On Load Balancer Name."
      }
    },
    "sqlsrvLBPrivateIPAddress": {
      "type": "string",
      "metadata": {
        "description": "SQL Server(s) Load Balancer's Private IP Address."
      }
    }
  },
  "resources": [
    {
      "name": "[parameters('sqlsrvLBPublicIPAddress')]",
      "type": "Microsoft.Network/publicIPAddresses",
      "location": "[resourceGroup().location]",
      "apiVersion": "[parameters('apiVersion')]",
      "tags": {
        "displayName": "[parameters('sqlsrvLBPublicIPAddress')]"
      },
      "properties": {
        "publicIPAllocationMethod": "Dynamic",
        "idleTimeoutInMinutes": 4,
        "dnsSettings": {
          "domainNameLabel": "[parameters('sqlsrvLBPublicIPAddress')]"
        }
      }
    },
    {
      "apiVersion": "2015-06-15",
      "name": "[parameters('sqlAlwaysOnLBName')]",
      "type": "Microsoft.Network/loadBalancers",
      "location": "[resourceGroup().location]",
      "tags": {
        "displayName": "[parameters('sqlAlwaysOnLBName')]"
      },
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "sqlAOLBFrontEnd",
            "properties": {
              "privateIPAllocationMethod": "Static",
              "privateIPAddress": "[parameters('sqlsrvLBPrivateIPAddress')]",
              "subnet": {
                "id": "[concat('/subscriptions/',subscription().subscriptionId,'/resourceGroups/', parameters('existingVNetResourceGroup'), '/providers/Microsoft.Network/virtualNetworks/', parameters('existingVNetName'), '/subnets/', parameters('existingSQLSubnetName'))]"
              }
            }
          }
        ],
        "backendAddressPools": [
          {
            "name": "sqlAOLBBackendPool"
          }
        ],
        "loadBalancingRules": [
          {
            "name": "sqlAOEndPointListener",
            "properties": {
              "backendAddressPool": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlAlwaysOnLBName')),'/backendAddressPools/sqlAOLBBackendPool')]"
              },
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlAlwaysOnLBName')),'/frontendIPConfigurations/sqlAOLBFrontEnd')]"
              },
              "protocol": "Tcp",
              "frontendPort": 1433,
              "backendPort": 1433,
              "enableFloatingIP": true,
              "probe": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlAlwaysOnLBName')),'/probes/sqlAOEndpointProbe')]"
              }
            }
          }
        ],
        "probes": [
          {
            "name": "sqlAOEndpointProbe",
            "properties": {
              "protocol": "tcp",
              "port": 59999,
              "intervalInSeconds": 5,
              "numberOfProbes": 2
            }
          }
        ]
      }
    },
    {
      "apiVersion": "[parameters('apiVersion')]",
      "name": "[parameters('sqlsrvLBName')]",
      "type": "Microsoft.Network/loadBalancers",
      "location": "[resourceGroup().location]",
      "tags": {
        "displayName": "[parameters('sqlsrvLBName')]"
      },
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', parameters('sqlsrvLBPublicIPAddress'))]"
      ],
      "properties": {
        "frontendIPConfigurations": [
          {
            "name": "sqlsrvLoadBalancerFrontEnd",
            "properties": {
              "publicIPAddress": {
                "id": "[resourceId('Microsoft.Network/publicIPAddresses', parameters('sqlsrvLBPublicIPAddress'))]"
              }
            }
          }
        ],
        "backendAddressPools": [
          {
            "name": "sqlsrvLoadBalancerBackendPool"
          }
        ],
        "inboundNatRules": [
          {
            "name": "rdp-vm-0",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/frontendIPConfigurations/sqlsrvLoadBalancerFrontEnd')]"
              },
              "protocol": "tcp",
              "frontendPort": 50000,
              "backendPort": 3389,
              "enableFloatingIP": false
            }
          },
          {
            "name": "rdp-vm-1",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/frontendIPConfigurations/sqlsrvLoadBalancerFrontEnd')]"
              },
              "protocol": "tcp",
              "frontendPort": 50001,
              "backendPort": 3389,
              "enableFloatingIP": false
            }
          }
        ],
        "loadBalancingRules": [
          {
            "name": "LBRulePort80",
            "properties": {
              "frontendIPConfiguration": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/frontendIPConfigurations/sqlsrvLoadBalancerFrontEnd')]"
              },
              "backendAddressPool": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/backendAddressPools/sqlsrvLoadBalancerBackendPool')]"
              },
              "protocol": "tcp",
              "frontendPort": 80,
              "backendPort": 80,
              "enableFloatingIP": false,
              "idleTimeoutInMinutes": 5,
              "probe": {
                "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/probes/httpTCPProbe')]"
              }
            }
          }
        ],
        "probes": [
          {
            "name": "httpTCPProbe",
            "properties": {
              "protocol": "tcp",
              "port": 80,
              "intervalInSeconds": 5,
              "numberOfProbes": 2
            }
          }
        ]
      }
    },
    {
      "name": "[concat(parameters('sqlsrvVMName'), '-NIC-', copyindex())]",
      "type": "Microsoft.Network/networkInterfaces",
      "location": "[resourceGroup().location]",
      "apiVersion": "[parameters('apiVersion')]",
      "copy": {
        "name": "sqlsrvNICLoop",
        "count": "[parameters('sqlsrvInstances')]"
      },
      "dependsOn": [
        "[concat('Microsoft.Network/loadBalancers/', parameters('sqlsrvLBName'))]",
        "[concat('Microsoft.Network/loadBalancers/', parameters('sqlAlwaysOnLBName'))]"
      ],
      "tags": {
        "displayName": "sqlsrvNICs"
      },
      "properties": {
        "ipConfigurations": [
          {
            "name": "primary-ipconfig",
            "properties": {
              "privateIPAllocationMethod": "Dynamic",
              "subnet": {
                "id": "[concat('/subscriptions/',subscription().subscriptionId,'/resourceGroups/', parameters('existingVNetResourceGroup'), '/providers/Microsoft.Network/virtualNetworks/', parameters('existingVNetName'), '/subnets/', parameters('existingSQLSubnetName'))]"
              },
              "loadBalancerBackendAddressPools": [
                {
                  "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlAlwaysOnLBName')), '/backendAddressPools/sqlAOLBBackendPool')]"
                }
              ],
              "loadBalancerInboundNatRules": [
                {
                  "id": "[concat(resourceId('Microsoft.Network/loadBalancers', parameters('sqlsrvLBName')),'/inboundNatRules/rdp-vm', '-', copyindex())]"
                }
              ]

            }
          }
        ]
      }
    }
  ]
}
```


## Gotcha #348: Non-Existent Property Values from Outputs from deployed Resources

So you've checked over your ARM Template thoroughly, you've determined that the Property you are trying to reference in your Outputs actually exists, but
you aren't getting any results back. The next thing you should check is to see if the Property you are referencing actually has a value.

One particular resource that is likely to give you a hell of a time is the Public IP Address Resource as the PublicIPAddress Property will not have a value until
the Resource is assigned to a NIC Card or Load Balancer.

