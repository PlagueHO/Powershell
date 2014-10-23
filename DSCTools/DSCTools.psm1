Function Invoke-DSCPull {
<#
.SYNOPSIS
Forces an LCM to repull DSC configuration data from the pull server.

.DESCRIPTION 
This function will cause the Local Configuration Manager on the computers listed in the ComputerName parameter to repull the DSC configuration MOF file from the pull server.

The computers listed must already have the LCM correctly configured for pull mode.
     
.PARAMETER ComputerName
This must contain a list of computers that will have the LCM repull triggered on.

.EXAMPLE 
 Invoke-DSCPull -ComputerName CLIENT01,CLIENT02,CLIENT03
 Causes the LCMs on computers CLIENT01, CLIENT02 and CLIENT03 to repull DSC Configuration MOF files from the DSC Pull server.
#>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
            )]
        [String[]]$ComputerName
    ) # Param

    Begin {}
    Process {
        Foreach ($Computer In $ComputerName) {
            # For some reason using the Invoke-CimMethod cmdlet with the -ComputerName parameter doesn't work
            # So the Invoke-Command 
            Invoke-Command -ComputerName $Computer { `
                Invoke-CimMethod `
                    -Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
                    -ClassName 'MSFT_DSCLocalConfigurationManager' `
                    -MethodName 'PerformRequiredConfigurationChecks' `
                    -Arguments @{ Flags = [uint32]1 }
                }
        }
    } # Process
    End {}
} # Function Invoke-DSCPull

Function Start-DSCPullMode {
<#
.SYNOPSIS
Configures a Node for Pull Mode.

.DESCRIPTION 
This function will create all configuration files required for a node to be placed into DSC Pull mode.

It will take an array of nodes in the nodes parameter which will list all nodes that should be configured for pull mode.

The function will:
1. Create the node DSC configuration MOF file if it is missing (and the configration file is noted in the Nodes array).
2. Copy the node DSC configuration MOF file and rename with GUID provided in the nodes array or to a new GUID if one is not provided in the nodes array.
3. Create a node DSC configuration MOF checksum file.
4. Move the node DSC configration MOF and checksum file to the Pull server.
5. Create the node LCM configuration MOF file to configure the LCM for pull mode.
6. Execute the node LCM configuration MOF on the node. 
     
.PARAMETER PullServerURL
-

.PARAMETER PullServerProtocol
-

.PARAMETER PullServerName
-

.PARAMETER PullServerPort
-

.PARAMETER PullServerPath
-

.PARAMETER DestConfigPath
-

.PARAMETER Nodes
-

.EXAMPLE 
 Start-DSCPullMode
 -
#>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory=$true,
            ParameterSetName='ServerURL'
            )]
        [string]$PullServerURL,

        [Parameter(
            ParameterSetName='ServerHTTP'
            )]
        [string]$PullServerProtocol='http',

        [Parameter(
            Mandatory=$true,
            ParameterSetName='ServerHTTP'
            )]
        [string]$PullServerName,

        [Parameter(
            ParameterSetName='ServerHTTP'
            )]
        [int]$PullServerPort=8080,

        [Parameter(
            ParameterSetName='ServerHTTP'
            )]
        [string]$PullServerPath='PSDSCPullServer.svc',

        [Parameter(Mandatory=$true)]
        [string]$DestConfigPath,

        [Parameter(Mandatory=$true)]
        [Array]$Nodes
    )
    
    If ($PullServerURL -eq '') {
        $PullServerURL = "$($PullServerProtocol)://$($PullServerName):$PullServerPort/$PullServerPath"
    }

    # Set up a temporary path
    $TempPath = "$Env:TEMP\Start-DSCPullMode\"
    New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

    Foreach ($Node In $Nodes) {
        # Get the Node parameters into variables and check them
        $NodeName = $Node.Name
        If ($NodeName -eq '') {
            Throw 'Node name is empty.'
        }
        $NodeGuid = $Node.Guid
        If ($NodeGuid -eq '') {
            $NodeGuid = [guid]::NewGuid()
        }
        $RebootNodeIfNeeded = $Node.RebootNodeIfNeeded
        $ConfigurationMode = $Node.ConfigurationMode

        # If the node doesn't have a specific MOF path specified then see if we can figure it out
        # Based on other parameters specified - or even create it.
        $MofPath = $Node.MofPath

        # Create and/or Move the Node Configuration file to the Pull server
        $source = "$MachineConfigPath\$ClientComputerName.mof"
        $dest = "\\$PullServerName\c`$\program files\windowspowershell\dscservice\configuration\$guid.mof"
        copy $source $dest
        New-DSCChecksum -ConfigurationPath $dest -Force

        # Create the LCM MOF File to set the nodes LCM to pull mode
        ConfigureLCMPullMode `
            -NodeName $NodeName `
            -NodeGuid $NodeGuid `
            -RebootNodeIfNeeded $RebootNodeIfNeeded `
            -ConfigurationMode $ConfigurationMode `
            -PullServerURL $PullServerURL `
            -Path $TempPath
        
        # Apply the LCM MOF File to the node
        Set-DSCLocalConfigurationManager -Computer $NodeName -Path "$env:TEMP\"

        # Reove the LCM MOF File
        Remove-Item -Path "$TempPath\$NodeName.MOF"
    } # Foreach

    Remove-Item -Path $TempPath -Recurse -Force
} # Start-DSCPullMode

Configuration ConfigureLCMPullMode {
    Param (
        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeName,

        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeGuid,

        [string]$ConfigurationMode = 'ApplyAndAutoCorrect',

        [boolean]$RebootNodeIfNeeded = $false,

        [Parameter(
            Mandatory=$true
            )]
        [string]$PullServerURL
    ) # Param

    If ($ConfigurationMode -notin ('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')) {
        Throw 'ConfigurationMode is invalid.'
    }

    If ($PullServerURL -match '^https?://') {
		$DownloadManagerName = 'WebDownloadManager'
		If ($PullServerURL.ToLower().StartsWith('https')) {
            $DownloadManagerCustomData = @{
			    ServerUrl = $PullServerURL;
			    AllowUnsecureConnection = 'true'
                }
        } Else {
            $DownloadManagerCustomData = @{
			    ServerUrl = $PullServerURL;
			    AllowUnsecureConnection = 'false'
                }
        } # If
    } Else {
        $DownloadManagerName = 'DscFileDownloadManager'
        $DownloadManagerCustomData = @{
	        SourcePath = $PullServerURL
            }
    } # If

	Node $NodeName {
		LocalConfigurationManager {
			ConfigurationMode = 'ApplyAndAutoCorrect'
			ConfigurationID = $NodeGuid
			RefreshMode = 'Pull'
            RebootNodeIfNeeded = $RebootNodeIfNeeded
			DownloadManagerName = $DownloadManagerName
			DownloadManagerCustomData = $DownloadManagerCustomData
		} # LocalConfigurationManager
	} # Node $NodeName
} # Configuration ConfigureLCMPullMode
