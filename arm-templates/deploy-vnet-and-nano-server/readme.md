# Deploy Nano Server and VNet into Azure

Clicking on the **Deploy to Azure** button below will deploy a new Nano Server into your Azure Subscription.

Some of the unique aspects of this deployment are as follows:

* Access to the Nano Server is controlled using a Network Security Group tied to the Subnet the Server is deployed to.
* The Server will only be manageable via WinRM over HTTPS on Port 5986.
* Port 80 is open for the deployment of IIS on the Nano Server.
* Port 8000 is open for the deployment of ASP.NET Core Applications.


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstarkfell%2Fstarkfell.github.io%2Fmaster%2Farm-templates%2Fdeploy-vnet-and-nano-server%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


## Related Articles

