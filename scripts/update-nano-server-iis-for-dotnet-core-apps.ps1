<#

.SYNOPSIS
This script updates the IIS Configuration to work with .NET Core on a target Nano Server.

.DESCRIPTION
This script updates the IIS Configuration to work with .NET Core on a target Nano Server.

Once this script is launched, the following actions will occur:

- A new PowerShell Session will be created targeting the Nano Server.
    - Prompt will appear to login to the targeted Nano Server using the 'Username' Parameter.
- Check to see if IIS has already been updated on the Nano Server. If the update is found, script will exit.
- IIS Configuration is updated to work with .NET Core.
- The PowerShell Session will be removed and Results of the process returned to STDOUT.

.PARAMETER NanoServerName
The IP Address or the FQDN of the Nano Server.

.PARAMETER Username
This is either the Administrative Account of the Nano Server or a Domain Account with rights to login to the Nano Server.

.PARAMETER DomainName
The Domain Name of the Domain Account with rights to login to the Nano Server. i.e. - CONTOSO.

.NOTES
Filename:   update-nano-server-iis-for-dotnet-core-apps.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

The section in this Script for updating the IIS Configuration on the Nano Server is a modified version from the following Microsoft Documentation article:

https://docs.microsoft.com/en-us/aspnet/core/tutorials/nano-server

.EXAMPLE
Updating the IIS Configuration on an existing Nano Server joined to a Domain.

