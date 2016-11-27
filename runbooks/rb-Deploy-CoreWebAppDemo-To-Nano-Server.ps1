<#

.SYNOPSIS
This Azure Automation Runbook, when triggered via Webhook, will look for Nano Server VMs with a Tag Text of 'CoreWebAppDemo' and attempt to deploy
the .NET Core Web Application to that Nano Server.

.DESCRIPTION
When this Runbook is triggered via the Webhook: the rb-CoreWebAppDemo-Webhook, the following will occur:
- Verify that the Runbook is being triggered from a Webhook.
- Retrieve All Azure VMs that are tagged for the 'CoreWebAppDemo' Deployment.
- Login to the Azure Subscription using the Azure Automation Account.
- Retrieve the Azure Automation Credentials for the Nano Server.
- A Session is then created to the Nano Server and the following actions are taken
  - Check if the CoreWebAppDemo IIS Website already exists.
  - Stop the CoreWebAppDemo IIS Website before downloading and extracting the new Application.
  - Stop the IIS Service on the Nano Server
  - Download the .NET Core Web Application Demo from GitHub.
  - Extract the CoreWebAppDemo.zip file to C:\CoreWebAppDemo.
  - Check the original 'processPath' value of web.config file.
  - Change the processPath="dotnet" to processPath="C:\dotnet\dotnet.exe" in the web.config file.
  - Check the modified 'processPath' value of web.config file.
  - Check if the CoreWebAppDemo8000 Firewall Rule already exists.
    - Add the CoreWebAppDemo8000 Firewall Rule if it wasn't found.
  - Import the IIS Administration Module.
  - Check if the CoreWebAppDemo IIS Website already exists.
  - Add the CoreWebAppDemo IIS Website if it wasn't found.
  - Start the IIS Service on the Nano Server.
  - Start the .NET Core Web Application Demo Site.
  - Results of the deployment are added to a new PSCustomObject that are added in the $Results Variable.
- Results are returned to the Output blade of the Job of the Runbook.

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

	Write-Output "Runbook triggered from Webhook $WebhookName by $From on $Date."
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

# Retrieve All Azure VMs that are tagged for the 'CoreWebAppDemo' Deployment.
[array]$VMs = Get-AzureRmVM `
    -ErrorAction SilentlyContinue `
    -ErrorVariable RetrieveVMError `
    | Where-Object {$_.TagsText -match "CoreWebAppDemo"}

If ($RetrieveVMError)
{
	Write-Output "There was a problem attempting to retrieve Virtual Machines from the Subscription. - $($RetrieveVMError.Exception)"
    exit 2
}

If (!$VMs)
{
	Write-Output "There are either no Virtual Machines in this Subscription or they were unable to retrieved from the Subscription."
    exit 0
}

If ($VMs)
{
	Write-Output "Virtual Machines tagged for 'CoreWebAppDemo' Deployment were Successfully retrieved from the Subscription."
}

# Retrieving the Nano Server Credentials from Azure Automation Assets.
$NanoServerCreds = Get-AutomationPSCredential `
    -Name "NanoServerCreds" `
    -ErrorAction SilentlyContinue `
    -ErrorVariable NanoServerCredsError

If (!$NanoServerCredsError)
{
    Write-Output "Successfully retrieved the Nano Server Credentials from the Azure Automation Account."
}

If ($NanoServerCredsError)
{
    Write-Output "There were was problem retrieving the Nano Server Credentials for the Azure Automation Account. - $($NanoServerCredsError.Exception)"
    exit 2
}

