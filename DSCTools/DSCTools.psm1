#Requires -Version 4.0
##########################################################################################################################################
# DSCTools
##########################################################################################################################################
<#
See README.md for additional information.
Github Repo: https://github.com/PlagueHO/Powershell/tree/master/DSCTools
Script Center: https://gallery.technet.microsoft.com/scriptcenter/DSC-Tools-c96e2c53
#>


##########################################################################################################################################
# Default Configuration Variables
##########################################################################################################################################
# The DSCTools module contains some script variables that can be changed to allow the default properties
# of the module to be changed. This helps reduce the number of parameters that need to be passed to each
# DSCTools function if you want to configure your DSC system with parameters other than the default.

# This is the name of the pull server that will be used if no pull server parameter is passed to functions
# Setting this value is a lazy way of using a different pull server (rather than passing the pullserver parameter)
# to each function that needs it.
[String]$Script:DSCTools_DefaultPullServerName = 'localhost'

# This is the protocol that will be used by the DSC machines to connect to the pull server. This must be HTTP or HTTPS.
# If HTTPS is used then the HTTPS certificate on your Pull server must be trusted by all DSC Machines.
# This can also be set to SMB to use a pull server SMB share.
[String]$Script:DSCTools_DefaultPullServerProtocol = 'HTTP'

# This is the default endpoint name a Pull server will be created as when it is installed by Enable-DSCPullServer.
[String]$Script:DSCTools_DefaultPullServerEndpointName = 'PSDSCPullServer'

# This is the default endpoint name a Compliance server will be created as when it is installed by Enable-DSCPullServer.
[String]$Script:DSCTools_DefaultComplianceServerEndpointName = 'PSDSCComplianceServer'

# This is the location of the powershell modules folder where all the resources can be found that will be
# Installed into the pull server by the Publish-DSCPullResources function.
[String]$Script:DSCTools_DefaultResourcePath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\Modules\All Resources\"

# This is the default folder on your pull server where any resources will get copied to by the
# Publish-DSCPullResources function. This can be a UNC path to a network share if required.
# This path may also be used by the Enable-DSCPullServer cmdlet as well.
[String]$Script:DSCTools_DefaultPullServerResourcePath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Modules\"

# This is the default folder where a DSC Pull Server will try and locate node configuraiton files.
# This should usually be a local path accessebile by the DSC Pull Server.
[String]$Script:DSCTools_DefaultPullServerConfigurationPath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Configuration\"

# This is the path and svc name component of the uRL used to access the Pull server.
[String]$Script:DSCTools_DefaultPullServerPath = 'PSDSCPullServer.svc'

# This is the default folder where a new DSC Pull Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$Script:DSCTools_DefaultPullServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCPullServer\"

# This is the port the Pull server is running on.
[Int]$Script:DSCTools_DefaultPullServerPort = 8080

# This is the default folder where a new DSC Compliance Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$Script:DSCTools_DefaultComplianceServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCComplianceServer\"

# This is the port the Compliance server is running on.
[Int]$Script:DSCTools_DefaultComplianceServerPort = 8090

# This is the URL to download the current version of the DSC Resource Kit.
# It may change when newer versions of the resource kit are released.
[String]$Script:DSCTools_ResourceKitURL = "https://gallery.technet.microsoft.com/scriptcenter/DSC-Resource-Kit-All-c449312d/file/131371/4/DSC%20Resource%20Kit%20Wave%2010%2004012015.zip"

# This is the default folder the functions Start-DSCPull, Start-DSCPush and Update-DSCNodeConfiguration functions will look for
# MOF files for node configuration. In future they may also look for PS1 files that can be converted to MOF files.
[String]$Script:DSCTools_DefaultNodeConfigSourceFolder = "$HOME\Documents\"

# This is the version of PowerShell that the Configuration files should be built to use.
# This is for future use when WMF 5.0 is available the LCM configuration files can be
# written in a more elegant fashion. Currently this should always be set to 4.0
[Float]$Script:DSCTools_PSVersion = 4.0

# Get the PS Version to a variable for easier access.
[Int]$Script:PSVersion = $PSVersionTable.PSVersion.Major
##########################################################################################################################################

##########################################################################################################################################
# Support Functions
##########################################################################################################################################
Function InitZip
{
	# If PS is version 4 or less then we require the PSCX Module to unzip/zip files
	If ($Script:PSVersion -lt 5) {
		# Is the PSCX Module Available? 
        If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
            Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
        } # If
        Import-Module PSCX	
	} # If
} # Function InitZip
##########################################################################################################################################

##########################################################################################################################################
Function UnzipFile ([String]$ZipFileName,[String]$DestinationPath)
{
	If ($Script:PSVersion -lt 5) {
		Expand-Archive -Path $ZipFileName -OutputPath $DestinationPath
	} Else {
		Expand-Archive -Path $ZipFileName -DestinationPath $DestinationPath -Force
	} # If
} # Function UnzipFile
##########################################################################################################################################

##########################################################################################################################################
Function ZipFolder ([String]$ZipFileName,[String]$SourcePath)
{
	If ($Script:PSVersion -lt 5) {
        Get-ChildItem -Path $SourcePath -Recurse | Write-Zip -IncludeEmptyDirectories -OutputPath $ZipFileName -EntryPathRoot $SourcePath -Level 9
	} Else {
		Compress-Archive -DestinationPath $ZipFileName -Path "$SourcePath\*" -CompressionLevel Optimal
	} # If
} # Function ZipFolder
##########################################################################################################################################

##########################################################################################################################################
Function IsLocalHost ([String]$Name)
{
	Return (($Name -match 'localhost') -or ($Name -match '127.0.0.1') -or ("$Name." -match "$ENV:COMPUTERNAME\."))
} # Function IsLocalHost
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
		 Invoke-DSCCheck -ComputerName SERVER01,SERVER02,SERVER03
		 Causes the LCMs on computers SERVER01, SERVER02 and SERVER03 to repull DSC Configuration MOF files from the DSC Pull server.

.EXAMPLE 
		 Invoke-DSCCheck -Nodes @(@{Name='SERVER01'},@{Name='SERVER02'})
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
			# Load all the nodes into the computername array.
            $ComputerName = @()
			Foreach ($Node In $Nodes) {
				$ComputerName += $Node.Name
			} # Foreach
		} # Foreach
        Foreach ($Computer In $ComputerName) {
			# If PS5 is installed then the Update-DscConfiguration command can be called -otherwise we need to
			# use Invoke-CimMethod on the remote host.
			If (IsLocalHost($Computer)) {
				If ($Script:PSVersion -lt 5) {
					Write-Verbose "Invoke-DSCCheck: Invoking Method PerformRequiredConfigurationChecks on Localhost"
					# For some reason using the Invoke-CimMethod cmdlet with the -ComputerName parameter doesn't work
					# So the Invoke-Command is used instead to execute the command on the destination computer.
					Invoke-CimMethod `
						-Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
						-ClassName 'MSFT_DSCLocalConfigurationManager' `
						-MethodName 'PerformRequiredConfigurationChecks' `
						-Arguments @{ Flags = [uint32]1 }
				} Else {
					Write-Verbose "Invoke-DSCCheck: Calling Update-DscConfigration on Localhost"
					Update-DscConfiguration
				} # If
			} Else {
				If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
					If ($Script:PSVersion -lt 5) {
						Write-Verbose "Invoke-DSCCheck: Invoking Method PerformRequiredConfigurationChecks on node $Computer"
						# For some reason using the Invoke-CimMethod cmdlet with the -ComputerName parameter doesn't work
						# So the Invoke-Command is used instead to execute the command on the destination computer.
						Invoke-Command -ComputerName $Computer { `
							Invoke-CimMethod `
								-Namespace 'root/Microsoft/Windows/DesiredStateConfiguration' `
								-ClassName 'MSFT_DSCLocalConfigurationManager' `
								-MethodName 'PerformRequiredConfigurationChecks' `
								-Arguments @{ Flags = [uint32]1 }
						} # Invoke-Command
					} Else {
						Write-Verbose "Invoke-DSCCheck: Calling Update-DscConfigration on node $Computer"
						Update-DscConfiguration -ComputerName $Computer
					} # If
				} Else {
					Write-Error "Invoke-DSCCheck: Error contacting $Computer. DSC check could not be triggered."
				}
			} # If
        } # Foreach ($Computer In $ComputerName)
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

		If PS 4 is used then this function requires the PSCX module to be available and installed on this computer.

		PSCX Module can be downloaded from http://pscx.codeplex.com/
     
.PARAMETER ModulePath
		This is the path containing the folders containing all the DSC resources.
		If this is not passed the default path of "c:\program files\windowspowershell\modules\" will be used.

.PARAMETER PullServerResourcePath
		This is the destination path to which the zipped resources and checksum files will be written to.
		The user running this command must have write access to this folder.

		If this parameter is not set the path will be set to:
		c:\Program Files\WindowsPowerShell\DscService\Modules

