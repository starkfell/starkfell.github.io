<#

.SYNOPSIS
This Azure Automation Runbook, when triggered via Webhook, will look for Nano Server VMs with a Tag Text of 'CoreWebAppDemo' and attempt to deploy
the .NET Core Web Application to that Nano Server.

.DESCRIPTION
When this Runbook is triggered via the Webhook: the rb-CoreWebAppDemo-Webhook, the following will occur:
 - WebhookData from the Webhook will be parsed and assigned to their respective ARM Template Deployment Parameters.
 - Retrieve All Azure VMs that are tagged for the 'CoreWebAppDemo'.

.PARAMETER WebhookData
This is the WebhookData that is automatically passed from the Webhook to the Runbook. The Runbook will exit if this Data Object is empty.

.NOTES
Filename:   rb-Deploy-CoreWebAppDemo-To-Nano-Server.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

.EXAMPLE
./rb-Deploy-CoreWebAppDemo-To-Nano-Server.ps1

#>

param(
    [Object]$WebhookData
)

# Parsing information out of the WebhookData.
If ($WebhookData)
{
	$WebhookName    = $WebhookData.WebhookName
	$WebhookHeaders = $WebhookData.RequestHeader
	$WebhookBody    = $WebhookData.RequestBody
	
	$From = $WebhookHeaders.From
	$Date = $WebhookHeaders.Date
	
	# Converting the Values from the WebhookBody from JSON.
	$WebhookDataParameters = ConvertFrom-Json -InputObject $WebhookBody
	
	# Parameter Values passed from the WebhookData.
	$VMName = $WebhookDataParameters.VMName

	Write-Output "Runbook triggered from Webhook $WebhookName on $VMName by $From on $Date."
}

# If this Runbook is not triggered from a Webhook or no WebhookData is found, the script will exit.
If (!$WebhookData)
{
	Write-Output "Runbook wasn't triggered from Webhook or no WebhookData was passed. Exiting."
	exit 1
}

# Logging into the Azure Subscription using the Azure Automation Run-As Connection.
$ConnectionName = "AzureRunAsConnection"

try
{
    # Get the connection "AzureRunAsConnection "
    $ServicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName         

    Write-Output "Logging in to Azure."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
		| Out-Null
}
catch 
{
    if (!$ServicePrincipalConnection)
    {
        $ErrorMessage = "Connection $ConnectionName not found."
        throw $ErrorMessage
    } 
	else
	{
        Write-Error -Message $_.Exception
        throw $_.Exception
	}
}

Write-Output "Successfully Logged in to Azure."

# Retrieve All Azure VMs that are tagged for the 'CoreWebAppDemo' DSC Configuration.
[array]$VMs = Get-AzureRmVM | Where-Object {$_.TagsText -match "CoreWebAppDemo"}

If ($?)
{
	Write-Output "The Virtual Machines were Successfully retrieved from the Subscription."
}

If (!$?)
{
	Write-Output "There are either no Virtual Machines in this Subscription or they were unable to retrieved from the Subscription."
}

# Retrieving the Nano Server Credentials from Azure Automation Assets.
$NanoServerCreds = Get-AutomationPSCredential -Name "NanoServerCreds"

