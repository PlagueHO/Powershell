Powershell
==========

## HyperVTools
This module provides miscellaneous helper functions for Hyper-V Machines.

### Overview
This module contains functions and workflows for optimizing Hyper-V Machines.

#### Workflow Invoke-DSCCheck
Workflow that optimizes all VHD/VHDx files attached to the Hyper-V VMs on a list of computers.

For example:
```powershell
Optimize-VHDsWorkflow -AllowRestart -Mode Full
```

See:
```powershell
Get-Help -Name Optimize-VHDsWorkflow -Full
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
1. Create a folder called HyperVTools in the $home\documents\windowspowershell\modules folder of your profile. E.g.
   C:\Users\Daniel\Documents\WindowsPowerShell\Modueles\DSCTools\
2. Copy the HyperVTools.psm1 and HyperVTools.psd1 files into the folder created above.
3. In PowerShell execute:
```powershell
   Import-Module HyperVTools
```


### Example Usage
```powershell
# Optimize all VHD/VHDxs on VMs DC01,DC02 and DC03 on host HV-01 allowing restart of running VMs using Full Optimization mode
Optimize-VHDsWorkflow -ComputerName HV-01 -Verbose -AllowRestart -VM "DC01","DC02","DC03" -Mode Full

# Optimize all VHD/VHDxs on VMs DC01,DC02 and DC03 on host HV-01 allowing restart of running VMs using Default (quick) Optimization mode
Optimize-VHDsWorkflow -ComputerName HV-01 -Verbose -AllowRestart -VM "DC01","DC02","DC03"

# Optimize all VHD/VHDxs on VMs DC01,DC02 and DC03 on the localhost using Default (quick) Optimization mode
Optimize-VHDsWorkflow -Verbose -AllowRestart -VM "DC01","DC02","DC03"

# Optimize all VHD/VHDxs on all VMs on host HV-01 allowing restart of running VMs using Default (quick) Optimization mode
Optimize-VHDsWorkflow -ComputerName HV-01 -Verbose -AllowRestart

# Optimize all VHD/VHDxs on VMs DC01,DC02 and DC03 on hosts HV-01,HV-02 and HV-03 using Default (quick) Optimization mode
Optimize-VHDsWorkflow -ComputerName HV-01,HV-02,HV-03 -VM "DC01","DC02","DC03" -Verbose

# Optimize all VHD/VHDxs on all VMs on host HV-01 running VMs using Full Optimization mode
Optimize-VHDsWorkflow -ComputerName HV-01 -Verbose -Mode Full
```
