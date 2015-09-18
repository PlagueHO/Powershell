<#   
	.SYNOPSIS
		Creates a bootable VHD/VHDx containing Windows Server Nano 2016.

	.DESCRIPTION
		Creates a bootable VHD/VHDx containing Windows Server Nano 2016 using the publically available Windows Server 2016 Technical Preview 3 ISO.

		This script needs the Convert-WindowsImage.ps1 script to be in the same folder. It can be downloaded from:
		https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f

		This function turns the instructions on the following link into a repeatable script:
		https://technet.microsoft.com/en-us/library/mt126167.aspx

		Plesae see the link for additional information.

		This script can be found:
		Github Repo: https://github.com/PlagueHO/Powershell/tree/master/New-NanoServerVHD

	.PARAMETER ServerISO
	This is the path to the Windows Server 2016 Technical Preview 3 ISO downloaded from:
	https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

	.PARAMETER DestVHD
	This is the path and name of the new Nano Server VHD.

	.PARAMETER VHDFormat
	Specifies whether to create a VHD or VHDX formatted Virtual Hard Disk. The default is VHD.

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

	.PARAMETER SubnetMask
	This is the the subnet mask to use with the static IP address to assign to the first ethernet card
    in this Nano Server. Should only be passed if IPAddress is provided. Defaults to 255.255.255.0. 

	.PARAMETER GatewayAddress
	This is the gateway IP address to assign to the first ethernet card in this Nano Server if static IP Address is 
    being used. Should only be passed if IPAddress is provided.

	.PARAMETER DNSAddresses
	These are the DNS Serverer addresses to assign to the first ethernet card in this Nano Server if static IP Address 
    is being used. Should only be passed if IPAddress is provided.

	.PARAMETER RegisteredOwner
	This is the Registered Owner that will be set for the Nano Server (if the default Unattended.XML is used).

	.PARAMETER RegisteredCorporation
	This is the Registered Corporation name that will be set for the Nano Server (if the default Unattended.XML is used).

	.PARAMETER UnattendedContent
	Allows the content of the Unattended.XML file to be overridden. Provide the content of a new Unattended.XML file in this parameter.

	.PARAMETER Edition
	This is the index name of the edition to install from the NanoServer.WIM. It defaults to CORESYSTEMSERVER_INSTALL and should
	not usually be changed.

	As of TP3, there are two editions found inside the NanoServer.WIM:
	CORESYSTEMSERVER_INSTALL
	CORESYSTEMSERVER_BOOT

	.EXAMPLE
		.\New-NanoServerVHD.ps1 `
			-ServerISO 'D:\ISOs\Windows Server 2016 TP3\10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO' `
			-DestVHD D:\Temp\NanoServer01.vhd `
			-ComputerName NANOTEST01 `
			-AdministratorPassword 'P@ssword!1' `
			-Packages 'Storage','OEM-Drivers','Guest' `
			-IPAddress '10.0.0.20' `
            -SubnetMask '255.0.0.0' `
            -GatewayAddress '10.0.0.1' `
            -DNSAddresses '10.0.0.2','10,0,0,3'
			-Verbose

		This command will create a new VHD containing a Nano Server machine with the name NANOTEST01. It will contain only the Storage, OEM-Drivers and Guest packages.
		It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 10.0.0.20/255.0.0.0 with gateway of 10.0.0.1 and DNS
        set to '10.0.0.2','10,0,0,3'

	.EXAMPLE
		.\New-NanoServerVHD.ps1 `
			-ServerISO 'D:\ISOs\Windows Server 2016 TP3\10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US' `
			-DestVHD D:\Temp\NanoServer02.vhdx `
			-VHDFormat VHDX `
			-ComputerName NANOTEST02 `
			-AdministratorPassword 'P@ssword!1' `
			-Packages 'Storage','OEM-Drivers','Guest' `
			-IPAddress '192.168.1.66' `
			-Verbose

		This command will create a new VHDx (for Generation 2 VMs) containing a Nano Server machine with the name NANOTEST02. It will contain only the Storage, OEM-Drivers and Guest packages.
		It will set the Administrator password to P@ssword!1 and set the IP address of the first ethernet NIC to 192.168.1.66/255.255.255.0 with no Gateway or DNS.

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

	[ValidateNotNullOrEmpty()]
	[ValidateSet("VHD", "VHDX")]
	[String]$VHDFormat  = "VHD",

	[ValidateSet('Compute','OEM-Drivers','Storage','FailoverCluster','ReverseForwarders','Guest','Containers','Defender')]
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
	[String]$SubnetMask='255.255.255.0',

	[ValidateNotNullOrEmpty()]
	[String]$GatewayAddress,

	[ValidateNotNullOrEmpty()]
	[String[]]$DNSAddresses,

	[ValidateNotNullOrEmpty()]
	[String]$RegisteredOwner = "Nano Server User",

	[ValidateNotNullOrEmpty()]
	[String]$RegisteredCorporation = "Contoso",

	[ValidateNotNullOrEmpty()]
	[String]$UnattendedContent,

	[ValidateNotNullOrEmpty()]
	[String]$Edition = 'CORESYSTEMSERVER_INSTALL'
)

If (-not (Test-Path -Path .\Convert-WindowsImage.ps1 -PathType Leaf)) {
	Write-Error "The Convert-WindowsImage.ps1 script was not found in the current folder. Please download it from https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f"
	Return
}

# Generate the file content for the Setup Complete script that runs on the VM
# Do this first because we can do address validation at the same time.
[String]$SetupComplete = "@ECHO OFF`n"
If ($IPaddress) {
    if(!([System.Net.Ipaddress]::TryParse($IPaddress, [ref]0))) {
        Throw "The IP Address '$IPaddress' is not in a valid format"
    }
    # Defining these as variables in case at some point need to allow them to be overridden.
    $InterfaceAlias = 'Ethernet'
    $AddressFamiyly = 'IPv4'
    # For some reason setting this stuff via powershell doesn't work - so use NETSH.    
    If ($GatewayAddress) {
        if(!([System.Net.Ipaddress]::TryParse($GatewayAddress, [ref]0))) {
            Throw "The Gateway Address '$GatewayAddress' is not in a valid format"
        }
        $IPAddressConfigString += "netsh interface ip set address $InterfaceAlias static addr=$IPaddress mask=$SubnetMask gateway=$GatewayAddress`n"
    } else {
        $IPAddressConfigString += "netsh interface ip set address $InterfaceAlias static addr=$IPaddress mask=$SubnetMask`n"
    }
    If ($DNSAddresses) {
        $Count = 1
        foreach ($DNSAddress in $DNSAddresses) {
            if(!([System.Net.Ipaddress]::TryParse($DNSAddress, [ref]0))) {
                Throw "The DNS Server Address '$DNSAddress' is not in a valid format"
            }
            If ($Count -eq 1) {
                $IPAddressConfigString += "netsh interface ip set dns $InterfaceAlias static addr=$DNSAddress`n"
            } Else {
                $IPAddressConfigString += "netsh interface ip add dns $InterfaceAlias addr=$DNSAddress index=$Count`n"
            }
            $Count++
        }
    }
	# Set a static IP Address on the machine
	$SetupComplete += $IPAddressConfigString
} # If

