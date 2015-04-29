##########################################################################################################################################
# Configuration Config_SetLCMPullMode
##########################################################################################################################################
Configuration Config_SetLCMPullMode {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$NodeName,

        [Parameter(Mandatory=$true)]
        [string]$NodeGuid,

		[ValidateSet('ApplyAndAutoCorrect','ApplyAndMonitor','ApplyOnly')]
        [string]$ConfigurationMode = 'ApplyAndAutoCorrect',

        [ValidateNotNullOrEmpty()]
        [boolean]$RebootNodeIfNeeded = $false,

        [Parameter(Mandatory=$true)]
        [string]$PullServerURL,

        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential,

        [ValidateNotNullOrEmpty()]
        [String]$CertificateId
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
            RefreshFrequencyMins = 30
			Credential = $Credential
			CertificateId = $CertificateId
		} # LocalConfigurationManager
	} # Node $NodeName
} # Configuration Config_SetLCMPullMode
##########################################################################################################################################
