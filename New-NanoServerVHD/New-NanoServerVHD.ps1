<#   
    .SYNOPSIS
        Creates a bootable VHD containing Windows Server Nano 2016.

    .DESCRIPTION
        Creates a bootable VHD containing Windows Server Nano 2016 using the publically available Windows Server 2016 Technical Preview 2 ISO.

		This script needs the Convert-WindowsImage.ps1 script to be in the same folder. It can be downloaded from:
		https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f

        This function turns the instructions on the following link into a repeatable script:
        https://technet.microsoft.com/en-us/library/mt126167.aspx

        Plesae see the link for additional information.

		This script can be found:
		Github Repo: https://github.com/PlagueHO/Powershell/tree/master/New-NanoServerVHD

    .PARAMETER ServerISO
    This is the path to the Windows Server 2016 Technical Preview 2 ISO downloaded from:
    https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

    .PARAMETER DestVHD
    This is the path and name of the new Nano Server VHD.

    .PARAMETER Packages
    This is a list of the packages to install in this Nano Server. There are only 6 available currently:
    Compute = Hyper-V Server
    OEM-Drivers = Standard OEM Drivers
    Storage = Storage Server
    FailoverCluster = FailOver Cluster Server
    ReverseForwarders = ReverseForwarders to allow some older App Servers to run
    Guest = Hyper-V Guest Tools

    If not specified then packages OEM-Drivers, Storage and Guest packages are installed.

    .PARAMETER ComputerName
    This is the Computer Name for the new Nano Server (if the default Unattended.XML is used).

    .PARAMETER AdministratorPassword
    This is the Administrator account password for the new Nano Server (if the default Unattended.XML is used).

    .PARAMETER IPAddress
    This is a Static IP address to assign to the first ethernet card in this Nano Server. If not passed it will use DHCP.

    .PARAMETER RegisteredOwner
    This is the Registered Owner that will be set for the Nano Server (if the default Unattended.XML is used).

    .PARAMETER RegisteredCorporation
    This is the Registered Corporation name that will be set for the Nano Server (if the default Unattended.XML is used).

    .PARAMETER UnattendedContent
    Allows the content of the Unattended.XML file to be overridden. Provide the content of a new Unattended.XML file in this parameter.

    .EXAMPLE
        .\New-NanoServerVHD.ps1 `
            -ServerISO 'D:\ISOs\Windows Server 2016 TP2\10074.0.150424-1350.fbl_impressive_SERVER_OEMRET_X64FRE_EN-US.ISO' `
            -DestVHD D:\Temp\NanoServer01.vhd `
            -ComputerName NANOTEST01 `
            -AdministratorPassword 'P@ssword!1' `
            -Packages 'Storage','OEM-Drivers','Guest' `
            -IPAddress '192.168.1.65' `
            -Verbose

        This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Storage, OEM-Drivers and Guest packages.
		It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 192.168.1.65.

    .LINK
    https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

    .LINK
    https://technet.microsoft.com/en-us/library/mt126167.aspx
#>
#Requires -Version 4.0

[CmdLetBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -Path $_ })]
    [String]$ServerISO,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$DestVHD,

    [ValidateSet('Compute','OEM-Drivers','Storage','FailoverCluster','ReverseForwarders','Guest')]
    [String[]]$Packages = @('OEM-Drivers','Storage','Guest'),

    [ValidateNotNullOrEmpty()]
    [String]$ComputerName = "NanoServer01",

    [Parameter(
        Mandatory = $true,
        HelpMessage="Enter the Administrator password of the new Nano Server."
        )]
        [String]$AdministratorPassword,

    [ValidateNotNullOrEmpty()]
    [String]$IPAddress,

    [ValidateNotNullOrEmpty()]
    [String]$RegisteredOwner = "Nano Server User",

    [ValidateNotNullOrEmpty()]
    [String]$RegisteredCorporation = "Contoso",

    [ValidateNotNullOrEmpty()]
    [String]$UnattendedContent
    
)

If (-not (Test-Path -Path .\Convert-WindowsImage.ps1 -PathType Leaf)) {
	Write-Error "The Convert-WindowsImage.ps1 script was not found in the current folder. Please download it from https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f"
	Return
}
[String]$WorkFolder = Join-Path -Path $ENV:Temp -ChildPath 'NanoServer' 
[String]$DismFolder = Join-Path -Path $WorkFolder -ChildPath "DISM"
[String]$MountFolder = Join-Path -Path $WorkFolder -ChildPath "Mount"
[String]$VHDType = 'VHD'
[String]$TempVHDName = "NanoServer.$VHDType"

# Create working folder
Write-Verbose 'Creating Working Folders'
If (-not (Test-Path -Path $WorkFolder -PathType Container)) {
    New-Item -Path $WorkFolder -ItemType Directory
}

# Mount the Windows Server 2016 ISO and get the drive letter
Write-Verbose 'Mounting Server ISO'
Mount-DiskImage -ImagePath $ServerISO
[String]$DriveLetter = (Get-Diskimage -ImagePath $ServerISO | Get-Volume).DriveLetter

# Copy DISM off the Windows ISO and put it into the working folder.
Write-Verbose 'Copying DISM from Server ISO to Working Folders'
If (-not (Test-Path -Path $DismFolder -PathType Container)) {
    New-Item -Path $DismFolder -ItemType Directory
}
Copy-Item -Path "$($DriveLetter):\Sources\api*downlevel*.dll" -Destination $DismFolder -Force
Copy-Item -Path "$($DriveLetter):\Sources\*dism*" -Destination $DismFolder -Force
Copy-Item -Path "$($DriveLetter):\Sources\*provider*" -Destination $DismFolder -Force

# Use Convert-WindowsImage.ps1 to convert the NanoServer.WIM into a VHD
Write-Verbose 'Creating base Nano Server Image from WIM file'
.\Convert-WindowsImage.ps1 -Sourcepath "$($DriveLetter):\NanoServer\NanoServer.wim" -VHD (Join-Path -Path $WorkFolder -ChildPath $TempVHDName ) –VHDformat $VHDType -Edition 1

If (-not (Test-Path -Path $MountFolder -PathType Container)) {
    New-Item -Path $MountFolder -ItemType Directory
}

# Mount the VHD to load packages into it
& "$DismFolder\Dism.exe" "/Mount-Image" "/ImageFile:$WorkFolder\$TempVHDName" "/Index:1" "/MountDir:$MountFolder"

# Add the basic packages
If ('Compute' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-NanoServer-Compute-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-Compute-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-us\Microsoft-NanoServer-Compute-Package.cab" "/Image:$MountFolder"
}
If ('OEM-Drivers' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-NanoServer-OEM-Drivers-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-OEM-Drivers-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-US\Microsoft-NanoServer-OEM-Drivers-Package.cab" "/Image:$MountFolder"
}

# Packages for Failover Cluster
If ('FailoverCluster' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-NanoServer-FailoverCluster-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-FailoverCluster-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-US\Microsoft-NanoServer-FailoverCluster-Package.cab" "/Image:$MountFolder"
}

# Packages for Storage Server
If ('Storage' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-NanoServer-Storage-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-Storage-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-US\Microsoft-NanoServer-Storage-Package.cab" "/Image:$MountFolder"
}

# Packages required to support some products not yet compiled with Nano Support built in.
If ('ReverseForwarders' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-OneCore-ReverseForwarders-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-OneCore-ReverseForwarders-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-US\Microsoft-OneCore-ReverseForwarders-Package.cab" "/Image:$MountFolder"
}

# These are the packages to run the Nano server in a Hyper-V VM.
If ('Guest' -in $Packages) {
    Write-Verbose 'Adding Package Microsoft-NanoServer-Guest-Package.cab to Image'
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-Guest-Package.cab" "/Image:$MountFolder"
    & "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-US\Microsoft-NanoServer-Guest-Package.cab" "/Image:$MountFolder"
}

# Apply Unattended File
If (($UnattendedContent -eq $null) -or ($UnattendedContent -eq '')) {
# For some reason applying computername in the Offline Servicing Phase doesn't work
# So it can be applied in the Specialize phase...

$UnattendedContent = [String] @"
<?xml version='1.0' encoding='utf-8'?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <settings pass="offlineServicing">
    <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$ComputerName</ComputerName>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserAccounts>
        <AdministratorPassword>
           <Value>$AdministratorPassword</Value>
           <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <TimeZone>Pacific Standard Time</TimeZone>
    </component>
  </settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$ComputerName</ComputerName>
      <RegisteredOwner>$RegisteredOwner</RegisteredOwner>
      <RegisteredOrganization>$RegisteredCorporation</RegisteredOrganization>
    </component>
  </settings>
</unattend>
"@
}

Write-Verbose 'Assigning Unattended.XML file to Nano Server'
$UnattendFile = Join-Path -Path $WorkFolder -ChildPath 'Unattend.xml'
Set-Content -Path $UnattendFile -Value $UnattendedContent
& "$DismFolder\Dism.exe" "/Image:$MountFolder" "/Apply-Unattend:$UnattendFile"
New-Item -Path "$MountFolder\windows\panther" -ItemType Directory
Copy-Item -Path $UnattendFile -Destination "$MountFolder\windows\panther"

If ($IPaddress -ne $null) {
	# Set a static IP Address on the machine
    $SetupComplete += 'powershell.exe -command "Import-Module C:\windows\system32\windowspowershell\v1.0\Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1; Import-Module C:\windows\system32\WindowsPowerShell\v1.0\Modules\NetAdapter\NetAdapter.psd1; $ifa = (Get-NetAdapter -Name Ethernet).ifalias; netsh interface ip set address $ifa static ' + $IPaddress + '"'
    New-Item "$MountFolder\Windows\Setup\Scripts" -ItemType Directory
    Set-Content -Path "$MountFolder\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete
}

# Dismount the image after adding the Packages to it and configuring it
Write-Verbose 'Dismounting Nano Server Image'
& "$DismFolder\Dism.exe" "/Unmount-Image" "/MountDir:$MountFolder" "/Commit"

# Dismount the ISO File
Write-Verbose 'Dismounting Server ISO'
Dismount-DiskImage -ImagePath $ServerISO

Write-Verbose "Moving Nano Server Image to $DestVHD"
Copy-Item -Path $WorkFolder\$TempVHDName -Destination $DestVHD -Force

# Cleanup
Write-Verbose 'Cleaning up Working Folders'
Remove-Item -Path $MountFolder -Recurse -Force
Remove-Item -Path $DismFolder -Recurse -Force
Remove-Item -Path $WorkFolder -Recurse -Force