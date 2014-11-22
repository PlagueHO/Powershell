Powershell
==========

These are some general purpose Powershell scripts and tools that I wrote while learning Powershell. I hope they help someone! Feel free to comment on them.

They were written in Powershell 4.0 and have only been tested in that version of PS.

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


## ACLReportTools
This module contains functions for generating reports of file, folder and share ACL's, storing the reports and comparing them with earlier reports.

### Overview
To complete...

#### Function Get-ACLShareReport
This cmdlet returns an ACL Share Report in the pipeline for the computers/shares specified. The output of the cmdlet can be
exported as a file by being piped to Export-ACLShareReport for later comparison or used directly in a Compare-ACLShareReport.

For example:
```powershell
Get-ACLShareReport -ComputerName CLIENT01,CLIENT02 -Include SHARE1,SHARE2
```

See:
```powershell
Get-Help -Name Get-ACLShareReport -Full
```
For more information.

#### Function Export-ACLShareReport
This cmdlet exports an ACL Share Report in the pipeline (or InputObject parameter) to the file specified.

For example:
```powershell
Get-ACLShareReport -ComputerName CLIENT01,CLIENT02 -Include SHARE1,SHARE2 | Export-ACLShareReport -Path c:\ACLShareReports\MyShareReport.ACL
```

See:
```powershell
Get-Help -Name Export-ACLShareReport -Full
```
For more information.

#### Function Import-ACLShareReport
This cmdlet imports an ACL Share Report from the file specified back and returns the objects in the pipeline.

For example:
```powershell
Import-ACLShareReport -Path c:\ACLShareReports\MyShareReport.ACL
```

See:
```powershell
Get-Help -Name Import-ACLShareReport -Full
```
For more information.

#### Function Compare-ACLShareReports
This cmdlet compares a previously stored ACL Share Report with another ACL Share Report. The second ACL Share Report
can either be the current Share ACLs for the computers/shares specified in cmdlet parameters or the return of another cmdlet
e.g. Import-ACLShareReport or Get-ACLShareReport.

For example:
```powershell
Compare-ACLShareReports -Baseline (Import-ACLShareReport -Path c:\ACLShareReports\MyShareReport.ACL) -ComputerName CLIENT01,CLIENT02 -Include SHARE1,SHARE2
```

See:
```powershell
Get-Help -Name Compare-ACLShareReport -Full
```
For more information.

#### Function Export-ACLs
This cmdlet exports any [ACLReportTool.permissions] objects that are in the pipeline to an XML file.

For example:
```powershell
Get-ShareACLs -ComputerName CLIENT01 | Export-ACLs -Path c:\ACLs\CLIENT01.ACL)
```

See:
```powershell
Get-Help -Name Export-ACLs -Full
```
For more information.

#### Function Import-ACLs
This cmdlet imports any [ACLReportTool.permissions] objects from a specified XML file back into the pipeline.

For example:
```powershell
Import-ACLs -Path c:\ACLs\CLIENT01.ACL)
```

See:
```powershell
Get-Help -Name Import-ACLs -Full
```
For more information.

#### Function Get-Shares
This cmdlet returns a list of shares available on the specified computers. Specific shares can be excluded or included by passing the appropriate parameters.

For example:
```powershell
Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL
```

See:
```powershell
Get-Help -Name Get-Shares -Full
```
For more information.

#### Function Get-ShareACLs
This cmdlet returns a list of share permissions for the specified shares. The shares can be on multiple computers or on a single computer. To specify shares on multiple computers
the shares must be passed in via the pipeline as ACLReportTools.Share objects.

For example:
```powershell
Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL | Get-ShareACLs
```

See:
```powershell
Get-Help -Name Get-ShareACLs -Full
```
For more information.

#### Function Get-ShareFileACLs
This cmdlet returns a list defined file/folder permissions for files and folders in the specified shares. The shares can be on multiple computers or on a single computer. To specify shares on multiple computers
the shares must be passed in via the pipeline as ACLReportTools.Share objects. It will only return the permissions for the root folder unless the -Recurse switch is specified.

For example:
```powershell
Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL | Get-ShareFileACLs -Recurse
```

See:
```powershell
Get-Help -Name Get-ShareFileACLs -Full
```
For more information.

