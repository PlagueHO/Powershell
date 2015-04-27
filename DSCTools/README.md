Powershell
==========

## DSCTools
This module provides helper functions for setting up and using Desired State Configration.

### Overview
Anyone who has attempted to install and use DSC and DSC pull servers knows that it can be a little bit of a tricky process. This module attempts to simplify the process by putting all the pieces together in simple functions.

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


#### Function Get-DscConfigurationRemote
Gets the current DSC configuration of a remote node.

For example:
```powershell
Get-DscConfigurationRemote -ComputerName DSCSVR01 -Credential (Get-Credential) -UseSSL
```

See:
```powershell
Get-Help -Name Get-DscConfigurationRemote -Full
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



### Example Usage - Installing a Pull Server with a single Node
This example would be run either on the Pull Server or on another computer using a user account that has administrator privileges to the Pull Server. This example will perform the following operations:

1. Create a basic folder structure on the DSCPULLSVR01 Pull Server where the DSC resources and configuratins will be stored.
2. Download and install the DSC Resource Kit onto this computer and the DSCPULLSVR01 Pull Server.
3. Publish the DSC Resources from the DSC resource kit onto the DSCPULLSVR01 Pull Server.
4. Install DSCPULLSVR01 as a DSC Pull Server.
5. Pull the LCM DSC Configuration from the DSCPULLSVR01 Pull Server to confirm it has been configured as a Pull Server.
6. Set NODE01 node to use the DSCPULLSVR01 Pull Server and load the configuration files for it onto the DSCPULLSVR01 Pull Server.
7. Force NODE01 node to pull DSC configuration from the DSCPULLSVR01 Pull Server.
8. Set NODE01 to use Push Mode and apply the DSC configration files.
9. Force NODE01 to apply the loaded Push Mode DSC configuration files.
```powershell
    $PullServer = 'DSCPULLSVR01'
    $Credential = Get-Credential
    
    # Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    New-Item -Path "\\$Script:DSCTools_DefaultPullServerName\c$\DSC\" -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerResourcePath -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerConfigurationPath -ItemType Directory
    
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
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer `
        -ComputerName $PullServer `
        -CertificateThumbprint '3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8' `
        -Credential ($Credential) `
        -PullServerResourcePath "\\$PullServer\c$\DSC\Resources\" `
        -PullServerConfigurationPath "\\$PullServer\c$\DSC\Configuration\" `
        -PullServerPhysicalPath "c:\DSC\PSDSCPullServer\" `
        -ComplianceServerPhysicalPath "c:\DSC\PSDSCComplianceServer\" `
        -Verbose

    # Check the pull server
    Get-DscConfigurationRemote `
        -ComputerName $PullServer `
        -UseSSL `
        -Credential ($Credential) `
        -Verbose
    
	# Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode `
		-ComputerName 'NODE01' `
		-Guid '115929a0-61e2-41fb-a9ad-0cdcd66fc2e7' `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_Test\NODE01.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
        -PullServerConfigurationPath "\\$PullServer\c$\DSC\Configuration\" `
		-Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-ComputerName NODE01 `
		-Verbose

	# Set all the nodes to back to push mode if we don't want to use Pull mode any more.
    Start-DSCPushMode `
		-ComputerName NODE01 `
		-RebootIfNeeded `
		-MofFile "$PSScriptRoot\Configuration\Config_Test\NODE01.MOF" `
		-ConfigurationMode 'ApplyAndAutoCorrect' `
		-Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck `
		-ComputerName NODE01 `
		-Verbose
