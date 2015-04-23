#Requires -Version 4.0
##########################################################################################################################################
# DSCTools
##########################################################################################################################################
<#
.SYNOPSIS
This module provides miscellaneous helper functions for setting up and using Powershell DSC.

.DESCRIPTION 
This module contains functions to try and make setting up and using Desired State Configuration easier.

I noticed while attempting to set up my first DSC Pull server that it was a resonably intricate process with lots of room for mistakes.
There were many manual steps that could all go wrong. So I attempted to try and automate some of the steps involved with setting up
Pull servers and installing resource files onto them as well as configuring the LCM on the machines being configured.

The functions in this module should all multiple machines to be switched to pull mode (or back to push mode) with a single command.

An example of how this module would be used:

# Configure where the pull server is and how it can be connected to.
$DSCTools_DefaultPullServerName = 'DSCPULLSVR01'
$DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
$DSCTools_DefaultPullServerPort = 26054  # Pull server is running on this port
$DSCTools_DefaultPullServerPath = 'PrimaryPullServer/PSDSCPullServer.svc'
$DSCTools_DefaultModuleFolder = 'c:\DSC\Resources\'  # This is where all the DSC resources can be found
$DSCTools_DefaultPullServerResourcePath = 'DscService\Modules'  # This is a share+path on the Pull Server
$DSCTools_DefaultConfigFolder = 'DscService\configuration'   # This is a share+path on the Pull Server
$DSCTools_DefaultNodeConfigSourceFolder = "c:\DSC\Configuratons\"  