#### Function Get-PathFileACLs
This cmdlet returns a list defined file/folder permissions for files and folders in the specified path. Only a single path can be specified. It will only return the permissions for the root path unless the -Recurse switch is specified.

For example:
```powershell
Get-PathFileACLs -Path c:\ -Recurse
```

See:
```powershell
Get-Help -Name Get-PathFileACLs -Full
```
For more information.

### Minimum requirements

- PowerShell 2.0

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

### Installing ACLReportTools
1. Create a folder called ACLReportTools in the documents\windowspowershell\modules folder of your profile. E.g.
   C:\Users\Daniel\Documents\WindowsPowerShell\Modueles\ACLReportTools\
2. Copy the ACLReportTools.psm1, ACLReportTools.psd1 and ACLReportTools.format.ps1xml files into the folder created above.
3. In PowerShell execute:
```powershell
   Import-Module ACLReportTools
```

### Creating an ACL Share Report
...

### TODO
1. Create a cmdlet that converts the result of the Compare-ACLShareReport into an HTML report file.
2. Extend Get-PathFileACLs so that multiple paths can be specified and passed in via the pipeline.
3. Correct Convert-FileSystemAccessToString so that Special Generic Rights are displayed correctly.



## Compare-ShareACLs - DEPRECATED!
This script is able record all the ACLs on specified SMB shares on computer and then report
the differences at a later date.

This script has been deprecated. The ACLReportTools module replaces it.

### Overview
This script has been deprecated!

This script will get all the ACLs for all shares on this computer and compare them with a baseline set of share ACLs. It will also get and store the file/folder ACL's for all files/folders in each share.

If this script is run it will look for specified baseline ACL. If none are found it will create them from the shares active on this machine.
If the baseline data is found the script will output a report showing the changes to the share and file/folder ACLs.
The script makes three different types of Baseline files (.BSL) in the baseline folder:
 1. _SHARES.BSL - this is the list of shares available on the computer at the time of the baseline info being created.
 2. SHARE_*.BSL - this is the share ACLs for the share specified by * on the computer.
 3. FILE_*.BSL - this is the full list of defined (not inherited) file/folder ACLs for the * share on this computer.

### Minimum requirements

- PowerShell 4.0
- May run on earlier versions of PS but untested.

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

### Installing Compare-ShareACLs
Copy the Compare-ShareACLs.ps1 script into your Powershell Modules folder.

### Future Changes
This script needs to be converted into a module and the report generation split out from the main
comparison script. This is so that the comparison can output custom PS objects containing any ACL changes to
the shares. The objects can then be piped to a report function or to any other standard PS output cmdlet.

### Example Usage
```powershell
Compare-ShareACLs -ComputerName DC -RebuildBaseline
```
Causes the Baseline share, file and folder ACL information to be rebuilt for the DC machine.

```powershell
Compare-ShareACLs -ComputerName DC -BaselinePath c:\baseline\DC\
```
Performs a Share, File and Folder ACL comparison with the current ACL info from all shares on the DC machine against the Baseline ACL
info stored in the c:\baseline\DC\ folder. If baseline data does not exist in this folder it will be created as if the -RebuildBaseline
swtich was set.

```powershell
Compare-ShareACLs -ComputerName DC -IncludeShares SHARE1,SHARE2
```
Performs a Share, File and Folder ACL comparison with the current ACL info from only shares SHARE1 and SHARE2 on the DC machine against the Baseline ACL
info stored in the c:\baseline\DC\ folder. If baseline data does not exist in this folder it will be created as if the -RebuildBaseline
swtich was set. Do not use the -ExcludeShares parameter when the -IncludeShares parameter is set.

```powershell
 Compare-ShareACLs -ComputerName DC -ExcludeShares SYSVOL,NETLOGON
```
Performs a Share, File and Folder ACL comparison with the current ACL info from all shares except SYSVOL and NETLOGON on the DC machine against the Baseline ACL
info stored in the c:\baseline\DC\ folder. If baseline data does not exist in this folder it will be created as if the -RebuildBaseline
swtich was set. Do not use the -IncludeShares parameter when the -ExcludeShares parameter is set.
