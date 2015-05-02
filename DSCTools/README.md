Powershell
==========

## DSCTools
This module provides helper functions for setting up and using Desired State Configration.

### Overview
Anyone who has attempted to install and use DSC and DSC pull servers knows that it can be a bit of a complicated process. This module attempts to simplify the process by putting all the pieces together in simple functions.

### Version Info
<pre>
1.7   2015-05-02   Daniel Scott-Raynsford       Added SkipConnectionCheck parameter to some cmdlets to prevent checking of connection
                                                prior to perfoming required function.
1.6   2015-05-01   Daniel Scott-Raynsford       Added function Update-DSCNodeConfiguration
1.5   2015-05-01   Daniel Scott-Raynsford       Improved Handling of calling functions with Localhost.
                                                Checks to see if remote computers accessible before calling functions.
1.4   2015-04-30   Daniel Scott-Raynsford       Misc fixes to DSCTools.psm1
											    Renamed DSCTools.selftest.* files to DSCTools.Example files and moved to Examples folder
1.3   2015-04-28   Daniel Scott-Raynsford       Added DSCTools.Package.ps1 Script
												Added Get-xDSCLocalConfigurationManager CmdLet
												Added Set-DSCPullServerLogging Cmdlet
1.2   2015-04-23   Daniel Scott-Raynsford       Added Install-DSCResourceKit CmdLet
												Added Enable-DSCPullServer CmdLet
1.1   2014-11-22   Daniel Scott-Raynsford       Alowed Invoke-DSCPull to use a Nodes param
												Added test functions
												Added Configuration ConfigureLCMPushMode
												Added Function Start-DSCPushMode
1.0   2014-10-23   Daniel Scott-Raynsford       Initial Version
</pre>

### Functions
This module contains functions to try and make setting up and using Desired State Configuration easier.

I noticed while attempting to set up my first DSC Pull server that it was a resonably intricate process with lots of room for mistakes.
There were many manual steps that could all go wrong. So I attempted to try and automate some of the steps involved with setting up
Pull servers and installing resource files onto them as well as configuring the LCM on the nodes being controlled.

The intent of this module is that it should allow setting up a full DSC pull system (the fiddly part) with only a few lines of code,
freeing up time to actually write the node configuration scripts (the fun part).

The functions in this module are:

- Invoke-DSCCheck - Forces the LCM on the specified nodes to trigger a DSC check.
- Publish-DSCPullResources - Publishes DSC Resources to a DSC pull server.
- Install-DSCResourceKit - Downloads and installs the DSC Resource Kit. It can also optionally publish the Resources to a pull server.
- Enable-DSCPullServer - Installs and configures one or more servers as a DSC Pull Servers.
- Set-DSCPullServerLogging - Enable/Disable DSC pull server logging on one or more DSC Pull Servers.
- Start-DSCPullMode - Configures one or mode nodes for Pull Mode.
- Start-DSCPushMode - Configures one or mode nodes for Push Mode.
- Get-xDscConfiguration - Returns the DSC configuration for this machine or for a remote node.
- Get-xDscLocalConfigurationManager - Returns the DSC Local Configuration Manager configuration for this machine or for a remote node.

#### Function Invoke-DSCCheck
Forces the LCM on the specified nodes to trigger a DSC check.

For example:
```powershell
Invoke-DSCCheck -ComputerName SERVER01,SERVER02,SERVER03
```

See:
```powershell
Get-Help -Name Invoke-DSCCheck -Full
```
For more information.


#### Function Publish-DSCPullResources
Publishes DSC Resources to a DSC pull server.

For example:
```powershell
Publish-DSCPullResources -ModulePath 'c:\program files\windowspowershell\modules\all resources\'
```

See:
```powershell
Get-Help -Name Publish-DSCPullResources -Full
```
For more information.


#### Function Install-DSCResourceKit
Downloads and installs the DSC Resource Kit. It can also optionally publish the Resources to a pull server.

For example:
```powershell
Install-DSCResourceKit -Publish
```

See:
```powershell
Get-Help -Name Install-DSCResourceKit -Full
```
For more information.


#### Function Enable-DSCPullServer
Installs and configures one or more servers as a DSC Pull Servers.

For example:
```powershell
Enable-DSCPullServer -ComputerName DSCPULLSRV01
```

See:
```powershell
Get-Help -Name Enable-DSCPullServer -Full
```
For more information.


