<#
    .NOTES
    
    .SYNOPSIS
        Uninstalls a Microsoft Office Product from a local or network media source.

    .DESCRIPTION
        Uninstalls a Microsoft Office Product (Office, Office Pro Plus, Visio, Project etc) from a specified media source and using
        a configuration XML or admin MSP file to configure the uninstallation process.

        This script would usually be used in conjunction with a Config.xml or Admin.MSP file that was created to uninstall a Microsoft Office
        product silently.

        This script could be combined with the Windows Server 2012 GPO PowerShell Start up Script feature to uninstall a Microsoft Office product on startup.
        
    .PARAMETER ProductId
        The Microsoft Office Product Id to uninstall. This must match the installation files for the product referred to in the SourcePath parameter.
        Defaults to 'Office15.PROPLUS'.

    .PARAMETER SourcePath
        The location of the installation source files. Can be a local or network path.

    .PARAMETER ConfigFile
        The location of the config XML file to use to control the product uninstallation. Should be specified if the AdminFile parameter is passed.

    .PARAMETER AdminFile
        The location of the admin MSP file to use to control the product uninstallation. Should be specified if the ConfigFile parameter is passed.

    .PARAMETER LogPath
        Optional parameter specifying where the uninstallation log file should be written to. If not specified, an uninstallation log file will not be written.
        The uninstallation log file will be named with the name of the computer being uninstalled from.
  
    .EXAMPLE
    To uninstall a copy of Microsoft Office 2013 Pro Plus from a network software folder using a SilentUninstallConfig.xml file with no log file creation:
    Uninstall-MSOffice -ProductId 'Office15.PROPLUS' -SourcePath '\\Server\Software$\MSO2013' -ConfigFile '\\Server\Software$\MSO2013\ProPlus.ww\SilentUninstallCnfig.xml'


    .EXAMPLE
    To uninstall a copy of Microsoft Office 2013 Project from a network software folder using a SilentInstall.msp file with log file creation:
    Uninstall-MSOffice -ProductId 'Office15.PRJPRO' -SourcePath '\\Server\Software$\MSP2013' -AdminFile '\\Server\Software$\MSP2013\PrjPro.ww\SilentUninstall.msp' -LogFile '\\Server\InstallLogFiles\MSP2013\'

    .OUTPUTS
      
#>
#Requires -Version 2.0
[CmdLetBinding()]
param( 
    [String]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ($_ -split '\.').Count -gt 1 })]
    $ProductId='Office15.PROPLUS',
 
    [String]
    [Parameter(
            Mandatory=$true
            )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    $SourcePath,
 
    [String]
    [Parameter(
            ParameterSetName='ConfigFile'
            )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    $ConfigFile,
 
    [String]
    [Parameter(
            ParameterSetName='AdminFile'
            )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    $AdminFile,

    [String]
    [ValidateScript({  ( $_ -eq '' ) -or ( Test-Path $_ ) })]
    $LogPath
) # Param

Function Add-LogEntry ( [String]$Path ,[String]$Message)
{
    # Only write log entry if a path was specified
    If ( $Path -ne '' ) {
        Add-Content -Path $Path -Value "$(Get-Date): $Message"
    } # ( $Path -ne '' )
} # Function Add-LogEntry

# If a Log Path was specified get up a log file name to write to.
If ($LogPath -eq '') {
    [String]$LogFile = ''
} else {
    [String]$LogFile = Join-Path -Path $LogPath -ChildPath $ENV:computername+'.txt' 
} # ($LogPath -eq '')

[String]$ProductCode=($ProductId -split '\.')[1]
# Is this Office Product already Installed?
[Boolean]$Installed = $False
If ( $env:PROCESSOR_ARCHITECTURE -eq 'AMD64' ) {
    # Operating system is AMD64
    
    If ( Test-Path -Path "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" ) {
        # 32-bit Office is installed.
        [Boolean]$Installed = $True
    } # ( Test-Path -Path "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" )

} # ( $env:PROCESSOR_ARCHITECTURE -eq 'AMD64' )
If ( Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" ) {
    # 32 or 64-bit Office is installed.
    [Boolean]$Installed = $True
} # ( Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" )
 
# This Office Product is already installed - so uninstall it.
If ($Installed) { 
    If ($ConfigFile -eq '') {
        Add-LogEntry -Path $Path -Message "$ProductId Uninstall from $SourcePath with /admin $AdminFile started."
        [Int]$ErrorCode = Invoke-Expression "$(Join-Path -Path $SourcePath -ChildPath 'setup.exe') /uninstall $Product /admin $AdminFile | Out-String"
    } Else {
        Add-LogEntry -Path $Path -Message "$ProductId Uninstall from $SourcePath with /config $ConfigFile started."
        [Int]$ErrorCode = Invoke-Expression "$(Join-Path -Path $SourcePath -ChildPath 'setup.exe') /config $ConfigFile | Out-String"
    } #  ($ConfigFile -eq '')
    If ($ErrorCode -eq 0) {
        Add-LogEntry -Path $Path -Message "$ProductId Uninstall from $SourcePath completed successfully."
    } Else {
        Add-LogEntry -Path $LogFile -Message "$ProductId Uninstall from $SourcePath failed with error code $ErrorCode."
    } # ($ErrorCode -eq 0)
} # ($Installed)
