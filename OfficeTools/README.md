Powershell
==========

## OfficeTools
This project contains scripts for installing and uninstalling Microsoft Office 2013 products.

### Overview
This contains two PowerShell scripts that will install or uninstall specified Microsoft Office products using user defined Office installation configuration files (*.xml or *.msp). These scripts are intended to be used in GPOs to silently install or uninstall Microsoft Office 2013 products, but could be used in other methods to install or uninstall these products.

### Install-MSOffice
Installs a Microsoft Office Product from a local or network media source.

####Description

Installs a Microsoft Office Product (Office, Office Pro Plus, Visio, Project etc) from a specified media source and using a configuration XML or admin MSP file to configure the installation process.

This script would usually be used in conjunction with a Config.xml or Admin.MSP file that was created to install a Microsoft Office product silently or with specific options.

This script could be combined with the Windows Server 2012 GPO PowerShell Start up Script feature to install a Microsoft Office product on startup.

####Examples
To install a copy of Microsoft Office 2013 Pro Plus from a network software folder using a SilentInstallConfig.xml file with no log file creation:
```powershell
Install-MSOffice -ProductId 'Office15.ProPlus' -SourcePath '\\Server\Software$\MSO2013' -ConfigFile '\\Server\Software$\MSO2013\ProPlus.w\SilentInstallConfig.xml' -LogFile '\\Server\InstallLogFiles\MSO2013\'
```

To install a copy of Microsoft Office 2013 Project from a network software folder using a SilentInstall.msp file with log file creation:
```powershell
Install-MSOffice -ProductId 'Office15.PRJPRO' -SourcePath '\\Server\Software$\MSP2013' -AdminFile '\\Server\Software$\MSP2013\PrjPro.w\SilentInstall.msp' -LogFile '\\Server\InstallLogFiles\MSP2013\'
```

See:
```powershell
Get-Help .\Install-MSOffice.ps1 -Full
```
For more information.


### Uninstall-MSOffice
Installs a Microsoft Office Product from a local or network media source.

####Description
Uninstalls a Microsoft Office Product (Office, Office Pro Plus, Visio, Project etc) from a specified media source and using a configuration XML or admin MSP file to configure the uninstallation process.

This script would usually be used in conjunction with a Config.xml or Admin.MSP file that was created to uninstall a Microsoft Office product silently.

This script could be combined with the Windows Server 2012 GPO PowerShell Start up Script feature to uninstall a Microsoft Office product on startup.

####Examples
Uninstall a copy of Microsoft Office 2013 Pro Plus from a network software folder using a SilentUninstallConfig.xml file with no log file creation:
```powershell
Uninstall-MSOffice -ProductId 'Office15.PROPLUS' -SourcePath '\\Server\Software$\MSO2013' -ConfigFile '\\Server\Software$\MSO2013\ProPlus.ww\SilentUninstallCnfig.xml'
```

See:
```powershell
Get-Help .\Uninstall-MSOffice.ps1 -Full
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
