Powershell
==========

## DSCTools
This module provides miscellaneous helper functions for setting up and using Powershell DSC.

### Overview
This module contains functions to try and make setting up and using Desired State Configuration easier.

#### Function Invoke-DSCCheck
Forces the LCM on the specified nodes to trigger a DSC check.

For example:
```powershell
Invoke-DSCCheck -ComputerName SERVER01,SERVER02
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
Invoke-DSCCheck -ComputerName SERVER01,SERVER02
```

See:
```powershell
Get-Help -Name Invoke-DSCCheck -Full
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
1. Create a folder called DSCTools in the documents\windowspowershell\modules folder of your profile. E.g.
   C:\Users\Daniel\Documents\WindowsPowerShell\Modueles\DSCTools\
2. Copy the DSCTools.psm1 and DSCTools.psd1 files into the folder created above.
3. In PowerShell execute:
```powershell
   Import-Module DSCTools
```


### Example Usage
```powershell
# Configure where the pull server is and how it can be connected to.
$DSCTools_PullServerName = 'PULLSERVER01'
$DSCTools_PullServerProtocol = 'HTTPS'  # Pull server has a valid trusted cert installed
$DSCTools_PullServerPort = 26054  # Pull server is running on this port
$DSCTools_PullServerPath = 'PrimaryPullServer/PSDSCPullServer.svc'
$DSCTools_DefaultModuleFolder = 'c:\DSC\Resources\'  # This is where all the DSC resources can be found
$DSCTools_DefaultResourceFolder = 'DscService\Modules'  # This is a share+path on the Pull Server
$DSCTools_DefaultConfigFolder = 'DscService\configuration'   # This is a share+path on the Pull Server
$DSCTools_DefaultNodeConfigSourceFolder = "c:\DSC\Configuratons\"  

# These are the nodes that we are going to set up Pull mode for
$Nodes = @( `
    @{Name='SERVER01';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e7';RebootNodeIfNeeded=$true;MofFile='C:\DSConfigs\SERVER01.MOF'} , `
    @{Name='SERVER02';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e1';RebootNodeIfNeeded=$true;MofFile='C:\DSConfigs\SERVER02.MOF'} , `
    @{Name='SERVER03';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e3';RebootNodeIfNeeded=$true;MofFile='C:\DSConfigs\SERVER03.MOF'} , `
    @{Name='SERVER04';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e4';RebootNodeIfNeeded=$true;MofFile='C:\DSConfigs\SERVER04.MOF'} , `
    @{Name='SERVER05';Guid='115929a0-61e2-41fb-a9ad-0cdcd66fc2e9';RebootNodeIfNeeded=$true;MofFile='C:\DSConfigs\SERVER05.MOF'} )

# Copy all th resources up to the pull server (zipped and with a checksum file).
Publish-DSCPullResources

# Set all the nodes to pull mode and copy the config files over to the pull server.
Start-DSCPullMode -Nodes $Nodes

# Force the all the machines to pull thier config from the Pull server (although we could just wait 15 minutes for this to happen automatically)
Invoke-DSCPull -Nodes $Nodes

# Set all the nodes to back to push mode if we don't want to use Pul mode any more.
# Start-DSCPushMode -Nodes $Nodes
```
