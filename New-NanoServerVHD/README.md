Powershell
==========

## New-NanoServerVHD
Creates a bootable VHD containing Windows Server Nano 2016.

### Overview
Creates a bootable VHD containing Windows Server Nano 2016 using the publically available Windows Server 2016 Technical Preview 2 ISO.

This script needs the Convert-WindowsImage.ps1 script to be in the same folder. It can be downloaded from:
https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f

This function turns the instructions on the following link into a repeatable script:
https://technet.microsoft.com/en-us/library/mt126167.aspx

Please see the link for additional information.

This script can be found:
Github Repo: https://github.com/PlagueHO/Powershell/tree/master/New-NanoServerVHD
Script Center: https://gallery.technet.microsoft.com/scriptcenter/DSC-Tools-c96e2c53


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


### Example Usage
<pre>
.\New-NanoServerVHD.ps1 `
    -ServerISO 'D:\ISOs\Windows Server 2016 TP2\10074.0.150424-1350.fbl_impressive_SERVER_OEMRET_X64FRE_EN-US.ISO' `
    -DestVHD D:\Temp\NanoServer01.vhd `
    -ComputerName NANOTEST01 `
    -AdministratorPassword 'P@ssword!1' `
    -Packages 'Compute','OEM-Drivers','Guest' `
    -Verbose
</pre>
This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Compute, OEM-Drivers and Guest packages.