[String]$WorkFolder = Join-Path -Path $ENV:Temp -ChildPath 'NanoServer' 
[String]$DismFolder = Join-Path -Path $WorkFolder -ChildPath "DISM"
[String]$MountFolder = Join-Path -Path $WorkFolder -ChildPath "Mount"
[String]$TempVHDName = "NanoServer.$VHDFormat"
Switch ($VHDFormat) {
	'VHD' { [String]$VHDPartitionStyle = 'MBR' }
	'VHDx' { [String]$VHDPartitionStyle = 'GPT' }
}

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

# As of 2015-06-16 Convert-WindowsImage contains a function instead of being a standalone script.
# . source the Convert-WindowsImage.ps1 so it can be called
. .\Convert-WindowsImage
Convert-WindowsImage -Sourcepath "$($DriveLetter):\NanoServer\NanoServer.wim" -VHD (Join-Path -Path $WorkFolder -ChildPath $TempVHDName ) –VHDFormat $VHDFormat -Edition $Edition -VHDPartitionStyle $VHDPartitionStyle

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

# Packages for Containers
If ('Containers' -in $Packages) {
	Write-Verbose 'Adding Package Microsoft-NanoServer-Containers-Package.cab to Image'
	& "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-Containers-Package.cab" "/Image:$MountFolder"
	& "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-us\Microsoft-NanoServer-Containers-Package.cab" "/Image:$MountFolder"
}

# Packages for Defender
If ('Defender' -in $Packages) {
	Write-Verbose 'Adding Package Microsoft-NanoServer-Defender-Package.cab to Image'
	& "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\Microsoft-NanoServer-Defender-Package.cab" "/Image:$MountFolder"
	& "$DismFolder\Dism.exe" "/Add-Package" "/PackagePath:$($DriveLetter):\NanoServer\packages\en-us\Microsoft-NanoServer-Defender-Package.cab" "/Image:$MountFolder"
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
	<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
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

# Write the Setup Complete script to the image
New-Item "$MountFolder\Windows\Setup\Scripts" -ItemType Directory
Set-Content -Path "$MountFolder\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupComplete

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