#### Function Set-DSCPullServerLogging

Enable/Disable DSC pull server logging on one or more DSC Pull Servers.

For example:
```powershell
Set-DSCPullServerLogging -ComputerName DSCPULLSRV01 -AnalyticLog $True -OperationalLog $True
```

See:
```powershell
Get-Help -Name Set-DSCPullServerLogging -Full
```
For more information.


#### Function Update-DSCNodeConfiguration
Updates the configuration for one or more nodes in a Pull Server.

For example:
```powershell
Update-DSCNodeConfiguration -Nodes @(@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'})
```

See:
```powershell
Get-Help -Name Update-DSCNodeConfiguration -Full
```
For more information.


#### Function Start-DSCPullMode
Configures one or mode nodes for Pull Mode.

For example:
```powershell
Start-DSCPullMode `
-Nodes @( `
@{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7'}, `
@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'} `
)
```

See:
```powershell
Get-Help -Name Start-DSCPullMode -Full
```
For more information.


#### Function Start-DSCPushMode
Configures one or mode nodes for Push Mode.

For example:
```powershell
Start-DSCPushMode `
-Nodes @( `
@{Name='SERVER01'}, `
@{Name='SERVER02';RebootNodeIfNeeded=$true;MofFile='c:\users\Administrtor\Documents\WindowsPowerShell\DSCConfig\SERVER02.MOF'} `
)
```

See:
```powershell
Get-Help -Name Start-DSCPushMode -Full
```
For more information.


#### Function Get-xDscConfiguration
Returns the DSC configuration for this machine or for a remote node.

For example:
```powershell
Get-xDscConfiguration -ComputerName DSCSVR01 -Credential (Get-Credential) -UseSSL
```

See:
```powershell
Get-Help -Name Get-xDscConfiguration -Full
```
For more information.


#### Function Get-xDscLocalConfigurationManager
Returns the DSC Local Configuration Manager configuration for this machine or for a remote node.

For example:
```powershell
Get-xDscLocalConfigurationManager -ComputerName DSCSVR01 -Credential (Get-Credential) -UseSSL
```

See:
```powershell
Get-Help -Name Get-xDscLocalConfigurationManager -Full
```
For more information.


### Minimum requirements

- PowerShell 4.0


### License and Copyright

Copyright 2014 Daniel Scott-Raynsford

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


### Installing DSCTools
1. Unzip the archive containing the DSCTools module into the one of the PowerShell Modules folders.
   E.g. c:\program files\windowspowershell\modules
2. This will create a folder called DSCTools containing all the files required for this module.
3. In PowerShell execute:
```powershell
Import-Module DSCTools
```


### Default Values
The DSCTools module contains some script variables that can be changed to allow the default properties
of the module to be changed. This helps reduce the number of parameters that need to be passed to each
DSCTools function if you want to configure your DSC system with parameters other than the default.

```powershell
# This is the name of the pull server that will be used if no pull server parameter is passed to functions
# Setting this value is a lazy way of using a different pull server (rather than passing the pullserver parameter)
# to each function that needs it.
[String]$Script:DSCTools_DefaultPullServerName = 'localhost'

# This is the protocol that will be used by the DSC machines to connect to the pull server. This must be HTTP or HTTPS.
# If HTTPS is used then the HTTPS certificate on your Pull server must be trusted by all DSC Machines.
# This can also be set to SMB to use a pull server SMB share.
[String]$Script:DSCTools_DefaultPullServerProtocol = 'HTTP'

# This is the default endpoint name a Pull server will be created as when it is installed by Enable-DSCPullServer.
[String]$Script:DSCTools_DefaultPullServerEndpointName = 'PSDSCPullServer'

# This is the default endpoint name a Compliance server will be created as when it is installed by Enable-DSCPullServer.
[String]$Script:DSCTools_DefaultComplianceServerEndpointName = 'PSDSCComplianceServer'

# This is the location of the powershell modules folder where all the resources can be found that will be
# Installed into the pull server by the Publish-DSCPullResources function.
[String]$Script:DSCTools_DefaultResourcePath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\Modules\All Resources\"

# This is the default folder on your pull server where any resources will get copied to by the
# Publish-DSCPullResources function. This can be a UNC path to a network share if required.
# This path may also be used by the Enable-DSCPullServer cmdlet as well.
[String]$Script:DSCTools_DefaultPullServerResourcePath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Modules\"

