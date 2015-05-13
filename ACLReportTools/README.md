Powershell
==========

## ACLReportTools
This module contains functions for creating reports on file, folder and share ACL's, storing the reports and comparing them with earlier reports.

### Overview
The intended purpose of this module is to allow an Admininstrator to report on how ACL's for a set of path or shares have changed since a baseline was last created.

Basically it allows administrators to easily see what ACL changes are being made so they keep an eye on any secuity issues arising. The process of creating/updating the baseline and producing the ACL Difference report could be easily automated. If performing SMB share comparisons, the report generation can be performed remotely (from a desktop PC for example).

The process that is normally followed using this module is:

1. Produce a baseline ACL Report from a set of Folders or Shares (even on multiple computers).
2. Export the baseline ACL Report as a file.
3. ... Sometime later ...
4. Import the baseline ACL Report from a stored file.
5. Produce a ACL Difference report comparing the imported baseline ACL Report with the current ACL state of the Folders or Shares.
6. Optionally export the ACL Difference report as HTML.
7. Repeat from step 1.

The above process could be easily automated in many ways (Task Scheduler is suggested).

The comparison is always performed recursively scanning a specified set of folders or SMB shares. All files and folders within these locations will be scanned, but only non-inherited ACLs will be added to the ACL Reports.

Note:

An ACL report is a list of the current ACLs for a set of Shares or Folders. It is stored as a serialized array of [ACLReportTools.Permission] objects that are returned by the New-ACLShareReport, New-ACLPathFileReport and Import-ACLReport cmdlets.

An ACL Difference report is a list of all ACL differences between two ACL reports. It is stored as serialized array of [ACLReportTools.PermissionDiff] objects that are produced by the Compare-ACLReports cmdlet.

ACL Reports produced for Shares rather than folders differ in that the Share name is provided in each [ACLReportTools.Permission] object and that the SMB Share ACL is also provided in the [ACLReportTools.Permission] array.

### Important Notes
When performing a comparison, make sure the baseline report used covers the same set of folders/shares you want to compare now. E.g. Don't try and compare ACLs for c:\windows and c:\wwwroot - that would make no sense.

