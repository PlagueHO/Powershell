<#
    .NOTES
		This script was based on the Install-ContainerHost.ps1 script from Microsoft.

		It has been modified by Daniel Scott-Raynsford to install on a Windows Nano Server TP3
		System with the following packages installed:
		Guest
		OEM-Drivers
		Containers
		Compute

		The following things had to be changed:
		1. All instances where a file is downloaded from the internet were removed because WGET
			(Invoke-WebRequest) isn't available.
		
		Known Issues:
		1. Creating either a DHCP or NAT switch throws errors, but the NAT switch appears to 
		   partially create (atthough the NAT binding fails).
		2. The Docker NSSM Service doesn't get created (possibly because of the switch failure).
    
    .SYNOPSIS
        Installs the prerequisites for creating Windows containers on Windows Nano Server TP3

    .DESCRIPTION
        Installs the prerequisites for creating Windows containers on Windows Nano Server TP3
                        
    .PARAMETER ExternalNetAdapter
        Specify a specific network adapter to bind to a DHCP switch
            
    .PARAMETER NoRestart
        If a restart is required the script will terminate and will not reboot the machine

    .PARAMETER SkipDocker
        If passed, skip Docker install

    .PARAMETER $UseDHCP
        If passed, use DHCP configuration
		            
    .PARAMETER WimPath
        Path to .wim file that contains the base package image

    .EXAMPLE
        .\Install-ContainerHostNano.ps1 -SkipDocker
                
#>
#Requires -Version 5.0

[CmdletBinding(DefaultParameterSetName="IncludeDocker")]
param(
  
    [string]
    $ExternalNetAdapter,

    [string]
    $NATSubnetPrefix = "172.16.0.0/12",
         
    [switch]
    $NoRestart,

    [Parameter(ParameterSetName="SkipDocker", Mandatory=$true)]
    [switch]
    $SkipDocker,

    [Parameter(ParameterSetName="Staging", Mandatory=$true)]
    [switch]
    $Staging,

    [switch]
    $UseDHCP,

    [string]
    [ValidateNotNullOrEmpty()]
    $WimPath = "NanoServer.wim"
)

$global:RebootRequired = $false

$global:ErrorFile = "$pwd\Install-ContainerHost.err"

$global:RegRunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$global:RegDockerKey = "DockerService"

$global:RegRunOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$global:RegPowershellValue = (Join-Path $env:windir "system32\WindowsPowerShell\v1.0\powershell.exe")
$global:RegBootstrapFile = "$pwd\Install-ContainerHost-Bootstrap.ps1"

$global:SwitchName = "Virtual Switch"

function
New-ContainerDhcpSwitch
{
    if ($ExternalNetAdapter)
    {
        $netAdapter = (Get-NetAdapter |? {$_.Name -eq "$ExternalNetAdapter"})[0]
    }
    else
    {
        $netAdapter = (Get-NetAdapter |? {($_.Status -eq 'Up') -and ($_.ConnectorPresent)})[0]
    }

    Write-Output "Creating container switch (DHCP)..."
    # This fails on Nano:
	# New-VmSwitch $global:SwitchName -NetAdapterName $netAdapter.Name | Out-Null
}

function
New-ContainerNatSwitch
{
    [CmdletBinding()]
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $SubnetPrefix
    )

    Write-Output "Creating container switch (NAT)..."
    New-VmSwitch $global:SwitchName -SwitchType NAT -NatSubnetAddress $SubnetPrefix | Out-Null
}


function
New-ContainerNat
{
    [CmdletBinding()]
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $SubnetPrefix
    )

    Write-Output "Creating NAT for $SubnetPrefix..."
	# This fails on Nano because the module doesn't exist.
    # New-NetNat -Name ContainerNAT -InternalIPInterfaceAddressPrefix $SubnetPrefix | Out-Null
}