.EXAMPLE 
		 Publish-DSCPullResources -ModulePath 'c:\program files\windowspowershell\modules\all resources\a*' `
			-PullServerResourcePath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
		 This will cause all resources found in the c:\program files\windowspowershell\modules\all resources\ folder
		 starting with the letter A to be zipped up and copied into the folder
		 \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules
		 A checksum file will also be created for each zipped resource.

.EXAMPLE 
		 Publish-DSCPullResources -ModulePath 'c:\program files\windowspowershell\modules\all resources\*'
		 This will cause all resources found in the c:\program files\windowspowershell\modules\all resources\ folder
		 to be zipped up and copied into the folder found in the default variable $Script:DSCTools_DefaultPullServerResourcePath.
		 A checksum file will also be created for each zipped resource.

.EXAMPLE 
		 'c:\program files\windowspowershell\modules\all resources\','c:\powershell\modules\' | Publish-DSCPullResources `
			-PullServerResourcePath '\\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules'
		 This will cause all resources found in either the c:\program files\windowspowershell\modules\all resources folder or
		 c:\powershell\modules\ folder to be zipped up and copied into the folder
		 \\DSCPullServer\c$\program files\windowspowershell\DSCService\Modules
		 A checksum file will also be created for each zipped resource.

 .LINK
		http://pscx.codeplex.com/
#>
    [CmdletBinding()]
    Param (
        [Parameter(
            ValueFromPipeline = $true
            )]
        [Alias('FullName')]
        [String[]]$ModulePath = $Script:DSCTools_DefaultResourcePath,

        [ValidateNotNullOrEmpty()]
        [String]$PullServerResourcePath = $Script:DSCTools_DefaultPullServerResourcePath
    ) # Param

    Begin {
		InitZip

		# Check the Pull Server Resource Path exists.
        If ((Test-Path -Path $PullServerResourcePath -PathType Container) -eq $false) {
            Throw "Folder $PullServerResourcePath could not be found."
        }
    } # Begin

    Process {
        Foreach ($Path in $ModulePath) {
            Write-Verbose "Publish-DSCPullResources: Examining $Path for Resource Folders"
            If (Test-Path -Path $Path -PathType Container) {
                # This path in the source path array is a folder
                Write-Verbose "Publish-DSCPullResources: Folder $Path Found"        

				# Get all the subfolders
                $Resources = Get-ChildItem -Path $Path -Attributes Directory
                Foreach ($Resource in $Resources) {
                    Write-Verbose "Publish-DSCPullResources: Possible Resource Folder $Resource Found"

                    # A folder was found inside the source path - does it contain a resource?
                    $ResourcePath = Join-Path -Path $Path -ChildPath $Resource
                    $Manifest = Join-Path -Path $ResourcePath -ChildPath "$Resource.psd1"
                    $DSCResourcesFolder = Join-Path -Path $ResourcePath -ChildPath DSCResources
                    If ((Test-Path -Path $Manifest -PathType Leaf) -and (Test-Path -Path $DSCResourcesFolder -PathType Container)) {
                        Write-Verbose "Publish-DSCPullResources: Resource $Resource in Resource Folder $ResourcePath Found"

                        # This folder appears to contain a valid DSC Resource
                        # Get the version number out of the manifest file
                        $ManifestContent = Invoke-Expression -Command (Get-Content -Path $Manifest -Raw)
                        $ModuleVersion = $ManifestContent.ModuleVersion
                        Write-Verbose "Publish-DSCPullResources: Resource $Resource is Version $ModuleVersion"

                        # Generate the Zip file name (including the destination to the pull server folder)
                        $ZipFileName = Join-Path -Path $PullServerResourcePath -ChildPath "$($Resource)_$($ModuleVersion).zip"

                        # Zip up the resource straight into the pull server resources path
						If (Test-Path -Path $ZipFileName) {
	                        Write-Verbose "Publish-DSCPullResources: Deleting Existing Resource File $ZipFileName" 
							Remove-Item -Path $ZipFileName
						}
                        Write-Verbose "Publish-DSCPullResources: Zipping $ResourcePath to $ZipFileName" 
						ZipFolder -ZipFileName $ZipFileName -SourcePath $ResourcePath

                        # Generate the checksum for the zip file
                        New-DSCCheckSum -ConfigurationPath $ZipFileName -Force | Out-Null
                        Write-Verbose "Publish-DSCPullResources: Checksum for Resource File $ZipFileName Created"
                    } # If
                } # Foreach ($Resource in $Resources)
            } Else {
                Write-Verbose "Publish-DSCPullResources: File $Path Is Ignored"
            } # If
        } # Foreach ($Path in $ModulePath)
    } # Process
    End {}
} # Function Publish-DSCPullResources
##########################################################################################################################################

##########################################################################################################################################
Function Install-DSCResourceKit {
<#
.SYNOPSIS
		Downloads and installs the DSC Resource Kit. It can also optionally publish the Resources to a pull server.

.DESCRIPTION 
		The DSC Resource Kit is a set of DSC Resources and other tools that are commonly used by DSC servers and nodes. It can be downloaded
		manually from the Microsoft Script Center Gallery.

		This function will attempt to download this file automatically and install it to the c:\program files\windows powershell\modules folder
		on this computer.

		If PS 4 is used then this function requires the PSCX module to be available and installed on this computer.

		PSCX Module can be downloaded from http://pscx.codeplex.com/
     
.PARAMETER ResourceKitURL
This is the URL to use to download the DSC Resource Kit from. It defaults to the URL contained in $Script:DSCTools_ResourceKitURL.

.PARAMETER ModulePath
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

		Note: If this is a SMB Pull Server then resources should be installed into the same folder as the configuration files.

.EXAMPLE 
		 Install-DSCResourceKit -Publish

 .LINK
		http://pscx.codeplex.com/
#>
    [CmdletBinding()]
    Param (
        [ValidateNotNullOrEmpty()]
        [String]$ResourceKitURL=$Script:DSCTools_ResourceKitURL,

		[ValidateNotNullOrEmpty()]
        [String]$ModulePath="$($ENV:PROGRAMFILES)\windowspowershell\modules",

		[Switch]$Publish = $false,

		[Switch]$UseCache = $false,

        [ValidateNotNullOrEmpty()]
        [String]$PullServerResourcePath=$Script:DSCTools_DefaultPullServerResourcePath
    ) # Param
	InitZip

    If ($Publish) {
		# Check the Pull Server Resource Path exists.
		If ((Test-Path -Path $PullServerResourcePath -PathType Container) -eq $false) {
			Throw "$PullServerResourcePath could not be found."
		}
	}

	# Attempt to download the Resource kit file to the temp folder.
	$TempPath = "$Env:TEMP\DSCResourceKit.zip"
	If ((Test-Path -Path $TempPath) -and ($UseCache)) {
		Write-Verbose "Install-DSCResourceKit: Using Cached Resource Kit File $TempPath"
	} Else {
		Write-Verbose "Install-DSCResourceKit: Downloading $ResourceKitURL to $TempPath"
		Try {
			Invoke-WebRequest $ResourceKitURL -OutFile $TempPath	    
		} Catch {
			Throw
		}
	}

	# Unzip the Resouce Kit File
	Write-Verbose "Install-DSCResourceKit: Extracting $TempPath to $ModulePath"
	Try {
		UnzipFile -ZipFileName $TempPath -DestinationPath $ModulePath
		#Expand-Archive -Path $TempPath -OutputPath $ModulePath
	} Catch {
		Throw
	} # Try

	If ($Publish)
	{ 
		# Publish the Resources from the Resource Kit
	
		Write-Verbose "Install-DSCResourceKit: Publishing Resources from $ModulePath to $PullServerResourcePath"
		Publish-DSCPullResources -ModulePath (Join-Path -Path $ModulePath -ChildPath "All Resources") -PullServerResourcePath $PullServerResourcePath
	} # If

	If ($UseCache -eq $false) {
		Write-Verbose "Install-DSCResourceKit: Deleting Resource Kit File $TempPath"
		Remove-Item -Path $TempPath
	} # If
} # Function Install-DSCResourceKit
##########################################################################################################################################