If shares or folders that are being compared have large numbers of non-inherited ACLs (perhaps because some junior admin doesn't understand inheritance) then a comparison can take a LONG time (hours) and really hog your CPU. If this is the case, run on another machine using Share mode or run after hours - or better yet, teach junior admins about inheritance! :)

This Module uses the awesome NTFS Security Module available here:

https://gallery.technet.microsoft.com/scriptcenter/1abd77a5-9c0b-4a2b-acef-90dbb2b84e85

Ensure that you unblock all files in the NTFSSecurity module before attempting to Import Module ACLReportTools. Module ACLReportTools automatically looks for and Imports NTFSSecuriy if present. If it is missing an error will be reported stating that it is missing. If you recieve any other errors loading ACL Report tools, it is usually because some of the NTFSSecurity module files are blocked and need to be unblocked manually or with Unblock-File. You can confirm this by calling Import-Module NTFSSecurity - if any errors appear then it is most likely the cause. After unblocking the module files you may need to restart PowerShell.

You should also ensure that the account that is being used to generate the reports has read access to all paths (recursively) you are reporting on and can access also read the ACLs. If it can't access them then you may get access denied errors.

### Version Info
<pre>
1.21  2015-05-13   Daniel Scott-Raynsford       Added Cmdlet for Exporting Diff Report as
                                                HTML
1.2   2015-05-13   Daniel Scott-Raynsford       Added Cmdlets for Importing/Exporting
                                                Permission Difference reports.
1.1   2015-05-12   Daniel Scott-Raynsford       Updated to use NTFSSecurity Module
                                                Updated CmdLet names to follow standards
1.0   2015-05-09   Daniel Scott-Raynsford       Initial Version
</pre>

### Installing ACLReportTools
1. Unzip the archive containing the ACLReportTools module into the one of the PowerShell Modules folders.
   E.g. c:\program files\windowspowershell\modules
2. This will create a folder called ACLReportTools containing all the files required for this module.
3. In PowerShell execute:
```powershell
Import-Module ACLReportTools
```

### Example Usage

#### Example Usage: Creating a Baseline ACL Report file from Folders
This example creates a baseline ACL Report on the folders e:\work and d:\profiles and stores it in the Baseline.acl file in the current users Documents folder.
```powershell
Import-Module ACLReportTools
New-ACLPathFileReport -Path "e:\Work","d:\Profiles" | Export-ACLReport -Path "$HOME\Documents\Baseline.acl" -Force
```

#### Example Usage: Comparing a Baseline ACL Report file from Folders with Current ACLs
This example compares the previously created baseline ACL Report stored in the users Documents folder and compares it with the current ACLs for the folders e:\Work and d:\Profiles.
```powershell
Import-Module ACLReportTools
Compare-ACLReports -Baseline (Import-ACLReport -Path "$HOME\Documents\Baseline.acl") -Path "e:\Work","d:\Profiles"
```

#### Example Usage: Creating a Baseline ACL Report file from Shares
This example creates a baseline ACL Report on the shares \\client\Share1\ and \\client\Share2\ and stores it in the Baseline.acl file in the current users Documents folder.
```powershell
Import-Module ACLReportTools
New-ACLShareReport -ComputerName Client -Include Share1,Share2 | Export-ACLReport -Path "$HOME\Documents\Baseline.acl" -Force
```

#### Example Usage: Comparing a Baseline ACL Report file from Shares with Current ACLs
This example compares the previously created baseline ACL Report stored in the users Documents folder and compares it with the current ACLs for the folders e:\Work and d:\Profiles.
```powershell
Import-Module ACLReportTools
Compare-ACLReports -Baseline (Import-ACLReport -Path "$HOME\Documents\Baseline.acl") -ComputerName Client -Include Share1,Share2
```

#### Example Usage: Exporting a Difference Report as an HTML File
This example takes the output of the Compare-ACLReports cmdlet and formats it as HTML and saves it for easier review and storage.
```powershell
Import-Module ACLReportTools
Compare-ACLReports -Baseline (Import-ACLReport -Path "$HOME\Documents\Baseline.acl") -ComputerName Client -Include Share1,Share2 | Export-ACLPermissionDiffHTML -Path "$HOME\Documents\Difference.htm"
```

### CmdLets

#### CmdLet New-ACLShareReport
Creates a list of Share, File and Folder ACLs for the specified shares/computers.

For example:
```powershell
New-ACLShareReport -ComputerName CLIENT01,CLIENT02 -Include SHARE1,SHARE2
```

See:
```powershell
Get-Help -Name New-ACLShareReport -Full
```
For more information.

#### CmdLet New-ACLPathFileReport
Creates a list of File and Folder ACLs for the provided path(s).

For example:
```powershell
New-ACLPathFileReport -Path 'e:\work','e:\profile'
```

See:
```powershell
Get-Help -Name New-ACLPathFileReport -Full
```
For more information.

#### CmdLet Export-ACLReport
Export an ACL Permission Report as a file.

For example:
```powershell
Export-ACLReport -Path C:\ACLReports\server01.acl -InputObject $PermissionReport
```

See:
```powershell
Get-Help -Name Export-ACLReport -Full
```
For more information.

#### CmdLet Import-ACLReport
This cmdlet imports an ACL Permission Report from the file specified back and returns the objects in the pipeline.

For example:
```powershell
Import-ACLReport -Path C:\ACLReports\server01.acl
```

See:
```powershell
Get-Help -Name Import-ACLReport -Full
```
For more information.

#### CmdLet Export-ACLDiffReport
Export an ACL Difference Report as a file.

For example:
```powershell
Export-ACLDiffReport -Path C:\ACLReports\server01.acr -InputObject $DiffReport
```

See:
```powershell
Get-Help -Name Export-ACLDiffReport -Full
```
For more information.

#### CmdLet Import-ACLDiffReport
This cmdlet imports an ACL Difference Report from the file specified back and returns the objects in the pipeline.

For example:
```powershell
Import-ACLDiffReport -Path C:\ACLReports\server01.acr
```

See:
```powershell
Get-Help -Name Import-ACLDiffReport -Full
```
For more information.

#### CmdLet Compare-ACLReports
Compares two ACL reports and produces an ACL Difference report.

For example:
```powershell
Compare-ACLReports -Baseline (Import-ACLReport -Path C:\ACLReports\server01.acl) -Path 'e:\work','e:\profile'
```

See:
```powershell
Get-Help -Name Compare-ACLReports -Full
```
For more information.

#### CmdLet Export-ACLPermission
Export the ACL Permissions objects that are provided as a file.

For example:
```powershell
Export-ACLPermission -Path C:\ACLReports\server01.acl -InputObject $ShareReport
```

See:
```powershell
Get-Help -Name Export-ACLPermission -Full
```
For more information.

#### CmdLet Import-ACLPermission
Import the a File containing serialized ACL Permission objects that are in a file back into the pipeline.

For example:
```powershell
Import-ACLPermission -Path c:\ACLs\CLIENT01.ACL
```

See:
```powershell
Get-Help -Name Import-ACLPermission -Full
```
For more information.

#### CmdLet Export-ACLPermissionDiff
Export the ACL Difference Objects that are provided as a file.

For example:
```powershell
Export-ACLPermission -Path C:\ACLReports\server01.acl -InputObject $ShareReport
```

See:
```powershell
Get-Help -Name Export-ACLPermissionDiff -Full
```
For more information.

#### CmdLet Import-ACLPermissionDiff
Import the a File containing serialized ACL Permission Diff objects that are in a file back into the pipeline.

For example:
```powershell
Import-ACLPermissionDiff -Path c:\ACLs\CLIENT01.ACR
```

See:
```powershell
Get-Help -Name Import-ACLPermissionDiff -Full
```
For more information.

#### CmdLet Export-ACLPermissionDiffHTML
Export the ACL Difference Objects that are provided as an HTML file.

For example:
```powershell
Compare-ACLReports -Baseline (Import-ACLReports -Path c:\ACLReports\server01.acl) -With (Get-ACLReport -ComputerName Server01) | Export-ACLPermissionDiffHTML -Path C:\ACLReports\server01.htm
```

See:
```powershell
Get-Help -Name Export-ACLPermissionDiffHTML -Full
```
For more information.

#### CmdLet Get-ACLShare
Gets a list of the Shares on a specified computer(s) with specified inclusions or exclusions.

For example:
```powershell
Get-ACLShare -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL
```

See:
```powershell
Get-Help -Name Get-ACLShare -Full
```
For more information.

#### CmdLet Get-ACLShareACL
Gets the ACLs for a specified Share.

For example:
```powershell
Get-ACLShare -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL | Get-ACLShareACL
```

See:
```powershell
Get-Help -Name Get-ACLShareACL -Full
```
For more information.

#### CmdLet Get-ACLShareFileACL
Gets all the non-inherited file/folder ACLs definited within a specified Share. A recursive search is optional.

For example:
```powershell
Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL | Get-ACLShareFileACL -Recurse
```

See:
```powershell
Get-Help -Name Get-ACLShareFileACL -Full
```
For more information.

#### CmdLet Get-ACLPathFileACL
Gets all the non-inherited file/folder ACLs defined within a specified Path. A recursive search is optional.

For example:
```powershell
Get-ACLPathFileACL -Path c:\ -Recurse
```

See:
```powershell
Get-Help -Name Get-ACLPathFileACL -Full
```
For more information.

### Minimum requirements

- PowerShell 2.0

### License and Copyright

Copyright 2015 Daniel Scott-Raynsford

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

### TODO