Foreach ($VM in $VMs)
{
    # Setting up Connection URI.
    $ConnectionUri = "https://" + "$($VM.Name)" + "." + "$($VM.Location)" + ".cloudapp.azure.com:5986"

    $Results = Invoke-Command `
        -connectionUri $ConnectionUri `
        -credential $NanoServerCreds `
        -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) `
        -ScriptBlock {param($VM)

            # Checking if the CoreWebAppDemo IIS Website already exists.
            Get-IISSite `
                -Name "CoreWebAppDemo" `
                -WarningAction SilentlyContinue `
                -WarningVariable IISInitialSiteCheck

            If (!$IISInitialSiteCheck)
            {
                $IISInitialSiteCheckResult = "CoreWebAppDemo IIS Site found on $($VM.Name). Stopping the Website."

                # Stopping the CoreWebAppDemo IIS Website before downloading and extracting the new Application.
                Stop-IISSite `
                    -Name "CoreWebAppDemo" `
                    -Confirm:$false `
                    -ErrorAction SilentlyContinue `
                    -ErrorVariable StopIISSiteError

                If (!$StopIISSiteError)
                {
                    $StopIISSiteErrorResult = "Successfully stopped the CoreWebAppDemo IIS Website on $($VM.Name)"
                }

                If ($StopIISSiteError)
                {
                    $StopIISSiteErrorResult = "Failed to stop the CoreWebAppDemo IIS Website on $($VM.Name)"
                }
            }
 
            # Stopping the IIS Service on the Nano Server
            Stop-Service `
                -Name W3SVC `
                -ErrorAction SilentlyContinue `
                -ErrorVariable StopIISServiceError

            If (!$StopIISServiceError)
            {
                $StopIISServiceErrorResult = "Successfullly Stopped the IIS Service on $($VM.Name). Pausing for 5 seconds before continuing."
                Start-Sleep -Seconds 5
            }
            
            If ($StopIISServiceError)
            {
                $StopIISServiceErrorResult = "Failed to Stop the IIS Service on $($VM.Name). - $($StopIISServiceError.Exception)"
            }

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

            # Extracting the CoreWebAppDemo.zip file to C:\CoreWebAppDemo.
            Expand-Archive `
                -LiteralPath "C:\Windows\Temp\CoreWebAppDemo.zip" `
                -DestinationPath "C:\CoreWebAppDemo" `
                -ErrorAction SilentlyContinue `
                -ErrorVariable ExpandArchiveError `
                -Force

            If (!$ExpandArchiveError)
            {
                $ExpandArchiveErrorResult = "Successfully extracted CoreWebAppDemo.zip to C:\CoreWebAppDemo on $($VM.Name)."
            }
            
            If ($ExpandArchiveError)
            {
                $ExpandArchiveErrorResult = "Failed to extract CoreWebAppDemo.zip to C:\CoreWebAppDemo on $($VM.Name). - $($ExpandArchiveError.Exception)"
            }            

            # Checking the original 'processPath' value of web.config file.
            $OriginalProcessPath = (Get-Content "C:\CoreWebAppDemo\web.config") `
                | Select-String "processPath=`"dotnet`""

            If (!$OriginalProcessPath)
            {
                $OriginalProcessPathResult = "processPath=`"dotnet`" entry not found in C:\CoreWebAppDemo\web.config."
            }

            If ($OriginalProcessPath)
            {
                $OriginalProcessPathResult = "processPath=`"dotnet`" entry found in C:\CoreWebAppDemo\web.config."

                # Changing the processPath="dotnet" to processPath="C:\dotnet\dotnet.exe" in the web.config file.
                (Get-Content C:\CoreWebAppDemo\web.config) `
                    -replace "processPath=`"dotnet`"", "processPath=`"C:\dotnet\dotnet.exe`"" `
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
            }

            # Checking the modified 'processPath' value of web.config file.
            $ModifiedProcessPath = (Get-Content "C:\CoreWebAppDemo\web.config") `
                | Select-String "processPath=`"C:\\dotnet\\dotnet.exe`""

            If (!$ModifiedProcessPath)
            {
                $ModifiedProcessPathResult = "processPath=`"C:\dotnet\dotnet.exe`" entry not found in C:\CoreWebAppDemo\web.config."
            }

            If ($ModifiedProcessPath)
            {
                $ModifiedProcessPathResult = "processPath=`"C:\dotnet\dotnet.exe`" entry found in C:\CoreWebAppDemo\web.config."
            }

            # Checking if the CoreWebAppDemo8000 Firewall Rule already exists.
            Get-NetFirewallRule `
                -Name "CoreWebAppDemo8000" `
                -ErrorAction SilentlyContinue `
                -ErrorVariable FirewallRuleCheck `
                | Out-Null

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
                    -ErrorVariable NewFirewallRuleError `
                    | Out-Null

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
            Import-Module IISAdministration `
                -ErrorAction SilentlyContinue `
                -ErrorVariable ImportIISModuleCheck `
                | Out-Null

            If (!$ImportIISModuleCheck)
            {
                $ImportIISModuleCheckResult = "Successfully imported the IIS Administration Module on $($VM.Name)."
            }

            If ($ImportIISModuleCheck)
            {
                $ImportIISModuleCheckResult = "Failed to import the IIS Administration Module onon $($VM.Name)."
            }

            # Checking if the CoreWebAppDemo IIS Website already exists.            
            Get-IISSite `
                -Name "CoreWebAppDemo" `
                -WarningAction SilentlyContinue `
                -WarningVariable IISSiteCheck `
                | Out-Null

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
                    -ErrorVariable NewIISSiteError `
                    | Out-Null

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
                -ErrorVariable StartServiceError `
                | Out-Null

            If (!$StartServiceError)
            {
                $StartServiceErrorResult = "Successfully Started the IIS Service on $($VM.Name). Pausing 5 seconds before continuing."
                Start-Sleep -Seconds 5
            }

            If ($StartServiceError)
            {
                $StartServiceErrorResult = "Failed to Start the IIS Service on $($VM.Name). - $($StartServiceError.Exception)"
            }

            # Starting the .NET Core Web Application Demo Site.
            Start-IISSite `
                -Name CoreWebAppDemo `
                -ErrorAction SilentlyContinue `
                -ErrorVariable StartSiteError `
                | Out-Null

            If (!$StartSiteError)
            {
                $StartSiteErrorResult = "Successfully Started the CoreWebAppDemo Site on $($VM.Name)."
            }

            If ($StartSiteError)
            {
                $StartSiteErrorResult = "Failed to Start the CoreWebAppDemo Site on $($VM.Name) - $($StartSiteError.Exception)."
            }

            # Adding the Results of the deployment to a new PSCustomObject that will be outputted in the $Results Variable.
            New-Object PSObject `
            -Property @{
                IISInitialSiteCheckResult      = $IISInitialSiteCheckResult
                StopIISSiteErrorResult         = $StopIISSiteErrorResult
                StopIISServiceErrorResult      = $StopIISServiceErrorResult
                CoreWebAppDownloadErrorResult  = $CoreWebAppDownloadErrorResult
                ExpandArchiveErrorResult       = $ExpandArchiveErrorResult
                SetContentErrorResult          = $SetContentErrorResult
                ModifiedProcessPathResult      = $ModifiedProcessPathResult
                FirewallRuleCheckResult        = $FirewallRuleCheckResult
                NewFirewallRuleErrorResult     = $NewFirewallRuleErrorResult
                ImportIISModuleCheckResult     = $ImportIISModuleCheckResult
                IISSiteCheckResult             = $IISSiteCheckResult
                NewIISSiteErrorResult          = $NewIISSiteErrorResult
                StartServiceErrorResult        = $StartServiceErrorResult
                StartSiteErrorResult           = $StartSiteErrorResult
            }
        } -ArgumentList $VM

    # Returned Results.
    $Results.IISInitialSiteCheckResult
    $Results.StopIISSiteErrorResult
    $Results.StopIISServiceErrorResult
    $Results.CoreWebAppDownloadErrorResult
    $Results.ExpandArchiveErrorResult
    $Results.SetContentErrorResult
    $Results.ModifiedProcessPathResult
    $Results.FirewallRuleCheckResult
    $Results.NewFirewallRuleErrorResult
    $Results.ImportIISModuleCheckResult
    $Results.IISSiteCheckResult
    $Results.NewIISSiteErrorResult
    $Results.StartServiceErrorResult
    $Results.StartSiteErrorResult
}