##########################################################################################################################################
Function Enable-DSCPullServer {
<#
.SYNOPSIS
		Installs and configures one or more servers as a DSC Pull Servers.

.DESCRIPTION 
		This function will create a MOF file for configuring a Windows Server computer to be a DSC Pull Server and then force DSC to apply the MOF to the server.

		The name of as least one computer to install as a Pull Server is mandatory. Multiple computers can be specified to install more than one Pull Server.

		Important Note: The server that will be installed onto must contain the DSC module xPSDesiredStateConfiguration installed into the PowerShell Module path. This module is part of the DSC Resource kit found here: https://gallery.technet.microsoft.com/scriptcenter/DSC-Resource-Kit-All-c449312d

		The function will:
		1. Create the node DSC Pull Server configuration MOF file for the server.
		2. Execute the node DSC Pull Server configuration MOF on the server.

		If the Pull Server Protocol is set to SMB then the Ports, Endpoint, 
     
.PARAMETER Nodes
		Must contain an array of hash tables. Each hash table will represent a node that should be configured as a DSC Pull Server.
		
		The hash table must contain the following entries:
		Name = Name of the computer to install as a DSC Pull Server.

		Each hash entry can also contain the following optional items. If each item is not specified it will default.
		PullServerProtocol = The protocol the Pull Server will use. Defaults to $Script:DSCTools_DefaultPullServerProtocol.
		PullServerPort = The port the Pull Server will run on. Defaults to $Script:DSCTools_DefaultPullServerPort.
		ComplianceServerPort = The port the Complaince Server will run on. Defaults to $Script:DSCTools_DefaultComplianceServerPort.
		CertificateThumbprint = The certificate thumbprint to use if HTTPS should be used. Defaults to using HTTP.
		PullServerEndpointName = The endpoint name to use when creating the Pull Server web site. Defaults to $Script:DSCTools_DefaultPullServerEndpointName.
		PullServerResourcePath = The path the DSC Pull Server will look for resource files in. Defaults to $Script:DSCTools_DefaultPullServerResourcePath.
		PullServerConfigurationPath = The path the DSC Pull Server will use look for configuration (MOF) files in. Defaults to $Script:DSCTools_DefaultPullServerConfigurationPath.
		PullServerPhysicalPath = The local path to where the DSC Pull Server web site will be created. Defaults to $Script:DSCTools_DefaultPullServerPhysicalPath.
		ComplianceServerEndpointName = The endpoint name to use when creating the Compliance Server web site. Defaults to $Script:DSCTools_DefaultComplianceServerEndpointName.
		ComplianceServerPhysicalPath = The local path to where the DSC Compliance Server web site will be created. Defaults to $Script:DSCTools_DefaultComplianceServerPhysicalPath.
		Credential = Credentials to use to configure the DSC Pull Server using. Defaults to none.

		For example:
		@(@{Name='DSCPULLSRV01';},@{Name='DSCPULLSRV01';})

.PARAMETER ComputerName
		Name of the computer to install as a DSC Pull Server.

.PARAMETER PullServerProtocol
		The protocol the Pull Server will use. Defaults to $Script:DSCTools_DefaultPullServerProtocol.

.PARAMETER PullServerPort
		The port the Pull Server will run on. Defaults to $Script:DSCTools_DefaultPullServerPort.

.PARAMETER ComplianceServerPort
		The port the Complaince Server will run on. Defaults to $Script:DSCTools_DefaultComplianceServerPort.

.PARAMETER CertificateThumbprint
		The certificate thumbprint to use if HTTPS should be used. Defaults to using HTTP.

.PARAMETER PullServerEndpointName
		The endpoint name to use when creating the Pull Server web site. Defaults to $Script:DSCTools_DefaultPullServerEndpointName.

.PARAMETER PullServerResourcePath
		The path the DSC Pull Server will look for resource files in. Defaults to $Script:DSCTools_DefaultPullServerResourcePath.

.PARAMETER PullServerConfigurationPath
		The path the DSC Pull Server will use look for configuration (MOF) files in. Defaults to $Script:DSCTools_DefaultPullServerConfigurationPath.

.PARAMETER PullServerPhysicalPath
		The local path to where the DSC Pull Server web site will be created. Defaults to $Script:DSCTools_DefaultPullServerPhysicalPath.

.PARAMETER ComplianceServerEndpointName
		The endpoint name to use when creating the Compliance Server web site. Defaults to $Script:DSCTools_DefaultComplianceServerEndpointName.

.PARAMETER ComplianceServerPhysicalPath
		The local path to where the DSC Compliance Server web site will be created. Defaults to $Script:DSCTools_DefaultComplianceServerPhysicalPath.

.PARAMETER Credential
		Credentials to use to configure the DSC Pull Server using. Defaults to none.

.EXAMPLE 
		 Enable-DSCPullServer -Nodes @(@{Name='DSCPULLSRV01';},@{Name='DSCPULLSRV01';})
		 This command will install and configure a DSC Pull Server onto machines DSCPULLSRV01 and DSCPULLSRV02.

.EXAMPLE 
		 Enable-DSCPullServer -ComputerName DSCPULLSRV01
		 This command will install and configure a DSC Pull Server onto machine DSCPULLSRV01
#>
    [CmdletBinding(DefaultParameterSetName='ComputerName')]
    Param (
        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[String]$ComputerName='localhost',

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateSet('HTTP','HTTPS','SMB')]
		[String]$PullServerProtocol,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[Int]$PullServerPort,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[Int]$ComplianceServerPort,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[String]$CertificateThumbprint,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[String]$PullServerEndpointName,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[String]$PullServerResourcePath,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [String]$PullServerConfigurationPath,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [String]$PullServerPhysicalPath,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [String]$ComplianceServerEndpointName,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [String]$ComplianceServerPhysicalPath,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [PSCredential]$Credential,

        [Parameter(ParameterSetName='Nodes')]
        [Array]$Nodes
    )
    
	# Set up a temporary path
	$TempPath = "$Env:TEMP\Enable-DSCPullServer"
	Write-Verbose "Enable-DSCPullServer: Creating Temporary Folder $TempPath."
	New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

	If (-not $Nodes) {
		$Nodes = @{
			Name=$ComputerName;
			PullServerProtocol = $PullServerProtocol;
			PullServerPort = $PullServerPort;
			ComplianceServerPort = $ComplianceServerPort;
			CertificateThumbprint = $CertificateThumbprint;
			PullServerEndpointName = $PullServerEndpointName;
			PullServerResourcePath = $PullServerResourcePath;
			PullServerConfigurationPath = $PullServerConfigurationPath;
			PullServerPhysicalPath = $PullServerPhysicalPath;
			ComplianceServerEndpointName = $ComplianceServerEndpointName;
			ComplianceServerPhysicalPath = $ComplianceServerPhysicalPath;
			Credential = $Credential;
		}
	} # If
	Foreach ($Node In $Nodes) {
		# Create the Pull Mode MOF that will configure the elements on this computer needed for Pull Mode
		[String]$NodeName = $Node.Name
		If (($NodeName -eq '') -or ($NodeName -eq $null)) {
			$NodeName = $ENV:COMPUTERNAME
		} # If

		# Get the Pull Server Protocol
		[String]$PullServerProtocol = $Node.PullServerProtocol
		If (($PullServerProtocol -eq '') -or ($PullServerProtocol -eq $null)) { $PullServerProtocol = $Script:DSCTools_DefaultPullServerProtocol }
        Write-Verbose "Enable-DSCPullServer: Enabling $PullServerProtocol Pull Server $NodeName"

		# Get the credentials that need to be used to apply the DSC Config to the Pull Server
		[PSCredential]$Credential = $Node.Credential

		If ($PullServerProtocol -match  'http') {
			# An HTTP/HTTPS Pull Server is required
			[String]$CertificateThumbprint = $Node.CertificateThumbprint
			# Get the certificate thumbprint
			If (($CertificateThumbprint -eq '') -or ($CertificateThumbprint -eq $null)) { 
				# If the pull server is HTTPS and no certificate thumbprint was provided then throw an error.
				If ($PullServerProtocol -match 'https') {
					Throw "A certificate thumbprint must be provided if the Pull Server protocol is set to HTTPS"
				}
				$CertificateThumbprint = 'AllowUnencryptedTraffic'
			}
			# Get all the Pull Server properties from the node or use defaults.
			[Int]$PullServerPort = $Node.PullServerPort
			If (($PullServerPort -eq 0) -or ($PullServerPort -eq $null)) { $PullServerPort = $Script:DSCTools_DefaultPullServerPort }
			[Int]$ComplianceServerPort = $Node.ComplianceServerPort
			If (($ComplianceServerPort -eq 0) -or ($ComplianceServerPort -eq $null)) { $ComplianceServerPort = $Script:DSCTools_DefaultComplianceServerPort }
			[String]$PullServerEndpointName = $Node.PullServerEndpointName
			If (($PullServerEndpointName -eq '') -or ($PullServerEndpointName -eq $null)) { $PullServerEndpointName = $Script:DSCTools_DefaultPullServerEndpointName }
			[String]$PullServerResourcePath = $Node.PullServerResourcePath
			If (($PullServerResourcePath -eq '') -or ($PullServerResourcePath -eq $null)) { $PullServerResourcePath = $Script:DSCTools_DefaultPullServerResourcePath }
			[String]$PullServerConfigurationPath = $Node.PullServerConfigurationPath
			If (($PullServerConfigurationPath -eq '') -or ($PullServerConfigurationPath -eq $null)) { $PullServerConfigurationPath = $Script:DSCTools_DefaultPullServerConfigurationPath }
			[String]$PullServerPhysicalPath = $Node.PullServerPhysicalPath
			If (($PullServerPhysicalPath -eq '') -or ($PullServerPhysicalPath -eq $null)) { $PullServerPhysicalPath = $Script:DSCTools_DefaultPullServerPhysicalPath }
			[String]$ComplianceServerEndpointName = $Node.ComplianceServerEndpointName
			If (($ComplianceServerEndpointName -eq '') -or ($ComplianceServerEndpointName -eq $null)) { $ComplianceServerEndpointName = $Script:DSCTools_DefaultComplianceServerEndpointName }
			[String]$ComplianceServerPhysicalPath = $Node.ComplianceServerPhysicalPath
			If (($ComplianceServerPhysicalPath -eq '') -or ($ComplianceServerPhysicalPath -eq $null)) { $ComplianceServerPhysicalPath = $Script:DSCTools_DefaultComplianceServerPhysicalPath }
			Try {
				Write-Verbose "Enable-DSCPullServer: HTTP Pull Server MOF $TempPath\$NodeName.MOF for $NodeName Begin Creation"

				# Load the CreatePullServer Configuration into memory (dot source it)
				# The file should be in Configuration folder beneath the folder the module is in.
				. "$(Join-Path -Path $PSScriptRoot -ChildPath 'Configuration\Config_EnablePullServerHTTP.ps1')"
				Config_EnablePullServerHTTP `
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
				Throw
			}
			Write-Verbose "Enable-DSCPullServer: HTTP Pull Server MOF $TempPath\$NodeName.MOF for $NodeName Created Successfully"
		} Else {
			[String]$PullServerConfigurationPath = $Node.PullServerConfigurationPath
			If (($PullServerConfigurationPath -eq '') -or ($PullServerConfigurationPath -eq $null)) { $PullServerConfigurationPath = $Script:DSCTools_DefaultPullServerConfigurationPath }
			[String]$PullServerEndpointName = $Node.PullServerEndpointName
			If (($PullServerEndpointName -eq '') -or ($PullServerEndpointName -eq $null)) { $PullServerEndpointName = $Script:DSCTools_DefaultPullServerEndpointName }

			Try {
				Write-Verbose "Enable-DSCPullServer: SMB Pull Server MOF $TempPath\$NodeName.MOF for $NodeName Begin Creation"

				# Load the CreatePullServer Configuration into memory (dot source it)
				# The file should be in Configuration folder beneath the folder the module is in.
				. "$(Join-Path -Path $PSScriptRoot -ChildPath 'Configuration\Config_EnablePullServerSMB.ps1')"
				Config_EnablePullServerSMB `
					-NodeName $NodeName `
					-Output $TempPath `
					-PullServerEndpointName $PullServerEndpointName `
					-PullServerConfigurationPath $PullServerConfigurationPath `
					| Out-Null
			} Catch {
				Throw
			}
			Write-Verbose "Enable-DSCPullServer: SMB Pull Server MOF $TempPath\$NodeName.MOF for $NodeName Created Successfully"

		}

        # Apply the Pull Server MOF File to the Server
        If  (IsLocalHost($NodeName)) {
			# Apply the Pull Server MOF File to the localhost
			If ($NodeName -match '\.') {
				Write-Warning "Enable-DSCPullServer: Warning Applying MOF $TempPath\$NodeName.MOF may fail because an FQDN name was used for Pull Server."
			}
			Try {
				Write-Verbose "Enable-DSCPullServer: Applying Pull Server MOF $TempPath\$NodeName.MOF to Localhost"
				Start-DSCConfiguration -Path $TempPath -Wait -Force
				Write-Verbose "Enable-DSCPullServer: Pull Server MOF $TempPath\$NodeName.MOF Applied to Localhost Successfully"
			} Catch {
			    Write-Warning "Enable-DSCPullServer: Error Applying Pull Server MOF $TempPath\$NodeName.MOF to Localhost"
				Throw
			} # Try
		} Else {
			# Apply the LCM MOF File to a remote node
			If (Test-Connection -ComputerName $NodeName -Count 1 -Quiet) {
				Try {
					Write-Verbose "Enable-DSCPullServer: Applying Pull Server MOF $TempPath\$NodeName.MOF to $NodeName"
					If ($Credential) {
						Start-DSCConfiguration -Path $TempPath -ComputerName $NodeName -Credential $Credential -Wait -Force
					} Else {
						Start-DSCConfiguration -Path $TempPath -ComputerName $NodeName -Wait -Force
					} # If
					Write-Verbose "Enable-DSCPullServer: Pull Server MOF $TempPath\$NodeName.MOF Applied to $NodeName Successfully"
				} Catch {
					Write-Warning "Enable-DSCPullServer: Error Applying Pull Server MOF $TempPath\$NodeName.MOF to $NodeName"
					Throw
				} # Try
			} Else {
				Write-Error "Enable-DSCPullServer: Error contacting $NodeName. Push Mode Configuration was not applied."
			} # If
		} # If

		# Reove the LCM MOF File
		Remove-Item -Path "$TempPath\$NodeName.MOF" -Force
		Write-Verbose "Enable-DSCPullServer: MOF $TempPath\$NodeName.MOF for $NodeName Deleted"
	} # Foreach
	
	Remove-Item -Path $TempPath -Recurse -Force
	Write-Verbose "Enable-DSCPullServer: Temporary Folder $TempPath Deleted"
} # Enable-DSCPullServer
##########################################################################################################################################

