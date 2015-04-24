##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-One {
    # Configure where the pull server is and how it can be connected to.
    $DSCTools_DefaultPullServerName = 'PLAGUE-PDC'
    $DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
    $DSCTools_DefaultResourcePath = "c:\program files\windowspowershel\DscService\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
    $DSCTools_DefaultPullServerResourcePath = "\\$DSCTools_DefaultPullServerName\c$\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
    $DSCTools_DefaultPullServerConfigurationPath = "\\$DSCTools_DefaultPullServerName\c$\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $DSCTools_DefaultNodeConfigurationSourceFolder = "$HOME\Documents\WindowsPowerShell\Configuration\" # Where to find source configuration files.
    $DSCTools_DefaultPullServerPhysicalPath = "c:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
    $DSCTools_DefaultComplianceServerPhysicalPath = "c:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.
    $Credential = Get-Credential

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name=$DSCTools_DefaultPullServerName;CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8';Credential=$Credential;} )

    # These are the nodes that we are going to set up Pull mode for
    $Nodes = @( `
	    @{Name='PLAGUE-MEMBER';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-MEMBER.MOF'} , `
	    @{Name='PLAGUE-RODC';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-RODC.MOF'} , `
	    @{Name='PLAGUE-SQL2014';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-SQL2014.MOF'} , `
	    @{Name='PLAGUE-PROXY';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-PROXY.MOF'} , `
	    @{Name='PLAGUE-SC2012';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e9';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-SC2012.MOF'} , `
	    @{Name='PLAGUE-SP2013';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e8';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-SP2013.MOF'} , `
	    @{Name='PLAGUE-IIS01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e8';RebootNodeIfNeeded=$true;MofFile='c:\DSC\Configuration\PLAGUE-IIS01.MOF'} )

    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit -UseCache -Verbose
    Install-DSCResourceKit -ModulePath "\\$DSCTools_DefaultPullServerName\c$\program files\windowspowershell\modules\" -UseCache -Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer -Nodes $PullServers -Verbose

    # Check the pull server
    Get-DscConfigurationRemote -ComputerName PLAGUE-PDC -UseSSL -Credential ($Credential) -Verbose

    # Set all the nodes to pull mode and copy the config files over to the pull server.
    #Start-DSCPullMode -Nodes $Nodes -Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    #Invoke-DSCPull -ComputerName PLAGUE-MEMBER -Verbose
    #Invoke-DSCPull -Nodes @(@{Name='PLAGUE-MEMBER'}) -Verbose

    # Set all the nodes to back to push mode if we don't want to use Pul mode any more.
    #Start-DSCPushMode -Nodes $Nodes
} # Function Test-One
##########################################################################################################################################

##########################################################################################################################################
Function Test-Two {
    $PullServer = 'PLAGUE-PDC'
    $Credential = Get-Credential
    Install-DSCResourceKit `
        -UseCache `
        -Verbose
    Install-DSCResourceKit `
        -ModulePath "\\$PullServer\c$\program files\windowspowershell\modules\" `
        -UseCache `
        -Verbose
    Publish-DSCPullResources `
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -Verbose
    Enable-DSCPullServer `
        -ComputerName PLAGUE-PDC `
        -CertificateThumbprint '3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8' `
        -Credential ($Credential) `
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -PullServerConfigurationPath "\\$PullServer\c$\DSC\Configuration\" `
        -PullServerPhysicalPath "c:\DSC\PSDSCPullServer\" `
        -ComplianceServerPhysicalPath "c:\DSC\PSDSCComplianceServer\" `
        -Verbose
    Get-DscConfigurationRemote `
        -ComputerName PLAGUE-PDC `
        -UseSSL `
        -Credential ($Credential) `
        -Verbose

} # Function Test-Two
##########################################################################################################################################

##########################################################################################################################################
Get-Module DSCTools | Remove-Module
Import-Module "$PSScriptRoot\DSCTools.psm1"
#Test-One
Test-Two
