##########################################################################################################################################
# Configuration Config_EnablePullServerHTTP
##########################################################################################################################################
Configuration Config_EnablePullServerHTTP {
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

	Import-DscResource –ModuleName xPSDesiredStateConfiguration,PSDesiredStateConfiguration

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
			IsComplianceServer = $false
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
			DependsOn = ("[WindowsFeature]DSCServiceFeature","[xDSCWebService]PSDSCPullServer")
		}
	} # Node $NodeName
} # Configuration Config_EnablePullServerHTTP
##########################################################################################################################################