./update-nano-server-iis-for-dotnet-core-apps.ps1 `
-NanoServerName nanosrv-vm-5 `
-Username serveradmin `
-DomainName lumagate.com

Updating the IIS Configuration on an existing stand-alone Nano Server.

./update-nano-server-iis-for-dotnet-core-apps.ps1 `
-NanoServerName nanosrv-vm-5 `
-Username administrator

#>

param
(
   [Parameter(Mandatory)]
    [String]$NanoServerName,

    [Parameter(Mandatory)]
    [String]$Username,

    [String]$DomainName
)

# Starting the WinRM Service if it isn't already Running.
If ((Get-Service | Where-Object {$_.Name -match "WinRM"}).Status -ne "Running")
{
    Start-Service -Name "WinRM"

    If ($?)
    {
        Write-Output "WinRM Service Started on Localhost."
    }

    If (!$?)
    {
        Write-Output "Failed to Start WinRM Service on Localhost."
        exit 2
    }
}

# Checking to see if the Public IP FQDN or Address of the Nano Server already exists in TrustedHosts.
If((Get-Item WSMan:\localhost\Client\TrustedHosts).Value -match $NanoServerName)
{
    Write-Output "$NanoServerName already exists in TrustedHosts."
}

If((Get-Item WSMan:\localhost\Client\TrustedHosts).Value -notmatch $NanoServerName)
{
    Write-Output "$NanoServerName was not found in TrustedHosts."

    # Adding The Public IP FQDN or Address of the Nano Server to TrustedHosts.
    Set-Item WSMan:\localhost\Client\TrustedHosts $NanoServerName -Concatenate -Force

    If ($?)
    {
        Write-Output "$NanoServerName was Successfully added to TrustedHosts in the WS-Management Configuration."
    }

    If (!$?)
    {
        Write-Output "Failed to add $NanoServerName to TrustedHosts in the WS-Management Configuration."
    }
}

If ($DomainName)
{
    # Creating a new PowerShell Session to connect to the Nano Server using Domain Credentials.
    $Session = New-PSSession `
        -ComputerName $NanoServerName `
        -Credential $DomainName\$Username `
        -ErrorAction SilentlyContinue `
        -ErrorVariable PSSessionError

    If (!$PSSessionError)
    {
        Write-Output "New PowerShell Session created Successfully using Domain Credentials."
    }

    If ($PSSessionError)
    {
        Write-Output "Failed to create a new PowerShell Session using Domain Credentials."
        Write-Output $PSSessionError.Exception
        exit 2
    }
}

If (!$DomainName)
{
    # Creating a new PowerShell Session to connect to the Nano Server using Local Credentials.
    $Session = New-PSSession `
        -ComputerName $NanoServerName `
        -Credential ~\$Username `
        -ErrorAction SilentlyContinue `
        -ErrorVariable PSSessionError

    If (!$PSSessionError)
    {
        Write-Output "New PowerShell Session created Successfully using Local Credentials."
    }

    If ($PSSessionError)
    {
        Write-Output "Failed to create a new PowerShell Session using Local Credentials."
        Write-Output $PSSessionError.Exception
        exit 2
    }
}

# Connecting to the PowerShell Session and updating the Nano Server.
$Results = Invoke-Command `
    -Session $Session `
    -ScriptBlock {param($NanoServerName)

    # Determining if the IIS Configuration on the Nano Server has been updated.
    Get-Item `
        -Path "C:\Windows\System32\inetsrv\config\applicationHost_AfterInstallingANCM.config" `
        -ErrorAction SilentlyContinue `
        -ErrorVariable FileCheck

    If (!$FileCheck)
    {
        $FileCheckResult = "IIS Configuration updates for IIS found on $NanoServerName."
    }

    If ($FileCheck)
    {
        $FileCheckResult = "IIS Configuration updates for IIS not found on $NanoServerName."

        # Backup existing applicationHost.config
        copy C:\Windows\System32\inetsrv\config\applicationHost.config C:\Windows\System32\inetsrv\config\applicationHost_BeforeInstallingANCM.config

        Import-Module IISAdministration

        # Initialize variables
        $aspNetCoreHandlerFilePath="C:\windows\system32\inetsrv\aspnetcore.dll"
        Reset-IISServerManager -confirm:$false
        $sm = Get-IISServerManager

        # Add AppSettings section
        $sm.GetApplicationHostConfiguration().RootSectionGroup.Sections.Add("appSettings")

        # Set Allow for handlers section
        $appHostconfig = $sm.GetApplicationHostConfiguration()
        $section = $appHostconfig.GetSection("system.webServer/handlers")
        $section.OverrideMode="Allow"

        # Add aspNetCore section to system.webServer
        $sectionaspNetCore = $appHostConfig.RootSectionGroup.SectionGroups["system.webServer"].Sections.Add("aspNetCore")
        $sectionaspNetCore.OverrideModeDefault = "Allow"
        $sm.CommitChanges()

        # Configure globalModule
        Reset-IISServerManager -confirm:$false
        $globalModules = Get-IISConfigSection "system.webServer/globalModules" | Get-IISConfigCollection
        New-IISConfigCollectionElement $globalModules -ConfigAttribute @{"name"="AspNetCoreModule";"image"=$aspNetCoreHandlerFilePath}

        # Configure module
        $modules = Get-IISConfigSection "system.webServer/modules" | Get-IISConfigCollection
        New-IISConfigCollectionElement $modules -ConfigAttribute @{"name"="AspNetCoreModule"}

        # Backup existing applicationHost.config
        copy C:\Windows\System32\inetsrv\config\applicationHost.config C:\Windows\System32\inetsrv\config\applicationHost_AfterInstallingANCM.config

        If ($?)
        {
            $IISUpdateResult = "Successfully updated IIS Configuration on $NanoServerName"
        }

        If (!$?)
        {
            $IISUpdateResult = "Failed to update IIS Configuration on $NanoServerName"
        }        
    }

    # Adding Results of Configuration to a new PSCustomObject that will be outputted in the $Results Variable.
    New-Object PSObject `
       -Property @{
        FileCheckResult                 = $FileCheckResult
        IISUpdateResult                 = $IISUpdateResult
        }
    } -ArgumentList $NanoServerName

# Removing the PowerShell Session.
Remove-PSSession -Session $Session

# Returned Results.
$Results.FileCheckResult
$Results.IISUpdateResult