```



### Example Usage - Installing a Pull Server with multiple Nodes
This example would be run either on the Pull Server or on another computer using a user account that has administrator privileges to the Pull Server. This example will perform the following operations:

1. Create a basic folder structure on the DSCPULLSVR01 Pull Server where the DSC resources and configuratins will be stored.
2. Download and install the DSC Resource Kit onto this computer and the DSCPULLSVR01 Pull Server.
3. Publish the DSC Resources from the DSC resource kit onto the DSCPULLSVR01 Pull Server.
4. Install DSCPULLSVR01 as a DSC Pull Server.
5. Pull the LCM DSC Configuration from the DSCPULLSVR01 Pull Server to confirm it has been configured as a Pull Server.
6. Set the Nodes defined in the Nodes array to use the DSC Pull Server and load the configuration files for them onto the Pull Server.
7. Force the Nodes to pull DSC configuration from the Pull Server.
8. Set the Nodes defined in the Nodes array to use Push Mode and apply the DSC configration files.
9. Force the Nodes to apply the loaded Push Mode DSC configuration files.
```powershell    
    # Configure where the pull server is and how it can be connected to.
    $Script:DSCTools_DefaultPullServerName = 'DSCPULLSVR02'
    $Script:DSCTools_DefaultPullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
    $Script:DSCTools_DefaultResourcePath = "c:\program files\windowspowershell\Modules\All Resources\"  # This is where the DSC resource module files are usually located.
    $Script:DSCTools_DefaultPullServerResourcePath = "\\$DSCTools_DefaultPullServerName\c$\DSC\Resources\"  # This is the path where a DSC Pull Server will look for Resources.
    $Script:DSCTools_DefaultPullServerConfigurationPath = "\\$DSCTools_DefaultPullServerName\c$\DSC\Configuration\"   # This is the path where a DSC Pull Server will look for MOF Files.
    $Script:DSCTools_DefaultPullServerPhysicalPath = "c:\DSC\PSDSCPullServer\" # The location a Pull Server web site will be installed to.
    $Script:DSCTools_DefaultComplianceServerPhysicalPath = "c:\DSC\PSDSCComplianceServer\" # The location a Pull Server compliance site will be installed to.
    $Credential = Get-Credential

    # These are the nodes that will become DSC Pull Servers
    $PullServers = @( `
	    @{Name=$Script:DSCTools_DefaultPullServerName;CertificateThumbprint='3aaeef3f4b6dad0c8cb59930b48a9ffc25daa7d8';Credential=$Credential;} )

    # These are the nodes that we are going to set up Pull mode for
    $Nodes = @( `
	    @{Name='NODE01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE01.MOF"} , `
	    @{Name='NODE02';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e2';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE02.MOF"} , `
	    @{Name='NODE03';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE03.MOF"} , `
	    @{Name='NODE04';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE04.MOF"} , `
	    @{Name='NODE05';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e5';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE05.MOF"} , `
	    @{Name='NODE06';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e6';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE06.MOF"} , `
	    @{Name='NODE07';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootIfNeeded=$true;MofFile="$PSScriptRoot\Configuration\Config_Test\NODE07.MOF"} )

	# Create the folder structure on the Pull Server where the DSC files will be installed to
	# If the default paths are used then this wouldn't need to be done as these paths usually already exist
    New-Item -Path "\\$Script:DSCTools_DefaultPullServerName\c$\DSC\" -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerResourcePath -ItemType Directory
    New-Item -Path $Script:DSCTools_DefaultPullServerConfigurationPath -ItemType Directory
    
    # Download the DSC Resource Kit and install it to the local machine and to the DSC Pull Server
    Install-DSCResourceKit -UseCache -Verbose
    Install-DSCResourceKit -ModulePath "\\$Script:DSCTools_DefaultPullServerName\c$\program files\windowspowershell\modules\" -UseCache -Verbose

    # Copy all the resources up to the pull server (zipped and with a checksum file).
    Publish-DSCPullResources -Verbose

    # Install a DSC Pull Server
    Enable-DSCPullServer -Nodes $PullServers -Verbose

    # Check the pull server
    Get-DscConfigurationRemote -ComputerName $Script:DSCTools_DefaultPullServerName -UseSSL -Credential ($Credential) -Verbose

    # Set all the nodes to pull mode and copy the config files over to the pull server.
    Start-DSCPullMode -Nodes $Nodes -Verbose

    # Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck -Nodes $Nodes -Verbose

    # Set all the nodes to back to push mode if we don't want to use Pul mode any more.
    Start-DSCPushMode -Nodes $Nodes -Verbose

    # Force the all the machines to reapply thier configuration (although we could just wait 15 minutes for this to happen automatically)
    Invoke-DSCCheck -Nodes $Nodes -Verbose
```
