# Sample configuration for Node01-Node07
$ConfigurationData = @{
    AllNodes = @(
        @{NodeName = '*';PSDscAllowPlainTextPassword = $true};
        @{NodeName = 'NODE01';Role=@('Web')};
        @{NodeName = 'NODE02';Role=@('Web')};
        @{NodeName = 'NODE03';Role=@('Web')};
        @{NodeName = 'NODE04';Role=@('Web')};
        @{NodeName = 'NODE05';Role=@('Web')};
        @{NodeName = 'NODE06';Role=@('Web')};
        @{NodeName = 'NODE07';Role=@('Web')};
    );
} # $ConfigurationData

configuration Config_Roles
{
	Param (
        $Roles
    ) # Param

    WindowsFeature FileSharing
    {
        Ensure = If ('FS' -in $Roles) {'Present'} Else {'Absent'}
        Name = 'FS-FileServer'
    } 
    WindowsFeature Web
    {
        Ensure = If ('Web' -in $Roles) {'Present'} Else {'Absent'}
        Name = 'web-Server'
    } 
    WindowsFeature App
    {
        Ensure = If('App' -in $Roles) {'Present'} Else {'Absent'}
        Name = 'Application-Server'
    }
} # configuration RoleConfiguration

configuration Config_Test 
{
    Import-DscResource -Module xPendingReboot

    node $allnodes.NodeName
    {
        # Make sure we've not got any pending reboots waiting before installing roles
        xPendingReboot RebootBeforeRoleInstall
        {
            Name='BeforeRoleInstall'
        }

        # Install server roles as per the Node configuration
        Config_Roles MyServerRoles
        {
        	Roles = $Node.Role
    	} # RoleConfiguration MyServerRoles

        xPendingReboot RebootAfterRoleInstall
        {
            Name='AfterRoleInstall'
        }

        # Create a folder to share
        File ScriptsFolderCreate
        {
            Ensure = 'Present'
            DestinationPath = 'c:\windows\scripts'
            Type = 'Directory'
        } # File ScriptsFolderCreate

        # Create a readme file in the folder
        File ReadmeCreate
        {
            Ensure = 'Present'
            DestinationPath = 'c:\windows\scripts\readme.txt'
            Contents = 'This folder was created using DSC to contain command domain scripts.'
            Type = 'File'
            DependsOn = '[File]ScriptsFolderCreate'
            CheckSum = 'SHA-256'
        } # File ReadmeCreate
                      
        # Write a Completion Log Entry
        Log WriteCompleteLog
        {
            Message = "DSC Configration Test-Config has been applied to $Node"
            DependsOn = '[File]ReadmeCreate'
        } # Log WriteCompleteLog
    } # node $allnodes.NodeName
} # configuration Config_Test 

# Generate the MOF file(s)
Config_Test -ConfigurationData $ConfigurationData -OutputPath "$PSScriptRoot\Config_Test"
