##########################################################################################################################################
# Example functions
# They will set up an HTTPS pull server on the local machine and then configure one or multiple nodes to use this pull server.
##########################################################################################################################################
Function Example-DSCToolsMulti {
	# Configure where the pull server is and how it can be connected to.
    $Script:DSCTools_DefaultPullServerName = 'PLAGUE-PDC.PLAGUEHO.COM'
    $Script:DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
    $Script:DSCTools_DefaultResourcePath = "c:\program files\windowspowershell\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
    $Script:DSCTools_DefaultPullServerResourcePath = "e:\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
    $Script:DSCTools_DefaultPullServerConfigurationPath = "e:\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $Script:DSCTools_DefaultPullServerPhysicalPath = "e:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
    $Script:DSCTools_DefaultComplianceServerPhysicalPath = "e:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name='PLAGUE-PDC';CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8'} )

    # These are the nodes that we are going to set up Pull mode for
    $Nodes = @( `
	    @{Name='PLAGUE-MEMBER.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-MEMBER.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-RODC.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e2';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-RODC.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-SQL2014.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-SQL2014.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-PROXY.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-PROXY.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-SC2012.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e5';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-SC2012.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-SP2013.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e6';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-SP2013.PLAGUEHO.COM.MOF"} , `
	    @{Name='PLAGUE-IIS01.PLAGUEHO.COM';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-IIS01.PLAGUEHO.COM.MOF"} )

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    If ( -not (Test-Path -Path $Script:DSCTools_DefaultPullServerResourcePath -PathType Container )) {
		New-Item `
			-Path $Script:DSCTools_DefaultPullServerResourcePath `
			-ItemType Directory
	}
    If ( -not (Test-Path -Path $Script:DSCTools_DefaultPullServerConfigurationPath -PathType Container )) {
		New-Item `
			-Path $Script:DSCTools_DefaultPullServerConfigurationPath `
			-ItemType Directory
	}

    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit `
		-UseCache `
		-Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources `
		-Verbose
    # Install a DSC Pull Server
    Enable-DSCPullServer `
		-Nodes $PullServers `
		-Verbose

    # Set DSC Pull Server Logging Mode
    Set-DSCPullServerLogging `
		-Nodes $PullServers `
		-AnalyticLog $True `
		-OperationalLog $True `
		-Verbose

    # Check the pull server
    Get-xDscConfiguration `
		-Verbose
    Get-xDscLocalConfigurationManager `
		-Verbose

    # Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode `
		-Nodes $Nodes `
		-Verbose

    # Re-copy the node configuration files up to the pull server.
    Update-DSCNodeConfiguration `
		-Nodes $Nodes `
		-InvokeCheck `
		-Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-Nodes $Nodes `
		-Verbose

    # Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    Start-DSCPushMode `
		-Nodes $Nodes `
		-Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-Nodes $Nodes `
		-Verbose
} # Function Example-DSCToolsMulti
##########################################################################################################################################

##########################################################################################################################################
Function Example-DSCToolsSingle {
	$NodeName = 'PLAGUE-MEMBER.PLAGUEHO.COM'
	$NodeGuid = '115929a0-61e2-41fb-a9ad-0cdcd66fc2e1'

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    If ( -not (Test-Path -Path "e:\DSC\Resources\" -PathType Container )) {
		New-Item `
			-Path "e:\DSC\Resources\" `
			-ItemType Directory
	}
    If ( -not (Test-Path -Path "e:\DSC\Configuration\" -PathType Container )) {
		New-Item `
			-Path "e:\DSC\Configuration\" `
			-ItemType Directory
	}

	# Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit `
        -UseCache `
        -Verbose

	# Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources `
        -PullServerResourcePath "e:\DSC\Resources\" `
        -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer `
        -CertificateThumbprint '3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8' `
        -PullServerResourcePath "e:\DSC\Resources\" `
        -PullServerConfigurationPath "e:\DSC\Configuration\" `
        -PullServerPhysicalPath "e:\DSC\PSDSCPullServer\" `
        -ComplianceServerPhysicalPath "e:\DSC\PSDSCComplianceServer\" `
        -Verbose

    # Set DSC Pull Server Logging Mode
    Set-DSCPullServerLogging `
		-AnalyticLog $True `
		-OperationalLog $True `
		-Verbose

    # Check the pull server
    Get-xDscConfiguration `
        -Verbose
	Get-xDscLocalConfigurationManager `
		-Verbose
    
	# Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode `
		-ComputerName $NodeName `
		-Guid $NodeGuid `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
        -PullServerConfigurationPath "e:\DSC\Configuration\" `
        -PullServerURL 'https://PLAGUE-PDC.PLAGUEHO.COM:8080/PSDSCPullServer.svc' `
		-Verbose

    # Re-copy the node configuration files up to the pull server.
    Update-DSCNodeConfiguration `
		-ComputerName $NodeName `
		-Guid $NodeGuid `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
        -PullServerConfigurationPath "e:\DSC\Configuration\" `
		-InvokeCheck `
		-Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
	 	-ComputerName $NodeName `
	 	-Verbose

	# Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    Start-DSCPushMode `
	 	-ComputerName $NodeName `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
		-Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-ComputerName $NodeName `
		-Verbose
} # Function Example-DSCToolsSingle
##########################################################################################################################################

##########################################################################################################################################
Function Example-DSCToolsLoadModule {
	Get-Module DSCTools | Remove-Module
	Import-Module "$PSScriptRoot\..\DSCTools.psm1"
} # Function Example-DSCToolsLoadModule
##########################################################################################################################################

##########################################################################################################################################
Function Example-DSCCreateConfig {
	& "$PSScriptRoot\Configuration\Config_PlagueHO.ps1"
} # Function Example-DSCCreateConfig
##########################################################################################################################################
Example-DSCToolsLoadModule
Example-DSCCreateConfig
Example-DSCToolsSingle
Example-DSCToolsMulti