# This is the default folder where a DSC Pull Server will try and locate node configuraiton files.
# This should usually be a local path accessebile by the DSC Pull Server.
[String]$Script:DSCTools_DefaultPullServerConfigurationPath = "$($ENV:PROGRAMFILES)\WindowsPowerShell\DscService\Configuration\"

# This is the path and svc name component of the uRL used to access the Pull server.
[String]$Script:DSCTools_DefaultPullServerPath = 'PSDSCPullServer.svc'

# This is the default folder where a new DSC Pull Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$Script:DSCTools_DefaultPullServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCPullServer\"

# This is the port the Pull server is running on.
[Int]$Script:DSCTools_DefaultPullServerPort = 8080

# This is the default folder where a new DSC Compliance Server IIS Web Site will be installed.
# This should always be a folder on the local DSC Pull Server.
[String]$Script:DSCTools_DefaultComplianceServerPhysicalPath = "$($ENV:SystemDrive)\inetpub\wwwroot\PSDSCComplianceServer\"

# This is the port the Compliance server is running on.
[Int]$Script:DSCTools_DefaultComplianceServerPort = 8090

# This is the URL to download the current version of the DSC Resource Kit.
# It may change when newer versions of the resource kit are released.
[String]$Script:DSCTools_ResourceKitURL = "https://gallery.technet.microsoft.com/scriptcenter/DSC-Resource-Kit-All-c449312d/file/131371/4/DSC%20Resource%20Kit%20Wave%2010%2004012015.zip"

# This is the default folder the functions Start-DSCPull, Start-DSCPush and Update-DSCNodeConfiguration functions will look for
# MOF files for node configuration. In future they may also look for PS1 files that can be converted to MOF files.
[String]$Script:DSCTools_DefaultNodeConfigSourceFolder = "$HOME\Documents\"

# This is the version of PowerShell that the Configuration files should be built to use.
# This is for future use when WMF 5.0 is available the LCM configuration files can be
# written in a more elegant fashion. Currently this should always be set to 4.0
[Float]$Script:DSCTools_PSVersion = 4.0
```

### Example Usage

#### Quick Install: DSC HTTP Pull Server

This example should be run under a user account that has administrator privileges to the Pull Server. This should be run directly on the Pull Server. This example will perform the following operations:

1. Download and install the DSC Resource Kit onto this computer.
2. Publish the DSC Resources from the DSC resource kit onto this computer.
3. Install this computer as a DSC Pull Server.
```powershell
# Download the DSC Resource Kit and install it to the local DSC Pull Server
Install-DSCResourceKit -UseCache

# Copy all the resources up to the local DSC Pull Server (zipped and with a checksum file).
Publish-DSCPullResources

# Install a DSC Pull Server to the local machine
Enable-DSCPullServer
```

#### Quick Install: Configure Node to use Pull Server

This example should be run under a user account that has administrator privileges to the Pull Server. This should be run directly on the Pull Server. This example will perform the following operations:

1. Copy the configuration MOF file to the Pull Server.
2. Generate a checksum file for the configuration.
3. Configure the LCM on the node to pull it's configuration from the Pull Server.
4. Trigger the node to immediately pull it's DSC configuration from the Pull Server (rather than wait 30 minutes).
```powershell
# Set up the node NODE01 to pull from the pull server on machine MYDSCSERVER.
# The MOF file for this node will be looked for in:
# $Home\Documents\NODE01.MOF
# This can be configured.
Start-DSCPullMode `
-ComputerName 'NODE01'
-PullServerURL 'http://MYDSCSERVER:8080/PSDSCPullServer.svc'

# Force the node to pull its configuration from the Pull Server
Invoke-DSCCheck -ComputerName NODE01
```

#### Full Install: DSC HTTPS Pull Server with a single Node
This example should be run under a user account that has administrator privileges to the Pull Server. This should not be run directly on the Pull Server without removing the ComputerName and Credential parameters. This example will perform the following operations:

