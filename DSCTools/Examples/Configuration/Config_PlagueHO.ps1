# Set up the Configuration data obejct we'll pass to our config
$ConfigurationData = @{
    AllNodes = @(
        @{NodeName = '*';PSDscAllowPlainTextPassword = $true};
        @{NodeName = 'PLAGUE-MEMBER.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-RODC.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-IIS01.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-SQL2014.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-SC2012.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-SP2013.PLAGUEHO.COM';Role=@('Web')};
        @{NodeName = 'PLAGUE-PROXY.PLAGUEHO.COM';Role=@('Web')};
    );
} # $ConfigurationData

configuration Config_PlagueHO
{
	Import-DSCResource -ModuleName 'PSDesiredStateConfiguration'

    node $allnodes.NodeName
    {

        # Ensure Windows PowerShell Modules folder exists
        File ModulesFolderCreate
        {
            Ensure = 'Present'
            DestinationPath = 'c:\program files\windowspowershell\modules'
            Type = 'Directory'
        } # File ModulesFolderCreate

        # Create a readme file in the folder
        File ReadmeCreate
        {
            Ensure = 'Present'
            DestinationPath = 'c:\program files\windowspowershell\modules\dscreadme.txt'
            Contents = 'Windows PowerShell Modules have been installed by DSC.'
            Type = 'File'
            CheckSum = 'SHA-256'
            DependsOn = '[File]ModulesFolderCreate'
        } # File ReadmeCreate
                      
		Archive PSWindowsUpdateModule
		{
			Destination = 'c:\program files\windowspowershell\modules\'
			Path = '\\plague-pdc.plagueho.com\public\PSModules\PSWindowsUpdate.zip'
			Ensure = 'Present'
			Force = $True
			CheckSum = 'SHA-256'
			Validate = $True
            DependsOn = '[File]ModulesFolderCreate'
		}

		Archive CoreFigModule
		{
			Destination = 'c:\program files\windowspowershell\modules\'
			Path = '\\plague-pdc.plagueho.com\public\PSModules\CoreFig.zip'
			Ensure = 'Present'
			Force = $True
			CheckSum = 'SHA-256'
			Validate = $True
            DependsOn = '[File]ModulesFolderCreate'
		}

        # Write a Completion Log Entry
        Log WriteCompleteLog
        {
            Message = "DSC Configration Config_PlagueHO has been applied to $Node"
            DependsOn = '[File]ReadmeCreate'
        } # Log WriteCompleteLog
    } # node $allnodes.NodeName
} # configuration Config_PlagueHO 

# Generate the MOF file(s)
Config_PlagueHO -ConfigurationData $ConfigurationData -OutputPath "$PSScriptRoot\Config_PlagueHO"
