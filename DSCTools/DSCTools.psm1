#Requires -Version 4.0

##########################################################################################################################################
# Default Configuration Variables
##########################################################################################################################################
# This is the name of the pull server that will be used if no pull server parameter is passed to functions
# Setting this value is a lazy way of using a different pull server (rather than passing the pullserver parameter)
# to each function that needs it.
$DSCTools_PullServerName = 'Localhost'

$DSCTools_PullServerProtocol = 'HTTP'

$DSCTools_PullServerPort = 8080

$DSCTools_PullServerPath = 'PSDSCPullServer.svc'

$DSCTools_DefaultModuleFolder = 'c:\program files\windowspowershell\modules\'

$DSCTools_DefaultResourceFolder = 'c$\Program Files\WindowsPowerShell\DscService\Modules'

$DSCTools_DefaultConfigFolder = 'c$\program files\windowspowershell\DscService\configuration'

$DSCTools_DefaultNodeConfigSourceFolder = "$HOME\Documents\windowspowershell\configuration"

$DSCTools_PSVersion = 4.0


##########################################################################################################################################
# Main CmdLets
##########################################################################################################################################
Function Invoke-DSCPull {
<#
.SYNOPSIS
Forces the LCM on destination computer(s) to repull DSC configuration data from a pull server.

.DESCRIPTION 
This function will cause the Local Configuration Manager on the computers listed in the ComputerName parameter to repull the DSC configuration MOF file from the pull server.

The computers listed must already have the LCM correctly configured for pull mode.

The command is executed via a call to Invoke-Command on the destination computer's LCM which will be called via WinRM.
Therefore WinRM must be enabled on the destination computer's LCM and the appropriate firewall ports opened.
     
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
            # So the Invoke-Command is used instead to execute the command on the destination computer.
            Invoke-Command -ComputerName $Computer { `
                Invoke-CimMethod `
                    -Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
                    -ClassName 'MSFT_DSCLocalConfigurationManager' `
                    -MethodName 'PerformRequiredConfigurationChecks' `
                    -Arguments @{ Flags = [uint32]1 }
                } # Invoke-Command
        } # Foreach ($Computer In $ComputerName)
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

The resource zip and checksum will then be moved into the folder provided in the PullServerResourcePath paramater.

This function requires the PSCX module to be available and installed on this computer.

PSCX Module can be downloaded from http://pscx.codeplex.com/
     
.PARAMETER SourcePath
This is the path containing the folders containing all the DSC resources. If this is not passed the default path of "c:\program files\windowspowershell\modules\" will be used.

.PARAMETER PullServerResourcePath
This is the destination path to which the zipped resources and checksum files will be written to. The user running this command must have write access to this folder.

If this parameter is not set the path will be set to:
\\$DSCTools_PullServer\c$\Program Files\WindowsPowerShell\DscService\Modules

.EXAMPLE 
 Publish-DSCPullResources -SourcePath 'c:\program files\windowspowershell\modules\a*' -PullServerResourcePath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
 This will cause all resources found in the c:\program files\windowspowershell\modules\ folder starting with the letter A to be zipped up and copied into the \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules folder.
 A checksum file will also be created for each zipped resource.

.EXAMPLE 
 Publish-DSCPullResources -SourcePath 'c:\program files\windowspowershell\modules\*'
 This will cause all resources found in the c:\program files\windowspowershell\modules\ folder to be zipped up and copied into the $DSCTools_DefaultResourceFolder folder on the machine set in the $DSCTools_PullServerName
 variable. A checksum file will also be created for each zipped resource.

.EXAMPLE 
 'c:\program files\windowspowershell\modules\','c:\powershell\modules\' | Publish-DSCPullResources -PullServerResourcePath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
 This will cause all resources found in either the c:\program files\windowspowershell\modules\ folder or c:\powershell\modules\ folder to be zipped up and copied into the \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules folder.
 A checksum file will also be created for each zipped resource.

 .LINK
 http://pscx.codeplex.com/