##########################################################################################################################################
Function Set-DSCPullServerLogging {
<#
.SYNOPSIS
		Enable/Disable DSC pull server logging on one or more DSC Pull Servers.

.DESCRIPTION 
     
.PARAMETER Nodes
		Must contain an array of hash tables. Each hash table will represent a pull server node that should be configured with logging.
		
		The hash table must contain the following entries:
		Name = Name of the DSC Pull Server 

		Each hash entry can also contain the following optional items. If each item is not specified it will default.
		AnalyticLog = a boolean value used to enable/disable Analytic logging.
		DebugLog = a boolean value used to enable/disable Debug logging.
		OperationalLog = a boolean value used to enable/disable Operational logging.

		For example:
		@(@{Name='DSCPULLSRV01';Analytic=$True;Debug=$False;Operational=$True;},@{Name='DSCPULLSRV01';Analytic=$True;Debug=$False;Operational=$True;})

.PARAMETER ComputerName
		Name of the computer to configure the DSC Pull Server logging on.

.PARAMETER AnalyticLog
		A boolean value used to enable/disable Analytic logging.

.PARAMETER DebugLog
		A boolean value used to enable/disable Debug logging.

.PARAMETER OperationaLog
		A boolean value used to enable/disable Operational logging.

.PARAMETER Credential
		Credentials to use to configure the DSC Pull Server using. Defaults to none.

.EXAMPLE 
		 Set-DSCPullServerLogging -Nodes @(@{Name='DSCPULLSRV01';Analytic=$True;Debug=$False;Operational=$True;},@{Name='DSCPULLSRV01';Analytic=$True;Debug=$False;Operational=$True;})
		 This command will enable Analytic and Operational logging for DSC Pull Servers DSCPULLSRV01 and DSCPULLSRV02.

.EXAMPLE 
		 Set-DSCPullServerLogging -ComputerName DSCPULLSRV01 -Analytic $True -Debug $False -Operational $True
		 This command will enable Analytic and Operational logging for DSC Pull Server DSCPULLSRV01.
#>
    [CmdletBinding(DefaultParameterSetName='ComputerName')]
    Param (
        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
		[String]$ComputerName,

        [Parameter(ParameterSetName='ComputerName')]
		[ValidateNotNullOrEmpty()]
	    [PSCredential]$Credential,

		[Boolean]$AnalyticLog=$false,

		[Boolean]$DebugLog=$false,

		[Boolean]$OperationalLog=$false,

        [Parameter(ParameterSetName='Nodes')]
        [Array]$Nodes
    )
    
	If ($ComputerName) {
		$Nodes = @{
			Name=$ComputerName;
			Credential=$Credential;
		}
	} # If
	Foreach ($Node In $Nodes) {
		# Create an array of additional parameters that will be added to the end of the command to set the log
		$Parameters = @{}

		# Was a computer name provided?
		[String]$NodeName = $Node.Name
		If (($NodeName -eq '') -or ($NodeName -eq $null) -or (IsLocalHost($NodeName))) {
			# None was provided or localhost was used.			
		} Else {
			$Parameters += @{ComputerName=$NodeName;}
			# Were credentials provided?
			If ($Node.Credential) {
				$Parameters += @{Credential=$Node.Credential;}
			} Elseif ($Credential) {
				$Parameters += @{Credential=$Credential;}			
			}
		} # If

		# Enable/Disable the Analytic Log
		If (($Node.AnalyticLog) -or ($AnalyticLog)) {
			Try {
				Update-xDscEventLogStatus -Channel Analytic -Status Enabled @Parameters
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Analytic Logging Enabled"
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Enabling Analytic Logging on $NodeName"
			}
		} Else {
			Try {
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Analytic Logging Disabled"
				Update-xDscEventLogStatus -Channel Analytic -Status Disabled @Parameters
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Disabling Analytic Logging on $NodeName"
			}
		} # If

		# Enable/Disable the Debug Log
		If (($Node.DebugLog) -or ($DebugLog)) {
			Try {
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Debug Logging Enabled"
				Update-xDscEventLogStatus -Channel Debug -Status Enabled @Parameters
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Enabling Debug Logging on $NodeName"
			}
		} Else {
			Try {
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Debug Logging Disabled"
				Update-xDscEventLogStatus -Channel Debug -Status Disabled @Parameters
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Disabling Debug Logging on $NodeName"
			}
		} # If

		# Enable/Disable the Operational Log
		If (($Node.OperationalLog) -or ($OperationalLog)) {
			Try {
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Operational Logging Enabled"
				Update-xDscEventLogStatus -Channel Operational -Status Enabled @Parameters
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Enabling Operational Logging on $NodeName"
			}
		} Else {
			Try {
				Write-Verbose "Set-DSCPullServerLogging: Pull Server $NodeName Operational Logging Disabled"
				Update-xDscEventLogStatus -Channel Operational -Status Disabled @Parameters 
			} Catch {
				Write-Error "Set-DSCPullServerLogging: Error Disabling Operational Logging on $NodeName"
			}
		} # If
	} # Foreach
} # Set-DSCPullServerLogging
##########################################################################################################################################