$Results = Invoke-Command `
	-connectionUri "https://rei-nanosrv-at.westeurope.cloudapp.azure.com:5986" `
    -credential $NanoServerCreds `
    -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) `
    -ScriptBlock {
        # Determining if the .NET Core Web Application Demo  is already installed.
        Get-Item -Path "C:\CoreWebAppDemo\web.config" `
            -ErrorAction SilentlyContinue `
            -ErrorVariable CoreWebAppCheck

        If ($CoreWebAppCheck)
        {
            $CoreWebAppCheckResult = "CoreWebAppDemo is already installed on $($VM.Name)."
        }

        If (!$CoreWebAppCheck)
        {
            $CoreWebAppCheckResult = "CoreWebAppDemo was not found on $($VM.Name). - $($CoreWebAppCheck.Exception)"

            # Downloading the .NET Core Web Application Demo from GitHub.
            Invoke-WebRequest `
                -Uri "https://github.com/starkfell/starkfell.github.io/blob/master/apps/continuous-deployment-to-nano-server-in-azure/CoreWebAppDemo.zip?raw=true" `
                -OutFile "C:\Windows\Temp\CoreWebAppDemo.zip" `
                -ErrorAction SilentlyContinue `
                -ErrorVariable CoreWebAppDownloadError

            If (!$CoreWebAppDownloadError)
            {
                $CoreWebAppDownloadErrorResult = "Successfully downloaded CoreWebAppDemo.zip from GitHub on $($VM.Name)."
            }
            
            If ($CoreWebAppDownloadError)
            {
                $CoreWebAppDownloadErrorResult = "Failed to download CoreWebAppDemo.zip from GitHub on $($VM.Name). - $($CoreWebAppDownloadError.Exception)"
            }
        }

        # Extracting the CoreWebAppDemo.zip file to C:\CoreWebAppDemo.
        Expand-Archive `
            -LiteralPath "C:\Windows\Temp\CoreWebAppDemo.zip" `
            -DestinationPath "C:\CoreWebAppDemo" `
            -ErrorAction SilentlyContinue `
            -ErrorVariable ExpandArchiveError

        If (!$ExpandArchiveError)
        {
            $ExpandArchiveErrorResult = "Successfully downloaded CoreWebAppDemo.zip from GitHub on $($VM.Name)."
        }
           
        If ($ExpandArchiveError)
        {
            $ExpandArchiveErrorResult = "Failed to download CoreWebAppDemo.zip from GitHub on $($VM.Name). - $($ExpandArchiveError.Exception)"
        }            

        # Changing the processPath="dotnet" to processPath="C:\dotnet\dotnet.exe" in the web.config file.
        (Get-Content C:\CoreWebAppDemo\web.config) `
            -replace 'dotnet', 'C:\dotnet\dotnet.exe' `
            | Set-Content C:\CoreWebAppDemo\web.config `
                -ErrorAction SilentlyContinue `
                -ErrorVariable SetContentError

        If (!$SetContentError)
        {
            $SetContentErrorResult = "Successfully updated processPath in web.config File on $($VM.Name)."
        }

        If ($SetContentError)
        {
            $SetContentErrorResult = "Failed to update processPath in web.config File on $($VM.Name). - $($SetContentError.Exception)"
        }

        # Checking if the CoreWebAppDemo8000 Firewall Rule already exists.
        Get-NetFirewallRule `
            -Name "CoreWebAppDemo8000" `
            -ErrorAction SilentlyContinue `
            -ErrorVariable FirewallRuleCheck

        If (!$FirewallRuleCheck)
        {
            $FirewallRuleCheckResult = "Firewall Rule 'CoreWebAppDemo8000' already exists on $($VM.Name)."
        }

        # Adding CoreWebAppDemo8000 Firewall Rule if it wasn't found.
        If ($FirewallRuleCheck)
        {
            $FirewallRuleCheckResult = "Firewall Rule 'CoreWebAppDemo8000' was not found. Adding new Rule."

            New-NetFirewallRule `
                -Name "CoreWebAppDemo8000" `
                -DisplayName "CoreWebAppDemo - HTTP (8000)" `
                -Protocol tcp -LocalPort 8000 `
                -Action Allow `
                -ErrorAction SilentlyContinue `
                -ErrorVariable NewFirewallRuleError

            If (!$NewFirewallRuleError)
            {
                $NewFirewallRuleErrorResult = "Successfully added Firewall Rule 'CoreWebAppDemo8000' to $($VM.Name)."
            }

            If ($NewFirewallRuleError)
            {
                $NewFirewallRuleErrorResult = "Failed to add Firewall Rule 'CoreWebAppDemo8000' to $($VM.Name). - $($NewFirewallRuleError.Exception)"
            }                               
        }

        # Importing the IIS Administration Module.
        Import-Module IISAdministration

        # Checking if the CoreWebAppDemo IIS Website already exists.            
        Get-IISSite `
            -Name "CoreWebAppDemo" `
            -WarningAction SilentlyContinue `
            -WarningVariable IISSiteCheck

        If (!$IISSiteCheck)
        {
            $IISSiteCheckResult = "CoreWebAppDemo IIS Site already exists on $($VM.Name)."
        }

        # Adding the CoreWebAppDemo IIS Website if it wasn't found.
        If ($IISSiteCheck)
        {
            $IISSiteCheckResult = "CoreWebAppDemo IIS Site not found on $($VM.Name). - $($IISSiteCheck.Exception)"

            Import-Module IISAdministration
            New-IISSite `
                -Name "CoreWebAppDemo" `
                -PhysicalPath C:\CoreWebAppDemo `
                -BindingInformation "*:8000:" `
                -ErrorAction SilentlyContinue `
                -ErrorVariable NewIISSiteError

            If (!$NewIISSiteError)
            {
                $NewIISSiteErrorResult = "Successfully added CoreWebAppDemo IIS Site to $($VM.Name)."
            }

            If ($NewIISSiteError)
            {
                $NewIISSiteErrorResult = "Failed to add CoreWebAppDemo IIS Site to $($VM.Name). - $($NewIISSiteError.Exception)"
            }
        }

        # Starting the IIS Service on the Nano Server.
        Start-Service `
            -Name W3SVC `
            -ErrorAction SilentlyContinue `
            -ErrorVariable StartServiceError

        If (!$StartServiceError)
        {
            $StartServiceErrorResult = "Successfullly Started the IIS Service on $($VM.Name)."
        }
           
        If ($StartServiceError)
        {
            $StartServiceErrorResult = "Failed to Start the IIS Service on $($VM.Name). - $($StartServiceError.Exception)"
        }
            
        # Starting the .NET Core Web Application Demo Site.
        Start-IISSite `
            -Name CoreWebAppDemo `
            -ErrorAction SilentlyContinue `
            -ErrorVariable StartSiteError
            
        If (!$StartSiteError)
        {
            $StartSiteErrorResult = "Successfullly Started the CoreWebAppDemo Site on $($VM.Name)."
        }
           
        If ($StartSiteError)
        {
            $StartSiteErrorResult = "Failed to Start the CoreWebAppDemo Site on $($VM.Name) - $($StartSiteError.Exception)."
        }

        # Adding Results of Configuration to a new PSCustomObject that will be outputted in the $Results Variable.
        New-Object PSObject `
        -Property @{
            CoreWebAppCheckResult          = $CoreWebAppCheckResult
            CoreWebAppDownloadErrorResult  = $CoreWebAppDownloadErrorResult
            ExpandArchiveErrorResult       = $ExpandArchiveErrorResult
            SetContentErrorResult          = $SetContentErrorResult
            FirewallRuleCheckResult        = $FirewallRuleCheckResult
            NewFirewallRuleErrorResult     = $NewFirewallRuleErrorResult
            IISSiteCheckResult             = $IISSiteCheckResult
            NewIISSiteErrorResult          = $NewIISSiteErrorResult
            StartServiceErrorResult        = $StartServiceErrorResult
            StartSiteErrorResult           = $StartSiteErrorResult
        }        
    }

# Returned Results.
$Results.CoreWebAppCheckResult
$Results.CoreWebAppDownloadErrorResult
$Results.ExpandArchiveErrorResult
$Results.SetContentErrorResult
$Results.FirewallRuleCheckResult
$Results.NewFirewallRuleErrorResult
$Results.IISSiteCheckResult
$Results.NewIISSiteErrorResult
$Results.StartServiceErrorResult
$Results.StartSiteErrorResult


