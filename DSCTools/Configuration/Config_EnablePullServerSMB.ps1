##########################################################################################################################################
# Configuration Config_EnablePullServerSMB
##########################################################################################################################################
Configuration Config_EnablePullServerSMB {
    Param (
        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeName,

        [ValidateNotNullOrEmpty()]
        [String]$PullServerEndpointName = "PSDSCPullServer",

        [ValidateNotNullOrEmpty()]
        [String]$PullServerConfigurationPath = "$($env:PROGRAMFILES)\WindowsPowerShell\DscService\Configuration"
    ) # Param

	Import-DscResource -ModuleName xSmbShare,xPSDesiredStateConfiguration,PSDesiredStateConfiguration

	Node $NodeName {
		WindowsFeature FileServer
		{
		  Ensure = "Present"
		  Name  = "FS-FileServer"
		}

		File ConfigurationFolderCreate
        {
            Ensure = "Present"
            DestinationPath = $PullServerConfigurationPath
            Type = "Directory"
			DependsOn = "[WindowsFeature]FileServer"
        } # File ConfigurationFolderCreate

		xSmbShare PullServerShare
		{
			Ensure = "Present"  
			Name = $PullServerEndpointName
			Path = $PullServerConfigurationPath
			Description = "DSC Pull Server Configuration Share"
			DependsOn = "[File]ConfigurationFolderCreate"
		}
	} # Node $NodeName
} # Configuration Config_EnablePullServerSMB
##########################################################################################################################################