##########################################################################################################################################
Function Update-DSCNodeConfiguration {
<#
.SYNOPSIS
		Updates the configuration for one or more nodes in a Pull Server.

.DESCRIPTION 
		This function will copy the node configuration MOF files to the pull server for the specified nodes.

		Note: The nodes should have already been successfully put into Pull Mode against the pull server using Start-DSCPullMode function.
		If any of these nodes are in push mode then the updated configuration will not be applied untill the node is switched into pull
		mode using the Start-DSCPullMode function.

		It will take an array of nodes in the nodes parameter which will list all nodes that should recieve updated MOF files.

		The function will:
		1. Create the node DSC configuration MOF file if it is missing (and the configration .ps1 file is specified).
		2. Copy the node DSC configuration MOF file and rename with GUID provided in the nodes array.
		3. Create a node DSC configuration MOF checksum file.
		4. Move the node DSC configration MOF and checksum file to the Pull server.
     
.PARAMETER ComputerName
		This is the name of the computer that should be switched into Pull Mode. This parameter should not be set if Nodes are provided.

.PARAMETER Guid
		This is the GUID that will be used to identify this computers configuration on the DSC Pull sever. This parameter should not be set if Nodes are provided.

.PARAMETER MOFFile
		This is MOF file that contains the DSC Configuration for this computer. This parameter should not be set if Nodes are provided.

.PARAMETER PullServerConfigurationPath
		This optional parameter contains the full path to where the Pull Server DSC Node configuration files should be written to.

		If this parameter is not passed it will be set to $Script:DSCTools_DefaultPullServerConfigurationPath

		For example:

		c:\program files\windowspowershell\DscService\configuration

.PARAMETER NodeConfigSourceFolder

		This parameter is used to specify the folder where the node configration files can be found. If it is not passed it will default to the
		module variable $Script:DSCTools_DefaultNodeConfigSourceFolder.

		This value will be ignored for any node that has a MOFFile key value set.

.PARAMETER Nodes
		Must contain an array of hash tables. Each hash table will represent a node that should be configured full DSC pull mode.

		The hash table must contain the following entries:
		Name = 

		Each hash entry can also contain the following optional items. If each item is not specified it will default.
		Guid = If no guid is passed for this node a new one will be created
		MofFile = This is the path and filename of the MOF file to use for this node. If not provided the MOF file will default to the NodeConfigSourceFolder parameter plus NodeName
		CertificateThumbprint = This is the certificate thumbprint of the certificate that will be used to encrypt credentials passed to this node. If none are supplied then the certificate thuumbpring parameter is used unless it it not passed.

		For example:
		@(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'})

.PARAMETER CertificateThumbprint
		This is the certificate thumbprint of the certificate that will be used to encrypt credentials contained in these configuration files.
		This is for future use and is not currently supported.

.PARAMETER InvokeCheck
		If this switch is set it will cause Invoke-DSCCheck to be called after the node configuration is updated. This will cause the configuration change to be immediately applied.

.EXAMPLE 
		 Update-DSCNodeConfiguration `
			-Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'}) 
		 This command will upload a new confguration file for node SERVER01 to the Pull Server configuration folder specified in $Script:DSCTools_DefaultPullServerConfigurationPath.

.EXAMPLE 
		 Update-DSCNodeConfiguration `
			-Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'}) `
			-PullServerConfigurationPath '\\MyPullServer\DSCConfiguration'
		 This command will upload a new configuraton file for node SERVER01 to the Pull Server configuration folder '\\MyPullServer\DSCConfiguration'
#>
    [CmdletBinding()]
    Param (
        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[string]$ComputerName,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[guid]$Guid,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
	    [string]$MOFFile,

        [Parameter(ParameterSetName='Nodes')]
        [Array]$Nodes,

        [ValidateNotNullOrEmpty()]
		[String]$PullServerConfigurationPath=$Script:DSCTools_DefaultPullServerConfigurationPath,

        [ValidateNotNullOrEmpty()]
		[String]$NodeConfigSourceFolder=$Script:DSCTools_DefaultNodeConfigSourceFolder,

		[ValidateNotNullOrEmpty()]
		[String]$CertificateThumbprint,

		[Switch]$InvokeCheck
    )
    
    If ($ComputerName) {
		$Nodes = @{
			Name=$ComputerName;
			Guid=$Guid;
			MofFile=$MOFFile;
		} # $Nodes
	} # If

	Foreach ($Node In $Nodes) {
        # Clear the node error flag
        [Boolean]$NodeError = $false
        
        # Get the Node parameters into variables and check them
        [String]$NodeName = $Node.Name
        If ($NodeName -eq '') {
            Throw 'Node name is empty.'
        } # If

        [String]$NodeGuid = $Node.Guid
        If ($NodeGuid -eq '') {
            Throw "Guid for node $NodeName is empty."
        } # If
        Write-Verbose "Update-DSCNodeConfiguration: Updating $NodeName Guid $NodeGuid with Pull Mode configuration"

		# This is the certificate thumbrint that will be used to encrypt any credentials in this configuration.
		[String]$Cert = $Node.CertificateThumbprint
        If (($Cert -eq $null) -or ($Cert -eq '')) {
            $Cert = $CertificateThumbprint
        } # If

		# If the node doesn't have a specific MOF path specified then see if we can figure it out
        # Based on other parameters specified - or even create it.
        [String]$MofFile = $Node.MofFile
        If ($MofFile -eq $null) {
            $SourceMof = "$NodeConfigSourceFolder\$NodeName.mof"
        } Else {
            $SourceMof = $MofFile
        } # If
        Write-Verbose "Update-DSCNodeConfiguration: $NodeName Will Use Configuration MOF $SourceMof"

        # If the MOF doesn't throw an error?
        If (-not (Test-Path -PathType Leaf -Path $SourceMof)) {
            #TODO: Can we try to create the MOF file from the configuration?
            Write-Error "Update-DSCNodeConfiguration: Node $NodeName Configuration MOF $SourceMof Could Not Be Found"
            $NodeError = $true
        } # If

        If (-not $NodeError) {
            # Create and/or Move the Node Configuration file to the Pull server
            $DestMof = Join-Path -Path $PullServerConfigurationPath -ChildPath "$NodeGuid.mof"
            Copy-Item -Path $SourceMof -Destination $DestMof -Force
            Write-Verbose "Update-DSCNodeConfiguration: Node $NodeName Configuration MOF $SourceMof Copied to $DestMof"
            New-DSCChecksum -ConfigurationPath $DestMof -Force
            Write-Verbose "Update-DSCNodeConfiguration: Node $NodeName Configuration MOF Checksum Created for $DestMof"
			If ($InvokeCheck) {
				Invoke-DSCCheck -ComputerName $NodeName
			} # If
		} # If

		Write-Verbose "Update-DSCNodeConfiguration: Node $NodeName Pull Mode configuration update complete"
    } # Foreach
} # Update-DSCNodeConfiguration
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
     
.PARAMETER ComputerName
		This is the name of the computer that should be switched into Pull Mode. This parameter should not be set if Nodes are provided.

.PARAMETER Guid
		This is the GUID that will be used to identify this computers configuration on the DSC Pull sever. This parameter should not be set if Nodes are provided.

.PARAMETER MOFFile
		This is MOF file that contains the DSC Configuration for this computer. This parameter should not be set if Nodes are provided.

.PARAMETER RebootIfNeeded
		This parameter controls whether the LCM is allowed to reboot the computer when applying configuration. If this value is also provided in any Nodes then the node value will be used instead.

.PARAMETER ConfigurationMode
		This parameter specifies the configuration mode for the LCM. If this value is also provided in any Nodes then the node value will be used instead.

.PARAMETER PullServerURL
		This is the URL that will be used by the Local Configuration Manager of the Node to pull the configuration files.

		If this parameter is not passed it is generated from the Module Variables:

		$($Script:DSCTools_DefaultPullServerProtocol)://$($Script:DSCTools_DefaultPullServerName):$($Script:DSCTools_DefaultPullServerPort)/$($Script:DSCTools_DefaultPullServerPath)

		For example:

		http://MyPullServer:8080/PSDSCPullServer.svc

.PARAMETER PullServerConfigurationPath
		This optional parameter contains the full path to where the Pull Server DSC Node configuration files should be written to.

		If this parameter is not passed it will be set to $Script:DSCTools_DefaultPullServerConfigurationPath

		For example:

		c:\program files\windowspowershell\DscService\configuration

.PARAMETER NodeConfigSourceFolder

		This parameter is used to specify the folder where the node configration files can be found. If it is not passed it will default to the
		module variable $Script:DSCTools_DefaultNodeConfigSourceFolder.

		This value will be ignored for any node that has a MOFFile key value set.

.PARAMETER Nodes
		Must contain an array of hash tables. Each hash table will represent a node that should be configured full DSC pull mode.

		The hash table must contain the following entries:
		Name = 

		Each hash entry can also contain the following optional items. If each item is not specified it will default.
		Guid = If no guid is passed for this node a new one will be created
		RebootIfNeeded = $false
		ConfigurationMode = 'ApplyAndAutoCorrect'
		MofFile = This is the path and filename of the MOF file to use for this node. If not provided the MOF file will default to the NodeConfigSourceFolder parameter plus NodeName
		Credential = These are node specific credentials that will be used to apply the LCM configuration. If none are supplied then the Credential parameter is used unless it it not passed.
		CertificateThumbprint = This is the certificate thumbprint of the certificate that will be used to encrypt credentials passed to this node. If none are supplied then the certificate thuumbpring parameter is used unless it it not passed.

		For example:
		@(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';Guid='';RebootIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})

.PARAMETER Credential
		These are the credentials (if required) that will be used to apply the LCM configuration to all nodes where a node specific credentials weren't supplied.

.PARAMETER CertificateThumbprint
		This is the certificate thumbprint of the certificate that will be used to encrypt credentials passed to any of these nodes.

.PARAMETER PullServerCredential
		These are the credentials (if required) that all nodes will need to use to pull the configuration from the Pull Server.

.EXAMPLE 
		 Start-DSCPullMode `
			-Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';RebootIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})
		 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server specified in $Script:DSCTools_DefaultPullServerConfigurationPath.

.EXAMPLE 
		 Start-DSCPullMode `
			-Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'},@{Name='SERVER02';RebootIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'}) `
			-PullServerConfigurationPath '\\MyPullServer\DSCConfiguration'
		 This command will cause the nodes SERVER01 and SERVER02 to be switched into Pull mode and the appropriate configration files uploaded to the Pull server configration folder '\\MyPullServer\DSCConfiguration'
#>
    [CmdletBinding()]
    Param (
        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[string]$ComputerName,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[guid]$Guid,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
	    [string]$MOFFile,

        [Parameter(ParameterSetName='Nodes')]
        [Array]$Nodes,

	    [switch]$RebootIfNeeded=$false,

	    [ValidateSet('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')]
		[String]$ConfigurationMode='ApplyAndAutoCorrect',

		[ValidateNotNullOrEmpty()]
		[string]$PullServerURL="",

        [ValidateNotNullOrEmpty()]
		[String]$PullServerConfigurationPath=$Script:DSCTools_DefaultPullServerConfigurationPath,

        [ValidateNotNullOrEmpty()]
		[String]$NodeConfigSourceFolder=$Script:DSCTools_DefaultNodeConfigSourceFolder,

		[ValidateNotNullOrEmpty()]
		[PSCredential]$Credential,

		[ValidateNotNullOrEmpty()]
		[String]$CertificateThumbprint,

		[ValidateNotNullOrEmpty()]
		[PSCredential]$PullServerCredential
    )
    
    # Set up a temporary path
    $TempPath = "$Env:TEMP\Start-DSCPullMode"
    Write-Verbose "Start-DSCPullMode: Creating Temporary Folder $TempPath"
    New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

    If ($ComputerName) {
		$Nodes = @{
			Name=$ComputerName;
			Guid=$Guid;
			MofFile=$MOFFile;
		} # $Nodes
	} # If

	# Figure out the Pull Server URL if it wasn't specified
	If (($PullServerURL -eq '') -or ($PullServerURL -eq $null)) {
		If ($Script:DSCTools_DefaultPullServerProtocol -match "SMB") {
			$PullServerURL = "\\$($Script:DSCTools_DefaultPullServerName)\$($Script:DSCTools_DefaultPullServerEndpointName)\"
		} Else {
			$PullServerURL = "$($Script:DSCTools_DefaultPullServerProtocol)://$($Script:DSCTools_DefaultPullServerName):$($Script:DSCTools_DefaultPullServerPort)/$($Script:DSCTools_DefaultPullServerPath)"
		}
	}

	Foreach ($Node In $Nodes) {
        # Clear the node error flag
        [Boolean]$NodeError = $false
        
        # Get the Node parameters into variables and check them
        [String]$NodeName = $Node.Name
        If ($NodeName -eq '') {
            Throw 'Node name is empty.'
        } # If
        Write-Verbose "Start-DSCPullMode: Configuring $NodeName for Pull Mode"

        [String]$NodeGuid = $Node.Guid
        If ($NodeGuid -eq '') {
            $NodeGuid = [guid]::NewGuid()
        } # If
		
		[Switch]$Reboot = $Node.RebootIfNeeded
        If ($Reboot -eq $null) {
            $Reboot = $RebootIfNeeded
		} # If

        [String]$Mode = $Node.ConfigurationMode
        If (($Mode -eq $null) -or ($Mode -eq '')) {
            $Mode = $ConfigurationMode
        } # If
		Write-Verbose "Start-DSCPullMode: $NodeName Will Use GUID $NodeGuid with Configuration Mode $Mode $(@{$true='and will Reboot If Needed';$false=''}[$RebootIfNeeded])"

        # Were credentials supplied to allow the LCM to be applied to the node?
		[PSCredential]$Cred = $Node.Credential
        If ($Cred -eq $null) {
            $Cred = $Credential
        } # If

		[String]$Cert = $Node.CertificateThumbprint
        If (($Cert -eq $null) -or ($Cert -eq '')) {
            $Cert = $CertificateThumbprint
        } # If

		# If the node doesn't have a specific MOF path specified then see if we can figure it out
        # Based on other parameters specified - or even create it.
        [String]$MofFile = $Node.MofFile
        If ($MofFile -eq $null) {
            $SourceMof = "$NodeConfigSourceFolder\$NodeName.mof"
        } Else {
            $SourceMof = $MofFile
        } # If
        Write-Verbose "Start-DSCPullMode: $NodeName Will Use Configuration MOF $SourceMof"

        # If the MOF doesn't throw an error?
        If (-not (Test-Path -PathType Leaf -Path $SourceMof)) {
            #TODO: Can we try to create the MOF file from the configuration?
            Write-Error "Start-DSCPullMode: Node $NodeName Configuration MOF $SourceMof Could Not Be Found"
            $NodeError = $true
        } # If

        If (-not $NodeError) {
            # Create and/or Move the Node Configuration file to the Pull server
            $DestMof = Join-Path -Path $PullServerConfigurationPath -ChildPath "$NodeGuid.mof"
            Copy-Item -Path $SourceMof -Destination $DestMof -Force
            Write-Verbose "Start-DSCPullMode: Node $NodeName Configuration MOF $SourceMof Copied to $DestMof"
            New-DSCChecksum -ConfigurationPath $DestMof -Force
            Write-Verbose "Start-DSCPullMode: Node $NodeName Configuration MOF Checksum Created for $DestMof"

            # Create the LCM MOF File to set the nodes LCM to pull mode
            Write-Verbose "Start-DSCPullMode: Node $NodeName LCM MOF $TempPath\$NodeName.MOF Start Creation"
			. "$(Join-Path -Path $PSScriptRoot -ChildPath 'Configuration\Config_SetLCMPullMode.ps1')"
            If ($PullServerCredential -eq $null) {
				Config_SetLCMPullMode `
					-NodeName $NodeName `
					-NodeGuid $NodeGuid `
					-RebootNodeIfNeeded $Reboot `
					-ConfigurationMode $Mode `
					-PullServerURL $PullServerURL `
					-Output $TempPath `
					| Out-Null
			} Else {
				If ($Cert -eq $null) {
					Throw "A Certificate Thumbprint must be provided for the node if a Pull Server credential is passed"
				} # If
				Config_SetLCMPullMode `
					-NodeName $NodeName `
					-NodeGuid $NodeGuid `
					-RebootNodeIfNeeded $Reboot `
					-ConfigurationMode $Mode `
					-PullServerURL $PullServerURL `
					-CertificateId $Cert `
					-Credential $PullServerCredential `
					-Output $TempPath `
					| Out-Null
			} # If
            Write-Verbose "Start-DSCPullMode: Node $NodeName LCM MOF $TempPath\$NodeName.MOF Created Successfully"
        
            If (IsLocalHost($NodeName)) {
				# Apply the LCM MOF File to the local node
				Try {
					Write-Verbose "Start-DSCPullMode: Setting Localhost to use LCM MOF $TempPath"
					Set-DSCLocalConfigurationManager -Path $TempPath
					Write-Verbose "Start-DSCPullMode: Node Localhost set to use LCM MOF $TempPath"
				} Catch {
			        Write-Error "Start-DSCPullMode: Error Setting Localhost to use LCM MOF $TempPath"
				} # Try
			} Else {
				# Apply the LCM MOF File to a remote node
				If (Test-Connection -ComputerName $NodeName -Count 1 -Quiet) {
					Try {
						Write-Verbose "Start-DSCPullMode: Setting $NodeName to use LCM MOF $TempPath"
						If ($Cred) {
							Set-DSCLocalConfigurationManager -Path $TempPath -ComputerName $NodeName -Credential $Cred 
						} Else {
							Set-DSCLocalConfigurationManager -Path $TempPath -ComputerName $NodeName
						} # If
						Write-Verbose "Start-DSCPullMode: Node $NodeName set to use LCM MOF $TempPath"
					} Catch {
						Write-Error "Start-DSCPullMode: Error Setting $NodeName to use LCM MOF $TempPath"
					} # Try
				} Else {
					Write-Error "Start-DSCPullMode: Error contacting $NodeName. Pull Mode Configuration was not applied."
				} # If
			} # If


            # Reove the LCM MOF File
            Remove-Item -Path "$TempPath\$NodeName.meta.MOF"
            Write-Verbose "Start-DSCPullMode: Node $NodeName LCM MOF $TempPath\$NodeName.meta.MOF Removed"
        } # If

    Write-Verbose "Start-DSCPullMode: Node $NodeName Processing Complete"
    } # Foreach

    Remove-Item -Path $TempPath -Recurse -Force
    Write-Verbose "Start-DSCPullMode: Temporary Folder $TempPath Deleted"
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
     
.PARAMETER ComputerName
		This is the name of the computer that should be switched into Push Mode. This parameter should not be set if Nodes are provided.

.PARAMETER MOFFile
		This is MOF file that contains the DSC Configuration for this computer. This parameter should not be set if Nodes are provided.

.PARAMETER RebootIfNeeded
		This parameter controls whether the LCM is allowed to reboot the computer when applying configuration. If this value is also provided in any Nodes then the node value will be used instead.

.PARAMETER ConfigurationMode
		This parameter specifies the configuration mode for the LCM. If this value is also provided in any Nodes then the node value will be used instead.

.PARAMETER NodeConfigSourceFolder
		This parameter is used to specify the folder where the node configration files can be found. If it is not passed it will default to the
		module variable $Script:DSCTools_DefaultNodeConfigSourceFolder.

		This value will be ignored for any node that has a MOFFile key value set.

.PARAMETER Nodes
		Must contain an array of hash tables. Each hash table will represent a node that should be configured full DSC push mode.

		The hash table must contain the following entries:
		Name = 

		Each hash entry can also contain the following optional items. If each item is not specified it will default.
		RebootIfNeeded = $false
		ConfigurationMode = 'ApplyAndAutoCorrect'
		MofFile = This is the path and filename of the MOF file to use for this node. If not provided the MOF file will be used

		For example:
		@(@{Name='SERVER01';},@{Name='SERVER02';RebootIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})

.EXAMPLE 
		 Start-DSCPushlMode `
			-Nodes @(@{Name='SERVER01'},@{Name='SERVER02';RebootIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'})
		 This command will cause the nodes SERVER01 and SERVER02 to be switched into Push mode.
#>
    [CmdletBinding()]
    Param (
        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[string]$ComputerName,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
		[guid]$Guid,

        [Parameter(ParameterSetName='ComputerName')]
	    [ValidateNotNullOrEmpty()]
	    [string]$MOFFile,

        [Parameter(ParameterSetName='Nodes')]
        [Array]$Nodes,

	    [switch]$RebootIfNeeded=$false,

	    [ValidateSet('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')]
		[String]$ConfigurationMode='ApplyAndAutoCorrect',

        [String]$NodeConfigSourceFolder=$Script:DSCTools_DefaultNodeConfigSourceFolder
    )
    
    # Set up a temporary path
    $TempPath = "$Env:TEMP\Start-DSCPushMode"
    Write-Verbose "Start-DSCPushMode: Creating Temporary Folder $TempPath"
    New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null

    If ($ComputerName) {
		$Nodes = @{
			Name=$ComputerName;
			MofFile=$MOFFile;
		} # $Nodes
	} # If

    Foreach ($Node In $Nodes) {
        # Clear the node error flag
        $NodeError = $false
        
        # Get the Node parameters into variables and check them
        $NodeName = $Node.Name
        If ($NodeName -eq '') {
            Throw 'Node name is empty.'
        }
        Write-Verbose "Start-DSCPushMode: Configuring $NodeName for Push Mode"

		[Switch]$Reboot = $Node.RebootIfNeeded
        If ($Reboot -eq $null) {
            $Reboot = $RebootIfNeeded
		} # If

        [String]$Mode = $Node.ConfigurationMode
        If (($Mode -eq $null) -or ($Mode -eq '')) {
            $Mode = $ConfigurationMode
        } # If
		Write-Verbose "Start-DSCPushMode: $NodeName set to Configuration Mode $Mode $(@{$true='and will Reboot If Needed';$false=''}[$RebootIfNeeded])"

        # If the node doesn't have a specific MOF path specified then see if we can figure it out
        # Based on other parameters specified - or even create it.
        $MofFile = $Node.MofFile
        If ($MofFile -eq $null) {
            $SourceMof = "$NodeConfigSourceFolder\$NodeName.mof"
        } Else {
            $SourceMof = $MofFile
        }
        Write-Verbose "Start-DSCPushMode: Node $NodeName Will Use Configuration MOF $SourceMof"

        # If the MOF doesn't throw an error?
        If (-not (Test-Path -PathType Leaf -Path $SourceMof)) {
            #TODO: Can we try to create the MOF file from the configuration?
            Write-Error "Start-DSCPushMode: Node $NodeName Configuration MOF $SourceMof Could Not Be Found"
            $NodeError = $true
        }

		Try {
			Start-DscConfiguration -ComputerName $NodeName -Path (Split-Path -Path $SourceMof)
		} Catch {
            Write-Error "Start-DSCPushMode: Node $NodeName Configuration MOF $SourceMof Could Not Be Applied because an Error Occurred"
            $NodeError = $true
		}

		If (-not $NodeError) {
            # Create the LCM MOF File to set the nodes LCM to push mode
            Write-Verbose "Start-DSCPushMode: Node $NodeName LCM MOF $TempPath\$NodeName.MOF Start Creation"
			. "$(Join-Path -Path $PSScriptRoot -ChildPath 'Configuration\Config_SetLCMPushMode.ps1')"
            Config_SetLCMPushMode `
                -NodeName $NodeName `
                -RebootNodeIfNeeded $RebootIfNeeded `
                -ConfigurationMode $Mode `
                -Output $TempPath `
                | Out-Null
            Write-Verbose "Start-DSCPushMode: Node $NodeName LCM MOF $TempPath\$NodeName.MOF Created Successfully"
        
            # Apply the LCM MOF File to the node
            If  (IsLocalHost($NodeName)) {
				# Apply the LCM MOF File to the local node
				Try {
					Write-Verbose "Start-DSCPushMode: Setting Localhost to use LCM MOF $TempPath"
					Set-DSCLocalConfigurationManager -Path $TempPath
					Write-Verbose "Start-DSCPushMode: Localhost set to use LCM MOF $TempPath"
				} Catch {
			        Write-Error "Start-DSCPushMode: Error Setting Localhost to use LCM MOF $TempPath"
				} # Try
			} Else {
				# Apply the LCM MOF File to a remote node
				If (Test-Connection -ComputerName $NodeName -Count 1 -Quiet) {
					Try {
						Write-Verbose "Start-DSCPushMode: Setting $NodeName to use LCM MOF $TempPath"
						If ($Cred) {
							Set-DSCLocalConfigurationManager -Path $TempPath -ComputerName $NodeName -Credential $Cred 
						} Else {
							Set-DSCLocalConfigurationManager -Path $TempPath -ComputerName $NodeName
						} # If
			            Write-Verbose "Start-DSCPushMode: Node $NodeName set to use LCM MOF $TempPath"
					} Catch {
			            Write-Error "Start-DSCPushMode: Error Setting $NodeName to use LCM MOF $TempPath"					
					} # Try
				} Else {
					Write-Error "Start-DSCPushMode: Error contacting $NodeName. Push Mode Configuration was not applied."
				} # If
			} # If

            # Reove the LCM MOF File
            Remove-Item -Path "$TempPath\$NodeName.meta.MOF"
            Write-Verbose "Start-DSCPushMode: Node $NodeName LCM MOF $TempPath\$NodeName.meta.MOF Removed"
        } # If

    Write-Verbose "Start-DSCPushMode: Node $NodeName Processing Complete"
    } # Foreach

    Remove-Item -Path $TempPath -Recurse -Force
    Write-Verbose "Start-DSCPushMode: Temporary folder $TempPath deleted"
} # Start-DSCPushMode
##########################################################################################################################################

##########################################################################################################################################
Function Get-xDscConfiguration {
<#
.SYNOPSIS
        Returns the DSC configuration for this machine or for a remote node.

.DESCRIPTION
        The Get-xDscConfiguration cmdlet gets the current configuration of the node, if configuration exists. Specify computers by using CIM sessions or the ComputerName parameter. If you do not specify a target computer, the cmdlet gets the configuration from the local computer.

.PARAMETER AsJob
        Runs the cmdlet as a background job. Use this parameter to run commands that take a long time to complete.
        The cmdlet immediately returns an object that represents the job and then displays the command prompt. You can continue to work in the session while the job completes. To manage the job, use the *-Job cmdlets. To get the job results, use the Receive-Job cmdlet.
        For more information about Windows PowerShell® background jobs, see about_Jobs.

.PARAMETER CimSession
        Runs the cmdlet in a remote session or on a remote computer. Enter a computer name or a session object, such as the output of a New-CimSession or Get-CimSession cmdlet. The default is the current session on the local computer.

.PARAMETER ComputerName
        Runs the cmdlet on a remote computer, forming a CIM session connection and then closing it after getting the configuration.

.PARAMETER UseSSL
        Runs the cmdlet on a remote computer connecting with SSL.

.PARAMETER Credemtial
        Uses these credentials to connect to the remote computer.

.PARAMETER ThrottleLimit
        Specifies the maximum number of concurrent operations that can be established to run the cmdlet. If this parameter is omitted or a value of 0 is entered, then Windows PowerShell® calculates an optimum throttle limit for the cmdlet based on the number of CIM cmdlets that are running on the computer. The throttle limit applies only to the current cmdlet, not to the session or to the computer.

.EXAMPLE
        PS C:\> Get-xDscConfiguration
        This command gets the current configuration for the local computer.

.EXAMPLE
        PS C:\> Get-xDscConfiguration -ComputerName DSCSVR01 -Credential (Get-Credential) -UseSSL
        This example gets the current configuration from computer DSCSVR01, connecting to it via SSL and the credentials supplied.

.INPUTS
.OUTPUTS
.LINK
        http://go.microsoft.com/fwlink/?LinkID=288760
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Alias('Session')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        ${CimSession},

        [int]
        ${ThrottleLimit},

        [switch]
        ${AsJob},

        [Parameter(ParameterSetName='ComputerName')]
        [ValidateNotNullOrEmpty()]
		[String]
		${ComputerName},

        [Parameter(ParameterSetName='ComputerName')]
        [PSCredential]
		${Credential},

        [Parameter(ParameterSetName='ComputerName')]
        [switch]
		${UseSSL}
		)

    begin {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            } # if

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-DscConfiguration', [System.Management.Automation.CommandTypes]::Function)
			if ($ComputerName) {
				$cimSessionParameters = @{}
				[Void]$PSBoundParameters.Remove('ComputerName')
				if ($UseSSL) {
					[Void]$PSBoundParameters.Remove('UseSSL')
					$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
					$cimSessionParameters += @{SessionOption=$cimSessionOption}
				} # if
				if ($Credential) {
					[Void]$PSBoundParameters.Remove('Credential')
					$cimSessionParameters += @{Credential=$Credential}
				} # if
				Write-Verbose "Get-xDscConfiguration: Connecting to $ComputerName"
				$cimSession = New-CimSession -ComputerName $ComputerName @CimSessionParameters
				Write-Verbose "Get-xDscConfiguration: Calling Get-DscConfiguration"
				$scriptCmd = {& $wrappedCmd @PSBoundParameters -CimSession $cimSession }
			} else {
				$scriptCmd = {& $wrappedCmd @PSBoundParameters }
			} # if
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        } # try
    } # begin

    process {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        } # try
    } # process

    end {
        try {
            $steppablePipeline.End()
			if ($ComputerName -and $cimSession) {
				Write-Verbose "Get-xDscConfiguration: Disconnecting from $ComputerName"
				Remove-CimSession -CimSession $cimSession
			} # if
        } catch {
            throw
        } # try
    } # end
} # Function Get-xDscConfiguration
##########################################################################################################################################

##########################################################################################################################################
Function Get-xDscLocalConfigurationManager {
<#
.SYNOPSIS
        Returns the DSC Local Configuration Manager configuration for this machine or for a remote node.

.DESCRIPTION
        The Get-xDscLocalConfigurationManager cmdlet gets the current LCM configuration of the node, if configuration exists. Specify computers by using CIM sessions or the ComputerName parameter. If you do not specify a target computer, the cmdlet gets the configuration from the local computer.

.PARAMETER AsJob
        Runs the cmdlet as a background job. Use this parameter to run commands that take a long time to complete.
        The cmdlet immediately returns an object that represents the job and then displays the command prompt. You can continue to work in the session while the job completes. To manage the job, use the *-Job cmdlets. To get the job results, use the Receive-Job cmdlet.
        For more information about Windows PowerShell® background jobs, see about_Jobs.

.PARAMETER CimSession
        Runs the cmdlet in a remote session or on a remote computer. Enter a computer name or a session object, such as the output of a New-CimSession or Get-CimSession cmdlet. The default is the current session on the local computer.

.PARAMETER ComputerName
        Runs the cmdlet on a remote computer, forming a CIM session connection and then closing it after getting the configuration.

.PARAMETER UseSSL
        Runs the cmdlet on a remote computer connecting with SSL.

.PARAMETER Credemtial
        Uses these credentials to connect to the remote computer.

.PARAMETER ThrottleLimit
        Specifies the maximum number of concurrent operations that can be established to run the cmdlet. If this parameter is omitted or a value of 0 is entered, then Windows PowerShell® calculates an optimum throttle limit for the cmdlet based on the number of CIM cmdlets that are running on the computer. The throttle limit applies only to the current cmdlet, not to the session or to the computer.

.EXAMPLE
        PS C:\> Get-xDscLocalConfigurationManager
        This command gets the current configuration for the local computer.

.EXAMPLE
        PS C:\> Get-xDscLocalConfigurationManager -ComputerName DSCSVR01 -Credential (Get-Credential) -UseSSL
        This example gets the current configuration from computer DSCSVR01, connecting to it via SSL and the credentials supplied.

.INPUTS
.OUTPUTS
.LINK
        http://go.microsoft.com/fwlink/?LinkID=288760
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Alias('Session')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        ${CimSession},

        [int]
        ${ThrottleLimit},

        [switch]
        ${AsJob},

        [Parameter(ParameterSetName='ComputerName')]
        [ValidateNotNullOrEmpty()]
		[String]
		${ComputerName},

        [Parameter(ParameterSetName='ComputerName')]
        [PSCredential]
		${Credential},

        [Parameter(ParameterSetName='ComputerName')]
        [switch]
		${UseSSL}
		)

    begin {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            } # if

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-DscLocalConfigurationManager', [System.Management.Automation.CommandTypes]::Function)
			if ($ComputerName) {
				$cimSessionParameters = @{}
				[Void]$PSBoundParameters.Remove('ComputerName')
				if ($UseSSL) {
					[Void]$PSBoundParameters.Remove('UseSSL')
					$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
					$cimSessionParameters += @{SessionOption=$cimSessionOption}
				} # if
				if ($Credential) {
					[Void]$PSBoundParameters.Remove('Credential')
					$cimSessionParameters += @{Credential=$Credential}
				} # if
				Write-Verbose "Get-xDscLocalConfigurationManager: Connecting to $ComputerName"
				$cimSession = New-CimSession -ComputerName $ComputerName @CimSessionParameters
				Write-Verbose "Get-xDscLocalConfigurationManager: Calling Get-DscLocalConfigurationManager"
				$scriptCmd = {& $wrappedCmd @PSBoundParameters -CimSession $cimSession }
			} else {
				$scriptCmd = {& $wrappedCmd @PSBoundParameters }
			} # if
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        } # try
    } # begin

    process {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        } # try
    } # process

    end {
        try {
            $steppablePipeline.End()
			if ($ComputerName -and $cimSession) {
				Write-Verbose "Get-xDscLocalConfigurationManager: Disconnecting from $ComputerName"
				Remove-CimSession -CimSession $cimSession
			} # if
        } catch {
            throw
        } # try
    } # end
} # Function Get-xDscLocalConfigurationManager
##########################################################################################################################################


##########################################################################################################################################
# DSC Configurations for configuring DSC Pull Server and LCM
# These sections are now containined in separate files found in the .\Configurations folder.
# This is so that this module will load even if the configurations contain import-dscresource commands that import resources
# That aren't available on the local computer. For example if the computer being used has not yet had the DSC Resource Kit Installed.
##########################################################################################################################################
# Available Configuration Files
# -----------------------------
# Configuration Config_SetLCMPullMode
# Configuration Config_SetLCMPushMode
# Configuration Config_EnablePullServerHTTP
# Configuration Config_EnablePullServerSMB
##########################################################################################################################################

##########################################################################################################################################
# Exports
##########################################################################################################################################
Export-ModuleMember `
    -Function Invoke-DSCCheck,Publish-DSCPullResources,Install-DSCResourceKit,Start-DSCPullMode,Start-DSCPushMode,Enable-DSCPullServer,Set-DSCPullServerLogging,Get-xDSCConfiguration,Get-xDscLocalConfigurationManager,Update-DSCNodeConfiguration `
    -Variable DSCTools_Default*,DSCTools_PSVersion
##########################################################################################################################################
