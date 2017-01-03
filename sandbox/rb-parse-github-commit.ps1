<#

.SYNOPSIS
This Azure Automation Runbook, when triggered via Webhook, will look for Nano Server VMs with a Tag Text of 'CoreWebAppDemo' and attempt to deploy
the .NET Core Web Application to that Nano Server.

.DESCRIPTION

.PARAMETER WebhookData
This is the WebhookData that is automatically passed from the Webhook to the Runbook. The Runbook will exit if this Data Object is empty.

.NOTES
Filename:   rb-parsing-github-webhooks.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

.EXAMPLE
./rb-parsing-github-webhooks.ps1

#>

param(
    [Object]$WebhookData
)

# Parsing information out of the WebhookData.
If ($WebhookData)
{
    Write-Output "RAW WEBHOOK DATA"
    $WebhookData | FL *
    Write-Output "                "

    # Parsing the RequestBody from the WebhookData.
    $RequestBody = ConvertFrom-Json -InputObject $WebhookData.RequestBody

    Write-Output "REQUEST BODY"
    $RequestBody
    Write-Output "            "


    # Commit Message
    $Message = $RequestBody.head_commit.message

    # Name of person who made the commit.
    $Name = $RequestBody.head_commit.author.name

    # Username of the person who pushed the update.
    $Username = $RequestBody.pusher.name

    # E-mail address of the person pushed the update.
    $Email = $RequestBody.pusher.email

    Write-Output "Commit Message:  $Message "
    Write-Output "Name:            $Name "
    Write-Output "Username:        $Username "    
    Write-Output "E-mail Address:  $Email "

    exit 0
    
    #$Login = $RequestBody.Sender.login
    #Write-Output "Login: $Login "
    #$Login
}


# If this Runbook is not triggered from a Webhook or no WebhookData is found, the script will exit.
If (!$WebhookData)
{
	Write-Output "Runbook wasn't triggered from Webhook or no WebhookData was passed. Exiting."
	exit 1
}

