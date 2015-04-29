##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-DSCToolsMulti {
	# Configure where the pull server is and how it can be connected to.
    $Script:DSCTools_DefaultPullServerName = 'PLAGUE-PDC.PLAGUEHO.COM'
    $Script:DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
    $Script:DSCTools_DefaultResourcePath = "c:\program files\windowspowershell\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
    $Script:DSCTools_DefaultPullServerResourcePath = "\\$Script:DSCTools_DefaultPullServerName\e$\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
    $Script:DSCTools_DefaultPullServerConfigurationPath = "\\$Script:DSCTools_DefaultPullServerName\e$\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $Script:DSCTools_DefaultPullServerPhysicalPath = "e:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
    $Script:DSCTools_DefaultComplianceServerPhysicalPath = "e:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name=$Script:DSCTools_DefaultPullServerName;CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8'} )

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
    New-Item -Path \\$Script:DSCTools_DefaultPullServerName\e$\DSC\ -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerResourcePath -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerConfigurationPath -ItemType Directory

    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit -UseCache -Verbose
    Install-DSCResourceKit -ModulePath "\\$Script:DSCTools_DefaultPullServerName\c$\program files\windowspowershell\modules\" -UseCache -Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer -Nodes $PullServers -Verbose

<#
    # Set DSC Pull Server Logging Mode
    Set-DSCPullServerLogging -Nodes $PullServers -AnalyticLog $True -OperationalLog $True -Verbose

    # Check the pull server
    Get-xDscConfiguration -Verbose
    Get-xDscLocalConfigurationManager -Verbose

    # Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode -Nodes $Nodes -Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck -Nodes $Nodes -Verbose

    # Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    Start-DSCPushMode -Nodes $Nodes -Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck -Nodes $Nodes -Verbose
#>

} # Function Test-DSCToolsMulti
##########################################################################################################################################

##########################################################################################################################################
Function Test-DSCToolsSingle {
    $PullServer = 'PLAGUE-PDC.PLAGUEHO.COM'

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    New-Item -Path "\\$PullServer\e$\DSC\" -ItemType Directory
    New-Item -Path "\\$PullServer\e$\DSC\Resources\" -ItemType Directory
    New-Item -Path "\\$PullServer\e$\DSC\Configuration\" -ItemType Directory

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
        -PullServerResourcePath "\\$PullServer\e$\DSC\Resources\" `
        -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer `
        -CertificateThumbprint '3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8' `
        -PullServerResourcePath "\\$PullServer\e$\DSC\Resources\" `
        -PullServerConfigurationPath "\\$PullServer\e$\DSC\Configuration\" `
        -PullServerPhysicalPath "e:\DSC\PSDSCPullServer\" `
        -ComplianceServerPhysicalPath "e:\DSC\PSDSCComplianceServer\" `
        -Verbose

    # Set DSC Pull Server Logging Mode
    Set-DSCPullServerLogging `
		-ComputerName $PullServer `
		-AnalyticLog $True `
		-OperationalLog $True `
		-Verbose

<#
    # Check the pull server
    Get-xDscConfiguration `
        -Verbose
	Get-xDscLocalConfigurationManager `
		-Verbose
    
	# Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode `
		-ComputerName 'PLAGUE-MEMBER.PLAGUEHO.COM' `
		-Guid '115929a0-61e2-41fb-a9ad-0cdcd66fc2e7' `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-MEMBER.PLAGUEHO.COM.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
        -PullServerConfigurationPath "\\$($PullServer)\e$\DSC\Configuration\" `
        -PullServerURL "https://$($PullServer):8080/$($Script:DSCTools_DefaultPullServerPath)" `
		-Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
	 	-ComputerName PLAGUE-MEMBER.PLAGUEHO.COM `
	 	-Verbose

	# Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    Start-DSCPushMode `
	 	-ComputerName PLAGUE-MEMBER.PLAGUEHO.COM `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\PLAGUE-MEMBER.PLAGUEHO.COM.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
		-Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-ComputerName PLAGUE-MEMBER.PLAGUEHO.COM `
		-Verbose
#>

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
	& "$PSScriptRoot\Configuration\Config_PlagueHO.ps1"
} # Function Test-DSCCreateTestConfig
##########################################################################################################################################
Test-DSCToolsLoadModule
Test-DSCCreateTestConfig
Test-DSCToolsSingle
#Test-DSCToolsMulti