function
Install-ContainerHost
{
    "If this file exists when Install-ContainerHost.ps1 exits, the script failed!" | Out-File -FilePath $global:ErrorFile

    #
    # Configure networking
    #
    if ($($PSCmdlet.ParameterSetName) -ne "Staging")
    {
        $switchCollection = Get-VmSwitch

        if ($switchCollection.Count -eq 0)
        {
           Write-Output "Enabling container networking..."
            
            if ($UseDHCP)
            {
                New-ContainerDhcpSwitch
            }
            else
            {   
                New-ContainerNatSwitch $NATSubnetPrefix

                New-ContainerNat $NATSubnetPrefix
            }    
		}
        else
        {
            Write-Output "Networking is already configured.  Confirming configuration..."

            $dhcpSwitchCollection = $switchCollection |? { $_.SwitchType -eq "External" }

            if ($dhcpSwitchCollection -eq $null)
            {
                Write-Output "We didn't find a configured external switch; configuring now..."
                New-ContainerDhcpSwitch
            }
            else
            {
                if ($($dhcpSwitchCollection |? { $_.SwitchName -eq $global:SwitchName }) -eq $null)
                {
                    throw "One or more external switches are configured, but none match the expected switch name ($global:SwitchName)"
                }
            }
        }
    }

    #
    # Install the base package
    #
    $imageCollection = Get-ContainerImage

    if ($imageCollection -eq $null)
    {
        Write-Output "Installing Container OS image from $WimPath (this may take a few minutes)..."

        if (Test-Path $WimPath)
        {
            #
            # .wim is present and local
            #            
        }
        else
        {
            throw "Path to existing local Wim File must be provided."
        }

        Install-ContainerOsImage -WimPath $WimPath -Force
        
        while ($imageCollection -eq $null)
        {
            #
            # Sleeping to ensure VMMS has restarted to workaround TP3 issue
            #
            Write-Output "Waiting for VMMS to return image at ($(get-date))..."

            Start-Sleep -Sec 2
                
            $imageCollection = Get-ContainerImage
        }

        Write-Output "Container base image install complete.  Querying container images..."            
    }

    $baseImage = $imageCollection |? IsOSImage
    
    if ($baseImage -eq $null)
    {
        throw "No Container OS image installed!"
    }

    Write-Output "The following images are present on this machine:"
    foreach ($image in $imageCollection)
    {
        Write-Output "    $($image).Name"
    }
    Write-Output ""
    
    #
    # Install, register, and start Docker
    #
    if ($($PSCmdlet.ParameterSetName) -eq "IncludeDocker")
    {    
        if (Test-Path "$env:windir\System32\docker.exe")
        {
            Write-Output "Docker is already installed."
        }
        else
		{
            throw "$env:windir\System32\docker.exe was not found."
        }

        $serviceName = "Docker"
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($service -ne $null)
        {
            Write-Output "Docker service is already installed."
        }
        else
        {
            Test-Admin
            
            if (Test-Path "$($env:SystemRoot)\System32\nssm.exe")
            {
                Write-Output "NSSM is already installed"
            }
            else
            {
                Throw "NSSM.exe was not found in $($env:SystemRoot)\System32\"
            }

            $dockerData = "$($env:ProgramData)\docker"
            $dockerLog = "$dockerData\daemon.log"

            if (-not (Test-Path $dockerData))
            {
                Write-Output "Creating Docker program data..."
                New-Item -ItemType Directory -Force -Path $dockerData | Out-Null
            }

            $dockerDaemonScript = "$dockerData\runDockerDaemon.cmd"

            $runDockerDaemon | Out-File -FilePath $dockerDaemonScript -Encoding ASCII
                        
            Write-Output "Configuring NSSM for $serviceName service..."
            Start-Process -Wait "nssm" -ArgumentList "install $serviceName $($env:SystemRoot)\System32\cmd.exe /s /c $dockerDaemonScript"
            Start-Process -Wait "nssm" -ArgumentList "set $serviceName DisplayName Docker Daemon"
            Start-Process -Wait "nssm" -ArgumentList "set $serviceName Description The Docker Daemon provides management capabilities of containers for docker clients"
            # Pipe output to daemon.log
            Start-Process -Wait "nssm" -ArgumentList "set $serviceName AppStderr $dockerLog"
            Start-Process -Wait "nssm" -ArgumentList "set $serviceName AppStdout $dockerLog"
            # Allow 15 seconds for graceful shutdown before process is terminated
            Start-Process -Wait "nssm" -ArgumentList "set $serviceName AppStopMethodConsole 15000"
            
            #Should the script prompt for creds for the service in some way?
            Start-Service -Name $serviceName
            
            #
            # Waiting for docker to come to steady state
            #
            Write-Output "Waiting for Docker daemon..."
            $dockerReady = $false
            $startTime = Get-Date

            while (-not $dockerReady)
            {
                try
                {
                    Invoke-RestMethod -Uri http://127.0.0.1:2375/info -Method GET | Out-Null
                    $dockerReady = $true
                }
                catch 
                {
                    $timeElapsed = $(Get-Date) - $startTime

                    if ($($timeElapsed).TotalMinutes -ge 1)
                    {
                        throw "Docker Daemon did not start successfully within 1 minute."
                    } 

                    # Swallow error and try again
                    Start-Sleep -sec 1
                }
            }
            Write-Output "Successfully connected to Docker Daemon."

            #
            # Register the base image with Docker
            #
            Write-Output "Tagging new base image..."
            docker tag (docker images -q) "$($baseImage.Name.tolower()):latest"
        }
    }
    
    Remove-Item $global:ErrorFile
    Write-Output "Script complete!"
} $global:AdminPriviledges = $false


function 
Test-Admin()
{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole))
    {
        $global:AdminPriviledges = $true
        return
    }
    else
    {
        #
        # We are not running "as Administrator"
        # Exit from the current, unelevated, process
        #
        throw "You must run this script as administrator"   
    }
}
$runDockerDaemon = @"

@echo off
set certs=%ProgramData%\docker\certs.d

if exist %ProgramData%\docker (goto :run)
mkdir %ProgramData%\docker

:run
if exist %certs%\server-cert.pem (goto :secure)
 
docker daemon -D -b "$global:SwitchName"
goto :eof
 
:secure
docker daemon -D -b "$global:SwitchName" -H 0.0.0.0:2376 --tlsverify --tlscacert=%certs%\ca.pem --tlscert=%certs%\server-cert.pem --tlskey=%certs%\server-key.pem

"@
try
{
    Install-ContainerHost
}
catch 
{
    Write-Error $_
}
