##########################################################################################################################################
# Configuration Config_SetLCMPushMode
##########################################################################################################################################
Configuration Config_SetLCMPushMode {
    Param (
        [Parameter(
            Mandatory=$true
            )]
        [string]$NodeName,

		[ValidateSet('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')]
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
} # Configuration Config_SetLCMPushMode
##########################################################################################################################################