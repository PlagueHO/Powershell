Powershell
==========

## New-NanoServerVHD
Creates a bootable VHD/VHDx containing Windows Server Nano 2016.

Note: As of Windows Server 2016 Technical Preview 3, the NanoServer folder in the ISO contains a new-nanoserverimage.ps1 PowerShell script that can also be used to create new Nano Server VHD/VHDx files. This script is the official one provided by Microsoft and so it should be used in any new scripts. I have updated the new-nanoservervhd.ps1 script to support TP3 so that if you have already got scripts using it then you don't have to rewrite them to use the official one (although you probably should).

### Overview
Creates a bootable VHD/VHDx containing Windows Server Nano 2016 using the publicly available Windows Server 2016 Technical Preview 3 ISO.

This script needs the Convert-WindowsImage.ps1 script to be in the same folder. It can be downloaded from:
https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f

Please make sure you have the 2015-06-16 version of the Convert-WindowsImage.ps1 script. Earlier versions will no longer work!

This function turns the instructions on the following link into a repeatable script:
https://technet.microsoft.com/en-us/library/mt126167.aspx

Please see the link for additional information.

This script can be found:
Github Repo: https://github.com/PlagueHO/Powershell/tree/master/New-NanoServerVHD
Script Center: https://gallery.technet.microsoft.com/scriptcenter/DSC-Tools-c96e2c53

### Change Log
2015-08-20: Updated to support packages available in Windows Server 2016 TP3.
2015-07-24: Updated setup complete script to create a task that shows the IP Address of the Nano Server in the console window 30 seconds after boot.
2015-06-19: Updated to support changes in Convert-WindowsImage on 2015-06-16.
2015-06-19: Added VHDFormat parameter to allow VHDx files to be created.
2015-06-19: Added Edition parameter (defaults to CORESYSTEMSERVER_INSTALL) so that the Name of the edition in the NanoServer.WIM can be specified. 
2015-06-19: Because of changes in Convert-WindowsImage, VHDx files are always created using the GPT partition format. VHD files are still created using MBR partition format.
2015-06-05: Fix to Unattend.xml to correctly set Server Name in OfflineServicing phase.

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
    -ServerISO 'D:\ISOs\Windows Server 2016 TP3\10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
    -DestVHD D:\Temp\NanoServer01.vhd `
    -ComputerName NANOTEST01 `
    -AdministratorPassword 'P@ssword!1' `
    -Packages 'Compute','OEM-Drivers','Guest' `
    -Verbose
</pre>
This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Compute, OEM-Drivers and Guest packages.