# These are the nodes that we are going to set up Pull mode for
$Nodes = @( `
    @{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuratons\SERVER01.MOF'} , `
    @{Name='SERVER02';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuratons\SERVER02.MOF'} , `
    @{Name='SERVER03';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuratons\SERVER03.MOF'} , `
    @{Name='SERVER04';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuratons\SERVER04.MOF'} , `
    @{Name='SERVER05';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e9';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuratons\SERVER05.MOF'} )

# Copy all the resources up to the pull server (zipped and with a checksum file).
Publish-DSCPullResources

# Install a DSC Pull Server
Enable-DSCPullServer -Nodes $Servers

# Set all the nodes to pull mode and copy the config files over to the pull server.
Start-DSCPullMode -Nodes $Nodes

# Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
Invoke-DSCPull -Nodes $Nodes

# Set all the nodes to back to push mode if we don't want to use Pul mode any more.
# Start-DSCPushMode -Nodes $Nodes

.VERSIONS
1.1   2014-11-22   Daniel Scott-Raynsford       Alowed Invoke-DSCPull to use a Nodes param
                                                Added test functions
                                                Added Configuration ConfigureLCMPushMode
                                                Added Function Start-DSCPushMode
1.0   2014-10-23   Daniel Scott-Raynsford       Initial Version

.TODO
Add ability to build the DSC configuration files if the MOF can't be found but the PS1 file can be found. Could also force rebuild the MOF
if the PS1 file is newer.
#>


##########################################################################################################################################
# Default Configuration Variables
##########################################################################################################################################
# Changing these variables after this module has been imported will allow the default parameters that the module cmdlets will use.
# This can be used to reduce the number of parameters that have to be passed to the module cmdlets if non-default values are used.

# This is the name of the pull server that will be used if no pull server parameter is passed to functions
# Setting this value is a lazy way of using a different pull server (rather than passing the pullserver parameter)
# to each function that needs it.
[String]$DSCTools_DefaultPullServerName = 'Localhost'

# This is the protocol that will be used by the DSC machines to connect to the pull server. This must be HTTP or HTTPS.
# If HTTPS is used then the HTTPS certificate on your Pull server must be trusted by all DSC Machines.
[String]$DSCTools_DefaultPullServerProtocol = 'HTTP'

# This is the port the Pull server is running on.
[Int]$DSCTools_DefaultPullServerPort = 8080

# This is the port the Compliance server is running on.
[Int]$DSCTools_DefaultComplianceServerPort = 8090

# This is the path and svc name component of the uRL used to access the Pull server.
[String]$DSCTools_DefaultPullServerPath = 'PSDSCPullServer.svc'

# This is the default endpoint name a Pull server will be created as when it is installed by Enable-DSCPullServer.
[String]$DSCTools_DefaultPullServerEndpointName = 'PSDSCPullServer'

# This is the default endpoint name a Compliance server will be created as when it is installed by Enable-DSCPullServer.
[String]$DSCTools_DefaultComplianceServerEndpointName = 'PSDSCComplianceServer'

# This is the location of the powershell modules folder where all the resources can be found that will be
# Installed into the pull server by the Publish-DSCPullResources function.
[String]$DSCTools_DefaultModuleFolder = "$($ENV:PROGRAMFILES)\windowspowershell\modules\All Resources\"

# This is the default folder on your pull server where any resources will get copied to by the
# Publish-DSCPullResources function. This can be a UNC path to a network share if required.
# This path may also be used by the Enable-DSCPullServer cmdlet as well.
[String]$DSCTools_DefaultPullServerResourcePath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Modules"

# This is the default folder on your pull server where the DSC configuration files will get copied to
# by the Start-DSCPullMode function. This can be a UNC path to a network share if required.
[String]$DSCTools_DefaultConfigFolder = "$($ENV:PROGRAMFILES)\windowspowershell\DscService\configuration"

# This is the default folder where the DSC configuration MOF files will be found.
[String]$DSCTools_DefaultNodeConfigSourceFolder = "$HOME\Documents\windowspowershell\configuration"

# This is the default folder where a DSC Pull Server will try and locate node configuraiton files.
# This should usually be a local path accessebile by the DSC Pull Server.
[String]$DSCTools_DefaultPullServerConfigurationPath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Configuration"

# This is the default folder where a new DSC Pull Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$DSCTools_DefaultPullServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCPullServer"

# This is the default folder where a new DSC Compliance Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$DSCTools_DefaultComplianceServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCComplianceServer"

# This is the URL to download the current version of the DSC Resource Kit.
# It may change when newer versions of the resource kit are released.
[String]$DSCTools_ResourceKitURL = "https://gallery.technet.microsoft.com/scriptcenter/DSC-Resource-Kit-All-c449312d/file/131371/4/DSC%20Resource%20Kit%20Wave%2010%2004012015.zip"

# This is the version of PowerShell that the Configuration files should be built to use.
# This is for future use when WMF 5.0 is available the LCM configuration files can be
# written in a more elegant fashion. Currently this should always be set to 4.0
[Float]$DSCTools_PSVersion = 4.0
##########################################################################################################################################

##########################################################################################################################################
# Main CmdLets
##########################################################################################################################################
Function Invoke-DSCCheck {
<#
.SYNOPSIS
Forces the LCM on the specified nodes to trigger a DSC check.

.DESCRIPTION 
This function will cause the Local Configuration Manager on the nodes provided to trigger a DSC check. If a node is set for pull mode
then the latest DSC configuration will be pulled down from the pull server. If a node is in push mode then the current DSC configuration
will be used.

The command is executed via a call to Invoke-Command on the destination computer's LCM which will be called via WinRM.
Therefore WinRM must be enabled on the destination computer's LCM and the appropriate firewall ports opened.
     
.PARAMETER ComputerName
This parameter should contain a list of computers that will have the a DSC check triggered.

.PARAMETER Nodes
This must contain an array of hash tables. Each hash table will represent a node that a DSC check should be triggered.

This parameter is provided to be consistent with the Start-DSCPullMode and Start-DSCPushMode functions.

The hash table must contain the following entries (other entries will be ignored):
Name = 

For example:
@(@{Name='SERVER01'},@{Name='SERVER02'})

.EXAMPLE 
 Invoke-DSCPull -ComputerName SERVER01,SERVER02,SERVER03
 Causes the LCMs on computers SERVER01, SERVER02 and SERVER03 to repull DSC Configuration MOF files from the DSC Pull server.

.EXAMPLE 
 Invoke-DSCPull -Nodes @(@{Name='SERVER01'},@{Name='SERVER02'})
 Causes the LCMs on computers SERVER01 and SERVER02 to repull DSC Configuration MOF files from the DSC Pull server.
 #>
    [CmdletBinding()]
    Param (
        [Parameter(
            ParameterSetName='ComputerName',
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
            )]
        [String[]]$ComputerName,

        [Parameter(
            ParameterSetName='Nodes'
            )]
        [Array]$Nodes
    ) # Param

    Begin {}
    Process {
        If ($ComputerName -eq $null) {
            Foreach ($Node In $Nodes) {
                # For some reason using the Invoke-CimMethod cmdlet with the -ComputerName parameter doesn't work
                # So the Invoke-Command is used instead to execute the command on the destination computer.
                $ComputerName = $Node.Name
                If (($ComputerName -eq $null) -or ($ComputerName -eq '')) {
                    Throw 'Node name is empty.'
                }
                Write-Verbose "Invoking Method PerformRequiredConfigurationChecks on node $ComputerName"
                Invoke-Command -ComputerName $ComputerName { `
                    Invoke-CimMethod `
                        -Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
                        -ClassName 'MSFT_DSCLocalConfigurationManager' `
                        -MethodName 'PerformRequiredConfigurationChecks' `
                        -Arguments @{ Flags = [uint32]1 }
                    } # Invoke-Command
            } # Foreach ($Node In $Nodes)
        } Else {
            Foreach ($Computer In $ComputerName) {
                # For some reason using the Invoke-CimMethod cmdlet with the -ComputerName parameter doesn't work
                # So the Invoke-Command is used instead to execute the command on the destination computer.
                Write-Verbose "Invoking Method PerformRequiredConfigurationChecks on node $ComputerName"
                Invoke-Command -ComputerName $Computer { `
                    Invoke-CimMethod `
                        -Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
                        -ClassName 'MSFT_DSCLocalConfigurationManager' `
                        -MethodName 'PerformRequiredConfigurationChecks' `
                        -Arguments @{ Flags = [uint32]1 }
                    } # Invoke-Command
            } # Foreach ($Computer In $ComputerName)
        } # If ($ComputerName -eq $null)
    } # Process
    End {}
} # Function Invoke-DSCCheck
##########################################################################################################################################

##########################################################################################################################################
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
c:\Program Files\WindowsPowerShell\DscService\Modules

.EXAMPLE 
 Publish-DSCPullResources -SourcePath 'c:\program files\windowspowershell\modules\a*' -PullServerResourcePath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
 This will cause all resources found in the c:\program files\windowspowershell\modules\ folder starting with the letter A to be zipped up and copied into the \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules folder.
 A checksum file will also be created for each zipped resource.

.EXAMPLE 
 Publish-DSCPullResources -SourcePath 'c:\program files\windowspowershell\modules\*'
 This will cause all resources found in the c:\program files\windowspowershell\modules\ folder to be zipped up and copied into the $DSCTools_DefaultPullServerResourcePath folder.
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

        [ValidateNotNullOrEmpty()]
        [String]$PullServerResourcePath=$DSCTools_DefaultPullServerResourcePath
    ) # Param

    Begin {
		# Is the PSCX Module Available? 
        If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
            Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
        }
        Import-Module PSCX

		# Check the Pull Server Resource Path exists.
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
##########################################################################################################################################

##########################################################################################################################################
Function Install-DSCResourceKit {
<#
.SYNOPSIS
Downlaods and installs the DSC Resource Kit.

.DESCRIPTION 
The DSC Resource Kit is a set of DSC Resources and other tools that are commonly used by DSC servers and nodes. It can be downloaded
manually from the Microsoft Script Center Gallery.

This function will attempt to download this file automatically and install it to the c:\program files\windows powershell\modules folder
on this computer.

This function requires the PSCX module to be available and installed on this computer.

PSCX Module can be downloaded from http://pscx.codeplex.com/
     
.PARAMETER ResourceKitURL
This is the URL to use to download the DSC Resource Kit from. It defaults to the URL contained in $DSCTools_ResourceKitURL.

.PARAMETER ModuleFolder
This optional parameter allows an alternate folder to install the DSC Resource Kit into. By default it will be installed into
$($ENV:PROGRAMFILES)\windowspowershell\modules

The Resouce Kit zip file contains a single folder called All Resources that will be created within the Modules folder.
All Resources will be inside this folder. All other cmdlets default to using this folder.

.PARAMETER Publish
If this switch is set to $true the DSC Resorce Kit files will also be published using Publish-DSCPullResources.

.PARAMETER UseCache
If this switch is set to $true then the DSC Resouce Kit File will not be redownloaded if one already exists in the temp folder.
If one does not exist it will be downloaded and it will not be deleted after the cmdlet finishes.

.PARAMETER PullServerResourcePath
This is the destination path to which the zipped resources and checksum files will be written to. The user running this command must have write access to this folder.

.EXAMPLE 
 Install-DSCResourceKit -Publish

 .LINK
  http://pscx.codeplex.com/
#>
    [CmdletBinding()]
    Param (
        [ValidateNotNullOrEmpty()]
        [String]$ResourceKitURL=$DSCTools_ResourceKitURL,

		[ValidateNotNullOrEmpty()]
        [String]$ModuleFolder=$DSCTools_DefaultModuleFolder,

		[Switch]$Publish = $false,

		[Switch]$UseCache = $false,

        [ValidateNotNullOrEmpty()]
        [String]$PullServerResourcePath=$DSCTools_DefaultPullServerResourcePath
    ) # Param

	# Is the PSCX Module Available? 
    If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
        Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
    }
    Import-Module PSCX

    If ($Publish) {
		# Check the Pull Server Resource Path exists.
		If ((Test-Path -Path $PullServerResourcePath -PathType Container) -eq $false) {
			Throw "$PullServerResourcePath could not be found."
		}
	}

	# Attempt to download the Resource kit file to the temp folder.
	$TempPath = "$Env:TEMP\DSCResourceKit.zip"
	If ((Test-Path -Path $TempPath) -and ($UseCache)) {
		Write-Verbose "Using cached Resource Kit File in $TempPath"
	} Else {
		Write-Verbose "Downloading $ResourceKitURL to $TempPath"
		Try {
			Invoke-WebRequest $ResourceKitURL -OutFile $TempPath	    
		} Catch {
			Throw "Error downloading DSC Resource File from $ResourceKitURL"
		}
	}

	# Unzip the Resouce Kit File
	Write-Verbose "Extracting $TempPath to $ModuleFolder"
	Try {
		Expand-Archive -Path $TempPath -OutputPath $ModuleFolder
	} Catch {
		Throw "Error unzipping Resource Kit file $TempPath to $ModuleFolder"
	} # Try

	If ($Publish)
	{ 
		# Publish the Resources from the Resource Kit
		Write-Verbose "Publishing Resources from $ModuleFolder to $PullServerResourcePath"
		Publish-DSCPullResources -SourcePath $ModuleFolder -PullServerResourcePath $PullServerResourcePath
	} # If

	If ($UseCache -eq $false) {
		Remove-Item -Path $TempPath
	} # If
} # Function Install-DSCResourceKit
##########################################################################################################################################

##########################################################################################################################################
Function Start-DSCPullMode {
<#
.SYNOPSIS
Configures one or mode nodes for Pull Mode.

.DESCRIPTION 
This function will create all configuration files required for a set of nodes to be placed into DSC Pull mode.

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

$($DSCTools_DefaultPullServerProtocol)://$($DSCTools_DefaultPullServerName):$($DSCTools_DefaultPullServerPort)/$($DSCTools_DefaultPullServerPath)

For example:

http://MyPullServer:8080/PSDSCPullServer.svc

.PARAMETER PullServerConfigPath
This optional parameter contains the full path to where the Pull Server DSC Node configuration files should be written to.

If this parameter is not passed it will be set to $DSCTools_DefaultConfigFolder

For example:

c:\program files\windowspowershell\DscService\configuration

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
 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server specified in $DSCTools_DefaultConfigFolder.

.EXAMPLE 
 Start-DSCPullMode `
    -Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'}) `
    -PullServerConfigPath '\\MyPullServer\DSCConfiguration'
 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server configration folder '\\MyPullServer\DSCConfiguration'
#>
    [CmdletBinding()]
    Param (
        [string]$PullServerURL="$($DSCTools_DefaultPullServerProtocol)://$($DSCTools_DefaultPullServerName):$($DSCTools_DefaultPullServerPort)/$($DSCTools_DefaultPullServerPath)",

        [String]$PullServerConfigPath=$DSCTools_DefaultConfigFolder,

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

##########################################################################################################################################
Function Start-DSCPushMode {
<#
.SYNOPSIS
Configures one or mode nodes for Push Mode.

.DESCRIPTION 
This function will create all configuration files required for a set of nodes to be placed into DSC Push mode.

It will take an array of nodes in the nodes parameter which will list all nodes that should be configured for push mode.

The function will:
1. Create the node DSC configuration MOF file if it is missing (and the configration file is noted in the Nodes array).
2. Create the node LCM configuration MOF file to configure the LCM for push mode.
3. Execute the node LCM configuration MOF on the node. 
     
.PARAMETER NodeConfigSourceFolder

This parameter is used to specify the folder where the node configration files can be found. If it is not passed it will default to the
module variable $DSCTools_DefaultNodeConfigSourceFolder.

This value will be ignored for any node that has a MOFFile key value set.

.PARAMETER Nodes
Must contain an array of hash tables. Each hash table will represent a node that should be configured full DSC push mode.

The hash table must contain the following entries:
Name = 

Each hash entry can also contain the following optional items. If each item is not specified it will default.
Guid = This is not required but retained for compatibility with Pull Mode
RebootNodeIfNeeded = $false
ConfigurationMode = 'ApplyAndAutoCorrect'
MofFile = This is the path and filename of the MOF file to use for this node. If not provided the MOF file will be used

For example:
@(@{Name='SERVER01';},@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})

.EXAMPLE 
 Start-DSCPushlMode `
    -Nodes @(@{Name='SERVER01'},@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})
 This command will cause the nodes SERVER01 and SERVER02 to be switched into Push mode.
#>
    [CmdletBinding()]
    Param (
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
            # Create the LCM MOF File to set the nodes LCM to pull mode
            ConfigureLCMPushMode `
                -NodeName $NodeName `
                -RebootNodeIfNeeded $RebootNodeIfNeeded `
                -ConfigurationMode $ConfigurationMode `
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
} # Start-DSCPushMode
##########################################################################################################################################

##########################################################################################################################################
Function Enable-DSCPullServer {
<#
.SYNOPSIS
Installs and configures a server as a DSC Pull Server.

.DESCRIPTION 
This function will create a MOF file for configuring a Windows Server computer to be a DSC Pull Server and then force DSC to apply the MOF to the server.

The name of as least one computer to install as a Pull Server is mandatory. Multiple computers can be specified to install more than one Pull Server.

Important Note: The server that will be installed onto must contain the DSC module xPSDesiredStateConfiguration installed into the PowerShell Module path.
This module is part of the DSC Resource kit found here: https://gallery.technet.microsoft.com/scriptcenter/DSC-Resource-Kit-All-c449312d

The function will:
1. Create the node DSC Pull Server configuration MOF file for the server.
2. Execute the node DSC Pull Server configuration MOF on the server. 
     
.PARAMETER Nodes
Must contain an array of hash tables. Each hash table will represent a node that should be configured as a DSC Pull Server.

The hash table must contain the following entries:
Name = 

Each hash entry can also contain the following optional items. If each item is not specified it will default.
PullServerPort = 

For example:
@(@{Name='DSCPULLSRV01';},@{Name='DSCPULLSRV01';})

.EXAMPLE 
 Enable-DSCPullServer -Nodes @(@{Name='DSCPULLSRV01';},@{Name='DSCPULLSRV01';})
 This command will install and configure a DSC Pull Server onto machines DSCPULLSRV01 and DSCPULLSRV02.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [Array]$Nodes
    )
    
	# Set up a temporary path
	$TempPath = "$Env:TEMP\Enable-DSCPullServer"
	Write-Verbose "Creating temporary folder $TempPath"
	New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

	Foreach ($Node In $Nodes) {
		# Create the Pull Mode MOF that will configure the elements on this computer needed for Pull Mode
		[String]$NodeName = $Node.Name
		If (($NodeName -eq '') -or ($NodeName -eq $null)) {
			Throw 'Node name is empty.'
		} # If

        Write-Verbose "Node $NodeName begin processing"
		# Get all the Pull Server properties from the node or use defaults.
		[Int]$PullServerPort = $Node.PullServerPort
		If (($PullServerPort -eq 0) -or ($PullServerPort -eq $null)) { $PullServerPort = $DSCTools_DefaultPullServerPort }
		[Int]$ComplianceServerPort = $Node.ComplianceServerPort
		If (($ComplianceServerPort -eq 0) -or ($ComplianceServerPort -eq $null)) { $ComplianceServerPort = $DSCTools_DefaultComplianceServerPort }
		[String]$CertificateThumbprint = $Node.CertificateThumbprint
		If (($CertificateThumbprint -eq '') -or ($CertificateThumbprint -eq $null)) { $CertificateThumbprint = 'AllowUnencryptedTraffic' }
		[String]$PullServerEndpointName = $Node.PullServerEndpointName
		If (($PullServerEndpointName -eq '') -or ($PullServerEndpointName -eq $null)) { $PullServerEndpointName = $DSCTools_DefaultPullServerEndpointName }
		[String]$PullServerResourcePath = $Node.PullServerResourcePath
		If (($ComplianceServerPhysicalPath -eq '') -or ($ComplianceServerPhysicalPath -eq $null)) { $ComplianceServerPhysicalPath = $DSCTools_DefaultPullServerResourcePath }
	    [String]$PullServerConfigurationPath = $Node.PullServerConfigurationPath
		If (($PullServerConfigurationPath -eq '') -or ($PullServerConfigurationPath -eq $null)) { $PullServerConfigurationPath = $DSCTools_DefaultPullServerConfigurationPath }
	    [String]$PullServerPhysicalPath = $Node.PullServerPhysicalPath
		If (($PullServerPhysicalPath -eq '') -or ($PullServerPhysicalPath -eq $null)) { $PullServerPhysicalPath = $DSCTools_DefaultPullServerPhysicalPath }
	    [String]$ComplianceServerEndpointName = $Node.ComplianceServerEndpointName
		If (($ComplianceServerEndpointName -eq '') -or ($ComplianceServerEndpointName -eq $null)) { $ComplianceServerEndpointName = $DSCTools_DefaultComplianceServerEndpointName }
	    [String]$ComplianceServerPhysicalPath = $Node.ComplianceServerPhysicalPath
		If (($ComplianceServerPhysicalPath -eq '') -or ($ComplianceServerPhysicalPath -eq $null)) { $ComplianceServerPhysicalPath = $DSCTools_DefaultComplianceServerPhysicalPath }
		Try {
			CreatePullServer `
				-NodeName $NodeName `
				-Output $TempPath `
				-PullServerPort $PullServerPort `
				-ComplianceServerPort $ComplianceServerPort `
				-CertificateThumbprint $CertificateThumbprint `
				-PullServerEndpointName $PullServerEndpointName `
				-PullServerResourcePath $PullServerResourcePath `
				-PullServerConfigurationPath $PullServerConfigurationPath `
				-PullServerPhysicalPath $PullServerPhysicalPath `
				-ComplianceServerEndpointName $ComplianceServerEndpointName `
				-ComplianceServerPhysicalPath $ComplianceServerPhysicalPath `
				| Out-Null
		} Catch {
			Throw "An error occurred creating the Pull Server MOF for $NodeName."
		}

		Write-Verbose "$NodeName Pull Server MOF $TempPath\$NodeName.MOF created"
        
		# Apply the Pull Server MOF File to the Server
		Try {
			Start-DSCConfiguration -ComputerName $NodeName -Path $TempPath -Wait
		} Catch {
			Throw "An error occurred applying the Pull Server MOF to $NodeName."
		}

		Write-Verbose "Node $NodeName set to use Pull Server MOF $TempPath"

		# Reove the LCM MOF File
		Remove-Item -Path "$TempPath\$NodeName.MOF"
		Write-Verbose "Node $NodeName Pull Server MOF $TempPath\$NodeName.MOF removed"
	} # Foreach
	
	Remove-Item -Path $TempPath -Recurse -Force
	Write-Verbose "Temporary folder $TempPath deleted"
} # Enable-DSCPullServer
##########################################################################################################################################

##########################################################################################################################################
# DSC Configurations for configuring DSC Pull Server and LCM
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

        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationMode = 'ApplyAndAutoCorrect',

        [ValidateNotNullOrEmpty()]
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
			ConfigurationMode = $ConfigurationMode
            ConfigurationModeFrequencyMins = 30
			ConfigurationID = $NodeGuid
			RefreshMode = 'Pull'
            RebootNodeIfNeeded = $RebootNodeIfNeeded
			DownloadManagerName = $DownloadManagerName
			DownloadManagerCustomData = $DownloadManagerCustomData
            RefreshFrequencyMins = 15
		} # LocalConfigurationManager
	} # Node $NodeName
} # Configuration ConfigureLCMPullMode
##########################################################################################################################################

##########################################################################################################################################
Configuration ConfigureLCMPushMode {
    Param (
        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeName,

        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationMode = 'ApplyAndAutoCorrect',

        [ValidateNotNullOrEmpty()]
        [boolean]$RebootNodeIfNeeded = $false

    ) # Param

    If ($ConfigurationMode -notin ('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')) {
        Throw 'ConfigurationMode is invalid.'
    }

	Node $NodeName {
		LocalConfigurationManager {
			ConfigurationMode = $ConfigurationMode
            ConfigurationModeFrequencyMins = 30
			RefreshMode = 'Push'
            RebootNodeIfNeeded = $RebootNodeIfNeeded
			DownloadManagerName = $Null
			DownloadManagerCustomData = $Null
            RefreshFrequencyMins = 30
		} # LocalConfigurationManager
	} # Node $NodeName
} # Configuration ConfigureLCMPushMode
##########################################################################################################################################

##########################################################################################################################################
Configuration CreatePullServer {
    Param (
        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeName,

        [ValidateNotNullOrEmpty()]
        [Int]$PullServerPort = 8080,

        [ValidateNotNullOrEmpty()]
        [Int]$ComplianceServerPort = 8090,

        [ValidateNotNullOrEmpty()]
        [String]$CertificateThumbprint = "AllowUnencryptedTraffic",

        [ValidateNotNullOrEmpty()]
        [String]$PullServerEndpointName = "PSDSCPullServer",

        [ValidateNotNullOrEmpty()]
        [String]$PullServerResourcePath = "$($env:PROGRAMFILES)\WindowsPowerShell\DscService\Modules",

        [ValidateNotNullOrEmpty()]
        [String]$PullServerConfigurationPath = "$($env:PROGRAMFILES)\WindowsPowerShell\DscService\Configuration",

        [ValidateNotNullOrEmpty()]
        [String]$PullServerPhysicalPath = "$($env:SystemDrive)\inetpub\wwwroot\PSDSCPullServer",

        [ValidateNotNullOrEmpty()]
        [String]$ComplianceServerEndpointName = "PSDSCComplianceServer",

        [ValidateNotNullOrEmpty()]
        [String]$ComplianceServerPhysicalPath = "$($env:SystemDrive)\inetpub\wwwroot\PSDSCComplianceServer"
    ) # Param

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

	Node $NodeName {
        WindowsFeature WebServer
        {
          Ensure = "Present"
          Name  = "Web-Server"
        }

        WindowsFeature DSCServiceFeature
        {
          Ensure = "Present"
          Name  = "DSC-Service"
        }

        xDscWebService PSDSCPullServer
        {
          Ensure = "Present"
          EndpointName = "PSDSCPullServer"
          Port = $PullServerPort
          PhysicalPath = $PullServerPhysicalPath
          CertificateThumbPrint = $CertificateThumbprint
          ModulePath = $PullServerResourcePath
          ConfigurationPath = $PullServerConfigurationPath
          State = "Started"
          DependsOn = "[WindowsFeature]DSCServiceFeature"
        }

        xDscWebService PSDSCComplianceServer
        {
          Ensure  = "Present"
          EndpointName = $ComplianceServerEndpointName
          Port = $ComplianceServerPort
          PhysicalPath = $ComplianceServerPhysicalPath
          CertificateThumbPrint = $CertificateThumbprint
          State = "Started"
          IsComplianceServer = $true
          DependsOn        = ("[WindowsFeature]DSCServiceFeature","[xDSCWebService]PSDSCPullServer")
        }
	} # Node $NodeName
} # Configuration CreatePullServer
##########################################################################################################################################

##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-InvokeDSCCheck {
    Invoke-DSCPull -ComputerName PLAGUE-MEMBER -Verbose
    Invoke-DSCPull -Nodes @(@{Name='PLAGUE-MEMBER'}) -Verbose
} # Test-InvokeDSCCheck

Function Test-PublishDSCPullResources {
    $DSCTools_DefaultPullServerName = 'PLAGUE-PDC'
    Publish-DSCPullResources
} # Test-PublishDSCPullResources

Function Test-StartDSCPullMode {
    $DSCTools_DefaultPullServerName = 'PLAGUE-PDC'
    Start-DSCPullMode -Nodes @(@{Name='PLAGUE-MEMBER';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootNodeIfNeeded=$true;MofFile='C:\Users\Daniel.PLAGUEHO\OneDrive\PS\DSC\PLAGUEConfiguration\PLAGUE-MEMBER.MOF'}) -Verbose
} # Test-StartDSCPullMode

Function Test-StartDSCPushMode {
    $DSCTools_DefaultPullServerName = 'PLAGUE-PDC'
    Start-DSCPushMode -Nodes @(@{Name='PLAGUE-MEMBER';RebootNodeIfNeeded=$false;ConfigurationMode='ApplyAndMonitor';MofFile='C:\Users\Daniel.PLAGUEHO\OneDrive\PS\DSC\PLAGUEConfiguration\PLAGUE-MEMBER.MOF'}) -Verbose
} # Test-StartDSCPushMode

Function Test-EnableDSCPullServer {
    $DSCTools_DefaultPullServerName = 'PLAGUE-PDC'
    Enable-DSCPullServer -Nodes @(@{Name='PLAGUE-PDC'}) -Verbose
    Get-DSCConfiguration
} # Test-StartDSCPushMode
##########################################################################################################################################

##########################################################################################################################################
# Exports
##########################################################################################################################################
Export-ModuleMember `
    -Function Invoke-DSCPull,Publish-DSCPullResources,Install-DSCResourceKit,Start-DSCPullMode,Start-DSCPushMode,Enable-DSCPullServer,Test* `
    -Variable DSCTools_PullServerName,DSCTools_PullServerProtocol,DSCTools_PullServerPort,DSCTools_PullServerPath,DSCTools_DefaultModuleFolder,DSCTools_DefaultResourceFolder,DSCTools_DefaultConfigFolder,DSCTools_DefaultNodeConfigSourceFolder,DSCTools_PSVersion
##########################################################################################################################################
