Powershell
==========

These are some general purpose Powershell scripts and tools that I wrote while learning Powershell.

They were written in Powershell 4.0 and have only been tested in that version of PS.

## Compare-ShareACLs
This script is able record all the ACLs on specified SMB shares on computer and then report
the differences at a later date.

### Overview
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
comaprison script. This is so that the comparison can output custom PS objects containing any ACL changes to
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


## DSCTools
This module provides miscellaneous helper functions for setting up and using Powershell DSC.


