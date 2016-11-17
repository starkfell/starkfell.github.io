<#

.SYNOPSIS
This script downloads and installs .NET Core 1.0.1 to 'C:\dotnet' on a target Nano Server.

.DESCRIPTION
This script downloads and installs .NET Core 1.0.1 to 'C:\dotnet' on a target Nano Server.

Once this script is launched, the following actions will occur:

- A new PowerShell Session will be created targeting the Nano Server.
    - Prompt will appear to login to the targeted Nano Server using the 'Username' Parameter.
- Check to see if .NET Core 1.0.1 is already installed. If it is found, script will exit.
- .NET Core 1.0.1 will be downloaded from https://go.microsoft.com/fwlink/?LinkID=827537 to C:\Windows\Temp.
- .NET Core 1.0.1 will be extracted to C:\dotnet.
- The PowerShell Session will be removed and Results of the process returned to STDOUT.

.PARAMETER NanoServerName
The IP Address or the FQDN of the Nano Server.

.PARAMETER Username
This is either the Administrative Account of the Nano Server or a Domain Account with rights to login to the Nano Server.

.PARAMETER DomainName
The Domain Name of the Domain Account with rights to login to the Nano Server. i.e. - CONTOSO.

.NOTES
Filename:   install-dotnet-core-1.0.1-on-nano-server.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

The main portion of the .NET Core Installation in this Script is a modified version from the following Microsoft Documentation article:

https://docs.microsoft.com/en-us/aspnet/core/tutorials/nano-server

.EXAMPLE
Installing .NET Core 1.0.1 to an existing Nano Server joined to a Domain.

./install-dotnet-core-1.0.1-on-nano-server.ps1 `
-NanoServerName nanosrv-vm-5 `
-Username serveradmin `
-DomainName lumagate.com

Installing .NET Core 1.0.1 to an existing stand-alone Nano Server.

./install-dotnet-core-1.0.1-on-nano-server.ps1 `
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

    # Determining if .NET Core 1.0.1 is installed on the Nano Server.
    Get-Item -Path "C:\dotnet\shared\Microsoft.NETCore.App\1.0.1" -ErrorAction SilentlyContinue -ErrorVariable CoreCheck

    If (!$CoreCheck)
    {
        $CoreCheckResult = ".NET Core 1.0.1 is already installed on $NanoServerName."
    }

    If ($CoreCheck)
    {
        $CoreCheckResult = ".NET Core 1.0.1 was not found on $NanoServerName."

        $SourcePath = "https://go.microsoft.com/fwlink/?LinkID=827537"
        $DestinationPath = "C:\dotnet"

        $EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId

        if (($EditionId -eq "ServerStandardNano") -or
            ($EditionId -eq "ServerDataCenterNano") -or
            ($EditionId -eq "NanoServer") -or
            ($EditionId -eq "ServerTuva")) 
            {
                $TempPath = [System.IO.Path]::GetTempFileName()
                if (($SourcePath -as [System.URI]).AbsoluteURI -ne $null)
                {
                    $handler = New-Object System.Net.Http.HttpClientHandler
                    $client = New-Object System.Net.Http.HttpClient($handler)
                    $client.Timeout = New-Object System.TimeSpan(0, 30, 0)
                    $cancelTokenSource = [System.Threading.CancellationTokenSource]::new()
                    $responseMsg = $client.GetAsync([System.Uri]::new($SourcePath), $cancelTokenSource.Token)
                    $responseMsg.Wait()
                    if (!$responseMsg.IsCanceled)
                    {
                        $response = $responseMsg.Result
                        if ($response.IsSuccessStatusCode)
                        {
                            $downloadedFileStream = [System.IO.FileStream]::new($TempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
                            $copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream)
                            $copyStreamOp.Wait()
                            $downloadedFileStream.Close()
                            if ($copyStreamOp.Exception -ne $null)
                            {
                                $DownloadErrorMessage = $copyStreamOp.Exception
                            }
                        }
                    }
                }
                else
                {
                    $CopyErrorMessage = "Cannot copy from $SourcePath."
                }

                [System.IO.Compression.ZipFile]::ExtractToDirectory($TempPath, $DestinationPath)
                
                if ($?)
                {
                    $ExtractionResult = "Successfully extracted .NET Core 1.0.1 to 'C:\dotnet'"
                    Remove-Item $TempPath
                }

                if (!$?)
                {
                    $ExtractionResult = $copyStreamOp.Exception
                    Remove-Item $TempPath
                }
            }
        }

        # Adding Results of Configuration to a new PSCustomObject that will be outputted in the $Results Variable.
        New-Object PSObject `
        -Property @{
            CoreCheckResult                 = $CoreCheckResult
            DownloadErrorMessage            = $DownloadErrorMessage
            CopyErrorMessage                = $CopyErrorMessage
            ExtractionResult                = $ExtractionResult          
        }
    } -ArgumentList $NanoServerName

# Removing the PowerShell Session.
Remove-PSSession -Session $Session

# Returned Results.
$Results.CoreCheckResult
$Results.DownloadErrorMessage
$Results.CopyErrorMessage
$Results.ExtractionResult

