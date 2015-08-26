# Customizable Parameters - Customize them!
$AdminPassword = 'P@ssword01!'
$WorkPath = "D:\Temp"
$IPAddress = '192.168.1.93'
$ComputerName = 'NS_Containers'
$VMPath = "c:\VM\Nano Servers"
$VMSwitchName = "General Purpose External"
$TP3ISOPath = "D:\ISOs\Windows Server 2016 TP3\10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO"

# Don't change these...
$NanoServerWIMPath = "$WorkPath\NanoServer.wim"
$NSSMPath = "$WorkPath\NSSM.zip"

New-Item -Path "$VMPath\$ComputerName\Virtual Hard Disks\" -Force -ItemType Directory

Mount-DiskImage -ImagePath $TP3ISOPath
[String]$DriveLetter = (Get-Diskimage -ImagePath $TP3ISOPath | Get-Volume).DriveLetter
Copy-Item -Path "$($DriveLetter):\NanoServer\NanoServer.wim" -Destination $NanoServerWIMPath -Force
Set-ItemProperty -Path $NanoServerWIMPath -Name IsReadOnly -Value $False
Dismount-DiskImage -ImagePath $TP3ISOPath

# Create the Container Host VM
Set-Location $WorkPath
.\New-NanoServerVHD.ps1 `
    -ServerISO $TP3ISOPath `
    -DestVHD "$VMPath\$ComputerName\Virtual Hard Disks\Boot.vhdx" `
    -VHDFormat VHDx `
    -Packages OEM-Drivers,Guest,Compute,Containers `
    -AdministratorPassword 'P@ssword01!' `
    -ComputerName $ComputerName `
    -Edition "CORESYSTEMSERVER_INSTALL" `
    -IPAddress $IPAddress
New-VM -Name $ComputerName -SwitchName $VMSwitchName -VHDPath "$VMPath\$ComputerName\Virtual Hard Disks\Boot.vhdx" -Path $VMPath -Generation 2
Start-VM -Name $ComputerName

# Install Chocolatey
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Docker
choco install docker 

# Download NSSM
wget -Uri "http://nssm.cc/release/nssm-2.24.zip" -Outfile $NSSMPath -UseBasicParsing
New-Item -Path "$WorkPath\NSSM" -ItemType Directory -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $NSSMPath -DestinationPath "$WorkPath\NSSM\" -Force

# Set Credentials
$secpasswd = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

# Connect to Container Host
$Session = New-PSSession -ComputerName $IPAddress -Credential $mycreds

# Copy the NanoServer.WIM and Docker.Exe to the Container Host
Copy-Item -Path $NanoServerWIMPath -Destination c:\Users\Administrator\Documents\ -ToSession $Session
Copy-Item -Path C:\ProgramData\chocolatey\lib\docker\bin\Docker.exe -Destination c:\Windows\System32 -ToSession $Session
Copy-Item -Path "$WorkPath\NSSM\nssm-2.24\win64\nssm.exe" -Destination c:\Windows\System32\ -ToSession $Session

# Run the install script
Invoke-Command -Session $Session -FilePath .\Install-ContainerHostNano.ps1