#>
    [CmdletBinding()]
    Param (
        [Parameter(
            ValueFromPipeline=$true
            )]
        [Alias('FullName')]
        [String[]]$SourcePath=$DSCTools_DefaultModuleFolder,

        [String]$PullServerResourcePath="\\$DSCTools_PullServerName\$DSCTools_DefaultResourceFolder"
    ) # Param

    Begin {
        If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
            Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
        }
        Import-Module PSCX

        If ((Test-Path -Path $PullServerResourcePath -PathType Container) -eq $false) {
            Throw "$PullServerResourcePath could not be found."
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
                        $ZipFileName = Join-Path -Path $PullServerResourcePath -ChildPath "$($Resource)_$($ModuleVersion).zip"
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
This is the URL that will be used by the Local Configuration Manager of the Node to pull the configuration files.

If this parameter is not passed it is generated from the Module Variables:

$($DSCTools_PullServerProtocol)://$($DSCTools_PullServerName):$($DSCTools_PullServerPort)/$($DSCTools_PullServerPath)

For example:

http://MyPullServer:8080/PSDSCPullServer.svc

.PARAMETER PullServerConfigPath
This optional parameter contains the full path to where the Pull Server DSC Node configuration files should be written to.

If this parameter is not passed it is generated from the module variables:

\\$DSCTools_PullServerName\$DSCTools_DefaultConfigFolder

For example:

\\MyPullServer\program files\windowspowershell\DscService\configuration

.PARAMETER NodeConfigSourceFolder

This parameter is used to specify the folder where the node configration files can be found. If it is not passed it will default to the
module variable $DSCTools_DefaultNodeConfigSourceFolder.

This value will be ignored for any node that has a MOFFile key value set.

.PARAMETER Nodes
Must contain an array of hash tables. Each hash table will represent a node that should be configured full DSC pull mode.

The hash table must contain the following entries:
Name = 

Each hash entry can also contain the following optional items. If each item is not specified it will default.
Guid = If no guid is passed for this node a new one will be created
RebootNodeIfNeeded = $false
ConfigurationMode = 'ApplyAndAutoCorrect'
MofFile = This is the path and filename of the MOF file to use for this node. If not provided the MOF file will be used

For example:
@(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';Guid='';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})

.EXAMPLE 
 Start-DSCPullMode `
    -Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})
 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server specified by a
 combination of the module variables \\$DSCTools_PullServerName\$DSCTools_DefaultConfigFolder.

.EXAMPLE 
 Start-DSCPullMode `
    -Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'}) `
    -PullServerConfigPath '\\MyPullServer\DSCConfiguration'
 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server configration folder '\\MyPullServer\DSCConfiguration'
#>
    [CmdletBinding()]
    Param (
        [string]$PullServerURL="$($DSCTools_PullServerProtocol)://$($DSCTools_PullServerName):$($DSCTools_PullServerPort)/$($DSCTools_PullServerPath)",

        [String]$PullServerConfigPath="\\$DSCTools_PullServerName\$DSCTools_DefaultConfigFolder",

        [String]$NodeConfigSourceFolder=$DSCTools_DefaultNodeConfigSourceFolder,

        [Parameter(Mandatory=$true)]
        [Array]$Nodes
    )
    
    # Set up a temporary path
    $TempPath = "$Env:TEMP\Start-DSCPullMode"
    Write-Verbose "Creating temporary folder $TempPath"
    New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

    Foreach ($Node In $Nodes) {
        # Clear the node error flag
        $NodeError = $false
        
        # Get the Node parameters into variables and check them
        $NodeName = $Node.Name
        If ($NodeName -eq '') {
            Throw 'Node name is empty.'
        }

        Write-Verbose "Node $NodeName begin processing"
        $NodeGuid = $Node.Guid
        If ($NodeGuid -eq '') {
            $NodeGuid = [guid]::NewGuid()
        }
        Write-Verbose "Node $NodeName will use GUID $NodeGuid"
        $RebootNodeIfNeeded = $Node.RebootNodeIfNeeded
        If ($RebootNodeIfNeeded -eq $null) {
            $RebootNodeIfNeeded = $false
        }
        $ConfigurationMode = $Node.ConfigurationMode
        If ($ConfigurationMode -eq $null) {
            $ConfigurationMode = 'ApplyAndAutoCorrect'
        }

        # If the node doesn't have a specific MOF path specified then see if we can figure it out
        # Based on other parameters specified - or even create it.
        $MofFile = $Node.MofFile
        If ($MofFile -eq $null) {
            $SourceMof = "$NodeConfigSourceFolder\$NodeName.mof"
        } Else {
            $SourceMof = $MofFile
        }
        Write-Verbose "Node $NodeName will use configuration MOF $SourceMof"

        # If the MOF doesn't throw an error?
        If (-not (Test-Path -PathType Leaf -Path $SourceMof)) {
            #TODO: Can we try to create the MOF file from the configuration?
            Write-Error "The node configuration MOF file $SourceMof could not be found for node $NodeName"
            $NodeError = $true
        }

        If (-not $NodeError) {
            # Create and/or Move the Node Configuration file to the Pull server
            $DestMof = "$PullServerConfigPath\$NodeGuid.mof"
            Copy-Item -Path $SourceMof -Destination $DestMof -Force
            Write-Verbose "Node $NodeName configuration MOF $SourceMof copied to $DestMof"
            New-DSCChecksum -ConfigurationPath $DestMof -Force
            Write-Verbose "Node $NodeName configuration MOF checksum created $DestMof"

            # Create the LCM MOF File to set the nodes LCM to pull mode
            ConfigureLCMPullMode `
                -NodeName $NodeName `
                -NodeGuid $NodeGuid `
                -RebootNodeIfNeeded $RebootNodeIfNeeded `
                -ConfigurationMode $ConfigurationMode `
                -PullServerURL $PullServerURL `
                -Output $TempPath `
                | Out-Null

            Write-Verbose "Node $NodeName LCM MOF $TempPath\$NodeName.MOF created"
        
            # Apply the LCM MOF File to the node
            Set-DSCLocalConfigurationManager -Computer $NodeName -Path $TempPath

            Write-Verbose "Node $NodeName set to use LCM MOF $TempPath"

            # Reove the LCM MOF File
            Remove-Item -Path "$TempPath\$NodeName.meta.MOF"
            Write-Verbose "Node $NodeName LCM MOF $TempPath\$NodeName.meta.MOF removed"
        } # If

    Write-Verbose "Node $NodeName processing complete"
    } # Foreach

    Remove-Item -Path $TempPath -Recurse -Force
    Write-Verbose "Temporary folder $TempPath deleted"
} # Start-DSCPullMode



##########################################################################################################################################
# Configurations
##########################################################################################################################################
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
			    AllowUnsecureConnection = 'false'
                }
        } Else {
            $DownloadManagerCustomData = @{
			    ServerUrl = $PullServerURL;
			    AllowUnsecureConnection = 'true'
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



##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-Start-DSCPullMode {
    $DSCTools_PullServerName = 'PLAGUE-PDC'
    Start-DSCPullMode -Nodes @(@{Name='PLAGUE-MEMBER';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootNodeIfNeeded=$true;MofFile='C:\Users\Daniel.PLAGUEHO\OneDrive\PS\DSC\PLAGUEConfiguration\PLAGUE-MEMBER.MOF'}) -Verbose
} # Test-Start-DSCPullMode



##########################################################################################################################################
# Exports
##########################################################################################################################################
Export-ModuleMember `
    -Function Invoke-DSCPull,Publish-DSCPullResources,Start-DSCPullMode `
    -Variable DSCTools_PullServerName,DSCTools_PullServerProtocol,DSCTools_PullServerPort,DSCTools_PullServerPath,DSCTools_DefaultModuleFolder,DSCTools_DefaultResourceFolder,DSCTools_DefaultConfigFolder,DSCTools_DefaultNodeConfigSourceFolder,DSCTools_PSVersion
