Powershell
==========

## New-NanoServerVHD
Creates a bootable VHD/VHDx containing Windows Server Nano 2016.

Note: As of Windows Server 2016 Technical Preview 3, the NanoServer folder in the ISO contains a new-nanoserverimage.ps1 PowerShell script that can also be used to create new Nano Server VHD/VHDx files. This script is the official one provided by Microsoft and so it should be used in any new scripts. I have updated the new-nanoservervhd.ps1 script to support TP3 so that if you have already got scripts using it then you don't have to rewrite them to use the official one (although you probably should).

### Overview
Creates a bootable VHD/VHDx containing Windows Server Nano 2016 using the publicly available Windows Server 2016 Technical Preview 3 ISO.

This script needs the Convert-WindowsImage.ps1 script to be in the same folder. It can be downloaded from:
https://raw.githubusercontent.com/PlagueHO/Powershell/master/New-NanoServerVHD/Convert-WindowsImage.ps1

Note: Due to a bug in the current version of the Convert-WindowsImage.ps1 on Microsoft Script Center, I am hosting a modified copy of this script on GitHub. The unfixed version can be downloaded from:
https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f
IT WILL NOT CURRENTLY WORK WITH NANO SERVER TP4.

If you recieve the error:
**ERROR  : The variable cannot be validated because the value $null is not a valid value for the Edition variable**
This indicates you are using an Unfixed version of the Convert-WindowsImage.ps1 script with Nano Server TP4 - please use the copy hosted at:
https://raw.githubusercontent.com/PlagueHO/Powershell/master/New-NanoServerVHD/Convert-WindowsImage.ps1

Please make sure you have the 2015-06-16 version of the Convert-WindowsImage.ps1 script. Earlier versions will no longer work!

This function turns the instructions on the following link into a repeatable script:
https://technet.microsoft.com/en-us/library/mt126167.aspx

Please see the link for additional information.

This script can be found:
Github Repo: https://github.com/PlagueHO/Powershell/tree/master/New-NanoServerVHD
Script Center: https://gallery.technet.microsoft.com/scriptcenter/DSC-Tools-c96e2c53

### Change Log
2015-12-01: Added WorkFolder parameter to override default work folder path.
2015-11-21: Offline Domain Join support added. Fix to adding SCVMM packages.
2015-11-20: Ability to cache base NanoServer.VHD/VHDx file to speed up creation of multiple VHD files with different packages/settings.
2015-11-20: Added support for Windows Server 2016 TP4.
2015-11-13: Added Optional Timezone Parameter. Defaults to 'Pacific Standard Time'.
2015-09-18: Added support for setting IP Subnet Mask, Default Gateway and DNS Settings on first boot.
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


### Example Usage
```powershell
.\New-NanoServerVHD.ps1 `
    -ServerISO 'D:\ISOs\Windows Server 2016 TP4\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
    -DestVHD D:\Temp\NanoServer01.vhd `
    -ComputerName NANOTEST01 `
    -AdministratorPassword 'P@ssword!1' `
    -Packages 'Compute','OEM-Drivers','Guest' `
    -Verbose
```
This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Compute, OEM-Drivers and Guest packages. The IP Address will be configured using DHCP.

```powershell
.\New-NanoServerVHD.ps1 `
	-ServerISO 'D:\ISOs\Windows Server 2016 TP4\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
	-DestVHD D:\Temp\NanoServer01.vhd `
	-ComputerName NANOTEST01 `
	-AdministratorPassword 'P@ssword!1' `
	-Packages 'Storage','OEM-Drivers','Guest' `
	-IPAddress '10.0.0.20' `
    -SubnetMask '255.0.0.0' `
    -GatewayAddress '10.0.0.1' `
    -DNSAddresses '10.0.0.2','10,0,0,3' `
	-Verbose
```

This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Storage, OEM-Drivers and Guest packages. It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 10.0.0.20/255.0.0.0 with gateway of 10.0.0.1 and DNS set to '10.0.0.2','10,0,0,3'. It will also set the timezone to 'Russian Standard Time'.

```powershell
.\New-NanoServerVHD.ps1 `
	-ServerISO 'D:\ISOs\Windows Server 2016 TP4\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
	-DestVHD D:\Temp\NanoServer02.vhdx `
	-VHDFormat VHDX `
	-ComputerName NANOTEST02 `
	-AdministratorPassword 'P@ssword!1' `
	-Packages 'Storage','OEM-Drivers','Guest' `
	-IPAddress '192.168.1.66' `
	-Timezone 'Russian Standard Time'
	-Verbose
```

This command will create a new VHDx (for Generation 2 VMs) containing a Nano Server machine with the name NANOTEST02. It will contain only the Storage, OEM-Drivers and Guest packages. It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 192.168.1.66/255.255.255.0 with no Gateway or DNS.

```powershell
.\New-NanoServerVHD.ps1 `
	-ServerISO 'D:\ISOs\Windows Server 2016 TP4\10586.0.151029-1700.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
	-DestVHD D:\Temp\NanoServer03.vhdx `
	-VHDFormat VHDX `
	-ComputerName NANOTEST03 `
	-AdministratorPassword 'P@ssword!1' `
	-Packages 'Compute','OEM-Drivers','Guest','Containers','ReverseForwarders' `
	-IPAddress '192.168.1.66' `
	-DJoinFile 'D:\Temp\DJOIN_NANOTEST03.TXT' `
	-Verbose
```

This command will create a new VHDx (for Generation 2 VMs) containing a Nano Server machine with the name NANOTEST03. It will contain be configured to be a container host. It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 192.168.1.66/255.255.255.0 with no Gateway or DNS. It will also be joined to a domain using the Offline Domain Join file D:\Temp\DJOIN_NANOTEST03.TXT.
