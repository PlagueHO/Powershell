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

Function Publish-DSCPullResources {
<#
.SYNOPSIS
Publishes DSC Resources to a DSC pull server.

.DESCRIPTION 
This function takes a path where all the source DSC resources are contained in subfolders.

These resources will then be zipped up and renamed based on the manifest version found in the resource.

A checksum file will also be created for each resource zip.

The resource zip and checksum will then be moved into the folder provided in the PullServerPath paramater.

This function requires the PSCX module to be available and installed on this computer.

PSCX Module can be downloaded from http://pscx.codeplex.com/
     
.PARAMETER SourcePath
This is the path containing the folders containing all the DSC resources.

.PARAMETER PullServerPath
This must contain a list of computers that will have the LCM repull triggered on.

.EXAMPLE 
 Publish-DSCPullResources -SourcePath 'c:\program files\windowspowershell\modules\a*' -PullServerPath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
 This will cause all resources found in the c:\program files\windowspowershell\modules\ folder starting with the letter A to be zipped up and copied into the \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules folder.
 A checksum file will also be created for each zipped resource.

.EXAMPLE 
 'c:\program files\windowspowershell\modules\','c:\powershell\modules\' | Publish-DSCPullResources -PullServerPath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
 This will cause all resources found in either the c:\program files\windowspowershell\modules\ folder or c:\powershell\modules\ folder to be zipped up and copied into the \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules folder.
 A checksum file will also be created for each zipped resource.

 .LINK
 http://pscx.codeplex.com/
#>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true
            )]
        [Alias('FullName')]
        [String[]]$SourcePath,

        [Parameter(
            Mandatory=$true
            )]
        [String]$PullServerPath
    ) # Param

    Begin {
        If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
            Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
        }
        Import-Module PSCX

        If ((Test-Path -Path $PullServerPath -PathType Container) -eq $false) {
            Throw "$PullServerPath could not be found."
        }
    }

    Process {
        Foreach ($Path in $SourcePath) {
            Write-Verbose "Examining $Path for Resource Folders"
            If ((Test-Path -Path $Path -PathType Container) -eq $true) {
                Write-Verbose "Folder $Path Found"        
                # This path in the source path array is a folder
                $Resources = Get-ChildItem -Path $Path -Attributes Directory
                Foreach ($Resource in $Resources) {
                    Write-Verbose "Folder $Resource Found"
                    # A folder was found inside the source path - does it contain a resource?
                    $ResourcePath = Join-Path -Path $Path -ChildPath $Resource
                    $Manifest = Join-Path -Path $ResourcePath -ChildPath "$Resource.psd1"
                    $DSCResourcesFolder = Join-Path -Path $ResourcePath -ChildPath DSCResources
                    If ((Test-Path -Path $Manifest -PathType Leaf) -and (Test-Path -Path $DSCResourcesFolder -PathType Container)) {
                        Write-Verbose "Resource $Resource in $ResourcePath Found"
                        # This folder appears to contain a valid DSC Resource
                        # Get the version number out of the manifest file
                        $ManifestContent = Invoke-Expression -Command (Get-Content -Path $Manifest -Raw)
                        $ModuleVersion = $ManifestContent.ModuleVersion
                        Write-Verbose "Resource $Resource is version $ModuleVersion"
                        # Generate the Zip file name (including the destination to the pull server folder)
                        $ZipFileName = Join-Path -Path $PullServerPath -ChildPath "$($Resource)_$($ModuleVersion).zip"
                        Write-Verbose "Zipping $ResourcePath to $ZipFileName" 
                        # Zip up the resource straight into the pull server resources path
                        Get-ChildItem -Path $ResourcePath -Recurse | Write-Zip -IncludeEmptyDirectories -OutputPath $ZipFileName -EntryPathRoot $ResourcePath -Level 9
                        # Generate the checksum for the zip file
                        New-DSCCheckSum -ConfigurationPath $ZipFileName -Force | Out-Null
                        Write-Verbose "Checksum for $ZipFileName created"
                    } # If
                } # Foreach ($Resource in $Resources)
            } Else {
                Write-Verbose "File $Path Is Ignored"
            }# If
        } # Foreach ($Path in $SourcePath)
    } # Process
    End {}
} # Function Publish-DSCPullResources

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
