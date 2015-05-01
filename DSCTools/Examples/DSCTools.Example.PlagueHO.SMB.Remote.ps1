##########################################################################################################################################
# Example functions
# They will set up an SMB pull server on the remote machine and then configure one or multiple nodes to use this pull server.
##########################################################################################################################################
Function Example-DSCToolsMulti {
	# Configure where the pull server is and how it can be connected to.
    $Script:DSCTools_DefaultPullServerName = 'PLAGUE-PDC.PLAGUEHO.COM'
    $Script:DSCTools_DefaultPullServerProtocol = 'SMB'  # Pull server has a valid trusted cert installed
    $Script:DSCTools_DefaultPullServerConfigurationPath = "\\$Script:DSCTools_DefaultPullServerName\e$\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $Credential = Get-Credential -Message "User Account to Install SMB Pull Server on $Script:DSCTools_DefaultPullServerName"

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name=$Script:DSCTools_DefaultPullServerName;CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8';Credential=$Credential;} )

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
    If ( -not (Test-Path -Path \\$Script:DSCTools_DefaultPullServerName\e$\DSC\Configuration\ -PathType Container )) {
        New-Item `
            -Path \\$Script:DSCTools_DefaultPullServerName\e$\DSC\Configuration\ `
            -ItemType Directory
    }

    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit `
        -UseCache `
        -Verbose
    Install-DSCResourceKit `
        -ModulePath "\\$Script:DSCTools_DefaultPullServerName\c$\program files\windowspowershell\modules\" `
        -UseCache `
        -Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources `
        -PullServerResourcePath "\\$Script:DSCTools_DefaultPullServerName\e$\DSC\Configuration\" `
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
    $PullServer = 'PLAGUE-PDC.PLAGUEHO.COM'
    $NodeName = 'PLAGUE-MEMBER.PLAGUEHO.COM'
    $NodeGuid = '115929a0-61e2-41fb-a9ad-0cdcd66fc2e1'
    $Credential = Get-Credential -Message "User Account to Install SMB Pull Server on $PullServer"

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    If ( -not (Test-Path -Path \\$PullServer\e$\DSC\Configuration\ -PathType Container )) {
        New-Item `
            -Path \\$PullServer\e$\DSC\Configuration\ `
            -ItemType Directory
    }

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
        -PullServerResourcePath "\\$PullServer\e$\DSC\Configuration\" `
        -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer `
		-ComputerName $PullServer `
        -Credential $Credential `
		-PullServerProtocol 'SMB' `
        -PullServerConfigurationPath "e:\DSC\Configuration\" `
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
		-ComputerName $NodeName `
		-Guid $NodeGuid `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
        -PullServerConfigurationPath "\\$($PullServer)\e$\DSC\Configuration\" `
        -PullServerURL "\\$($PullServer)\($Script:DSCTools_DefaultPullServerEndpointName)\" `
		-Verbose

    # Re-copy the node configuration files up to the pull server.
    Update-DSCNodeConfiguration `
        -ComputerName $NodeName `
		-Guid $NodeGuid `
		-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
        -PullServerConfigurationPath $ConfigPath `
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
#Example-DSCToolsSingle
Example-DSCToolsMulti