1. Create a basic folder structure on the DSCPULLSVR01 Pull Server where the DSC resources and configuratins will be stored.
2. Download and install the DSC Resource Kit onto this computer and the DSCPULLSVR01 Pull Server.
3. Publish the DSC Resources from the DSC resource kit onto the DSCPULLSVR01 Pull Server.
4. Install DSCPULLSVR01 as a DSC Pull Server.
5. Pull the LCM DSC Configuration from the DSCPULLSVR01 Pull Server to confirm it has been configured as a Pull Server.
6. Set NODE01 node to use the DSCPULLSVR01 Pull Server and load the configuration files for it onto the DSCPULLSVR01 Pull Server.
7. Force NODE01 node to pull DSC configuration from the DSCPULLSVR01 Pull Server (commended out).
8. Set NODE01 to use Push Mode and apply the DSC configration files (commented out).
9. Force NODE01 to apply the loaded Push Mode DSC configuration files (commented out).
```powershell
$NodeName = 'NODE01'
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
-MofFile "$PSScriptRoot\Configuration\Config_StandardSvr\$NodeName.MOF" `
-ConfigurationMode 'ApplyAndAutoCorrect' `
-PullServerConfigurationPath "e:\DSC\Configuration\" `
-PullServerURL 'https://DSCPULLSVR01:8080/PSDSCPullServer.svc' `
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
# Start-DSCPushMode `
# 	-ComputerName $NodeName `
#	-RebootIfNeeded `
#	-MofFile "$PSScriptRoot\Configuration\Config_PlagueHO\$NodeName.MOF" `
#	-ConfigurationMode 'ApplyAndAutoCorrect' `
#	-Verbose

# Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
# Invoke-DSCCheck `
#	-ComputerName $NodeName `
#	-Verbose
```



### Example Usage - Installing a Pull Server with multiple Nodes
This example should be run under a user account that has administrator privileges to the Pull Server. This should not be run directly on the Pull Server without removing the ComputerName and Credential parameters. This example will perform the following operations:

1. Create a basic folder structure on the DSCPULLSVR01 Pull Server where the DSC resources and configuratins will be stored.
2. Download and install the DSC Resource Kit onto this computer and the DSCPULLSVR01 Pull Server.
3. Publish the DSC Resources from the DSC resource kit onto the DSCPULLSVR01 Pull Server.
4. Install DSCPULLSVR01 as a DSC Pull Server.
5. Pull the LCM DSC Configuration from the DSCPULLSVR01 Pull Server to confirm it has been configured as a Pull Server.
6. Set the Nodes defined in the Nodes array to use the DSC Pull Server and load the configuration files for them onto the Pull Server.
7. Force the Nodes to pull DSC configuration from the Pull Server (commented out).
8. Set the Nodes defined in the Nodes array to use Push Mode and apply the DSC configration files (commented out).
9. Force the Nodes to apply the loaded Push Mode DSC configuration files (commented out).
```powershell
# Configure where the pull server is and how it can be connected to.
$Script:DSCTools_DefaultPullServerName = 'DSCPULLSVR01'
$Script:DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
$Script:DSCTools_DefaultResourcePath = "c:\program files\windowspowershell\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
$Script:DSCTools_DefaultPullServerResourcePath = "e:\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
$Script:DSCTools_DefaultPullServerConfigurationPath = "e:\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
$Script:DSCTools_DefaultPullServerPhysicalPath = "e:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
$Script:DSCTools_DefaultComplianceServerPhysicalPath = "e:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.

# These are the nodes that will become DSC Pull Servers
$PullServers = @( `
@{Name='DSCPULLSVR01';CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8'} )

# These are the nodes that we are going to set up Pull mode for
$Nodes = @( `
@{Name='NODE01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE01.MOF"} , `
@{Name='NODE02';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e2';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE02.MOF"} , `
@{Name='NODE03';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE03.MOF"} , `
@{Name='NODE04';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE04.MOF"} , `
@{Name='NODE05';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e5';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE05.MOF"} , `
@{Name='NODE06';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e6';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE06.MOF"} , `
@{Name='NODE07';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_StandardSrv\NODE07.MOF"} )

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
```

### Example Usage
Please see the GitHub repository folder for additional examples:
https://github.com/PlagueHO/Powershell/tree/master/DSCTools/Examples

### Todo Items
- Add Apply-DSCConfig function that will set up an entire DSC environment from a dsc.config xml file.
- Add ability to build the DSC configuration files if the MOF can't be found but the PS1 file can be found.
- Force rebuild MOF if the PS1 file is newer.
- Add support for Nodes to provide credentials to connect to a Pull Server.
- Add automatic update of module function.
- Add support for downloading Resource Kit Resouces when PS 5.0 is installed.
- Add support for specifying a list of Resources to be downloaded with PS 5.0 from PowerShell Get.
