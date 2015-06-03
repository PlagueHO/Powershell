Powershell
==========

## Install using GPO Tools
This project contains scripts for installing applications or updates via GPO.

### Overview
This contains two PowerShell scripts that will install either an Application or an Windows QFE Update. These scripts are designed to be used with Startup/Logon GPO scripts to install these updates. The registry or WMI will be checked to see if the Application or Update is already installed. If it is installed then the process will be skipped.

I wrote these scripts initally to automate the process of installing Notepad++ and the WMF 5.0 preview in my lab environemt. It is based loosely on the code I wrote in the OfficeTools scripts (for installing Office via GPO).

### Install-Application
Installs an Application from a local or network media source if a registry key/value is not set.

####Description
Installs an Application from a specified media source by executing the setup installer (.EXE) file.
  
A registry key must also be provided to check for to identify if the application is already installed. Optionally a registry value in the registry key can also be checked for.

This script would normally be used with the Windows Server 2012 GPO PowerShell Start up Script feature to install a specific application.

####Examples
Install Notepad++ 6.7.8.2 without creating a logfile:
```powershell
Install-Application -InstallerPath '\\server\Software$\Notepad++\npp.6.7.8.2.Installer.exe' -RegistryKey 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++' -RegistryName 'DisplayVersion' -RegistryValue '6.7.8.2' -InstallerParameters '/S'
```

Install Notepad++ 6.7.8.2 creating log files for each machine it is installed on in \\Server\Software$\logfiles\ folder:
```powershell
Install-Application -InstallerPath '\\server\Software$\Notepad++\npp.6.7.8.2.Installer.exe' -RegistryKey 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++' -RegistryName 'DisplayVersion' -RegistryValue '6.7.8.2' -InstallerParameters '/S' -LogPath \\Server\Software$\logfiles\
```

See:
```powershell
Get-Help .\Install-Application.ps1 -Full
```
For more information.


### Install-Update
Installs a Windows QFE Update from a local or network media source.

####Description
Installs a Windows QFE Update from a specified media source by executing the update installer (.EXE) or Microsoft Update (.MSU) file.
  
This script would normally be used with the Windows Server 2012 GPO PowerShell Start up Script feature to install a specific application or update.

Normally WSUS would be used to distribute and install QFE updates, but some updates are not always available via this method (Windows Management Framework 3.0 and above for example). SCCM could be used instead but this is for sites not using SCCM.

####Examples
To install the Windows Management Framework 5.0 April 2015 update with no log file creation:
```powershell
Install-Update -InstallerPath \\Server\Software$\Updates\WindowsBlue-KB3055381-x64.msu -KBID KB3055381
```

To install the Windows Management Framework 5.0 April 2015 update creating log files for each machine it is installed on in \\Server\Software$\logfiles\ folder:
```powershell
Install-Update -InstallerPath \\Server\Software$\Updates\WindowsBlue-KB3055381-x64.msu -KBID KB3055381 -LogPath \\Server\Software$\logfiles\
```

See:
```powershell
Get-Help .\Install-Update.ps1 -Full
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
