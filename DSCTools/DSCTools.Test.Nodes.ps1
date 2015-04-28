##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-DSCToolsMulti {
	# Configure where the pull server is and how it can be connected to.
    $Script:DSCTools_DefaultPullServerName = 'DSCPULLSVR01'
    $Script:DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
    $Script:DSCTools_DefaultResourcePath = "c:\program files\windowspowershell\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
    $Script:DSCTools_DefaultPullServerResourcePath = "\\$Script:DSCTools_DefaultPullServerName\c$\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
    $Script:DSCTools_DefaultPullServerConfigurationPath = "\\$Script:DSCTools_DefaultPullServerName\c$\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $Script:DSCTools_DefaultPullServerPhysicalPath = "c:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
    $Script:DSCTools_DefaultComplianceServerPhysicalPath = "c:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.
    $Credential = Get-Credential

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name=$Script:DSCTools_DefaultPullServerName;CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8';Credential=$Credential;} )

    # These are the nodes that we are going to set up Pull mode for
    $Nodes = @( `
	    @{Name='NODE01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE01.MOF"} , `
	    @{Name='NODE02';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e2';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE02.MOF"} , `
	    @{Name='NODE03';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE03.MOF"} , `
	    @{Name='NODE04';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE04.MOF"} , `
	    @{Name='NODE05';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e5';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE05.MOF"} , `
	    @{Name='NODE06';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e6';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE06.MOF"} , `
	    @{Name='NODE07';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE07.MOF"} )

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    New-Item -Path \\$Script:DSCTools_DefaultPullServerName\c$\DSC\ -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerResourcePath -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerConfigurationPath -ItemType Directory

    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit -UseCache -Verbose
    Install-DSCResourceKit -ModulePath "\\$Script:DSCTools_DefaultPullServerName\c$\program files\windowspowershell\modules\" -UseCache -Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer -Nodes $PullServers -Verbose

    # Set DSC Pull Server Logging Mode
    Set-DSCPullServerLogging -Nodes $PullServers -AnalyticLog $True -OperationalLog $True -Verbose

    # Check the pull server
    Get-xDscConfiguration -ComputerName $Script:DSCTools_DefaultPullServerName -UseSSL -Credential ($Credential) -Verbose
    Get-xDscLocalConfigurationManager -ComputerName $Script:DSCTools_DefaultPullServerName -UseSSL -Credential ($Credential) -Verbose

    # Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode -Nodes $Nodes -Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    # Invoke-DSCCheck -Nodes $Nodes -Verbose

    # Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    # Start-DSCPushMode -Nodes $Nodes -Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    # Invoke-DSCCheck -Nodes $Nodes -Verbose

} # Function Test-DSCToolsMulti
##########################################################################################################################################

##########################################################################################################################################
Function Test-DSCToolsSingle {
    $PullServer = 'DSCPULLSVR02'
    $Credential = Get-Credential

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    New-Item -Path "\\$PullServer\c$\DSC\" -ItemType Directory
    New-Item -Path "\\$PullServer\c$\DSC\Resources\" -ItemType Directory
    New-Item -Path "\\$PullServer\c$\DSC\Configuration\" -ItemType Directory

	# Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit `
        -UseCache `
        -Verbose
    Install-DSCResourceKit `
        -ModulePath "\\$PullServer\c$\program files\windowspowershell\modules\" `
        -UseCache `
        -Verbose

	# Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources `
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer `
        -ComputerName $PullServer `
        -CertificateThumbprint '3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8' `
        -Credential ($Credential) `
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -PullServerConfigurationPath "\\$PullServer\c$\DSC\Configuration\" `
        -PullServerPhysicalPath "c:\DSC\PSDSCPullServer\" `
        -ComplianceServerPhysicalPath "c:\DSC\PSDSCComplianceServer\" `
        -Verbose

    # Set DSC Pull Server Logging Mode
   Set-DSCPullServerLogging `
		-ComputerName $PullServer `
		-AnalyticLog $True `
		-OperationalLog $True `
		-Verbose

    # Check the pull server
    Get-xDscConfiguration `
        -ComputerName $PullServer `
        -UseSSL `
        -Credential ($Credential) `
        -Verbose
    Get-xDscLocalConfigurationManager `
        -ComputerName $PullServer `
        -UseSSL `
        -Credential ($Credential) `
        -Verbose
    
	# Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode `
		-ComputerName 'NODE01' `
		-Guid '115929a0-61e2-41fb-a9ad-0cdcd66fc2e7' `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_Test\PLAGUE-MEMBER.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
        -PullServerConfigurationPath "\\$($PullServer)\c$\DSC\Configuration\" `
        -PullServerURL "https://$($PullServer):8080/$($Script:DSCTools_DefaultPullServerPath)" `
		-Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    # Invoke-DSCCheck `
	# 	-ComputerName NODE01 `
	# 	-Verbose

	# Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    # Start-DSCPushMode `
	# 	-ComputerName NODE01 `
	#	-RebootIfNeeded `
	#	-MofFile "$PSScriptRoot\Configuration\Config_Test\PLAGUE-MEMBER.MOF" `
	#	-ConfigurationMode 'ApplyAndAutoCorrect' `
	#	-Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    # Invoke-DSCCheck `
	#	-ComputerName NODE01 `
	#	-Verbose

} # Function Test-DSCToolsSingle
##########################################################################################################################################

##########################################################################################################################################
Function Test-DSCToolsLoadModule {
	Get-Module DSCTools | Remove-Module
	Import-Module "$PSScriptRoot\DSCTools.psm1"
} # Function Test-DSCToolsLoadModule
##########################################################################################################################################

##########################################################################################################################################
Function Test-DSCCreateTestConfig {
	& "$PSScriptRoot\Configuration\Config_Test.ps1"
} # Function Test-DSCCreateTestConfig
##########################################################################################################################################
Test-DSCToolsLoadModule
Test-DSCCreateTestConfig
#Test-DSCToolsSingle
#Test-DSCToolsMulti
