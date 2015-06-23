<#
  .SYNOPSIS
  Installs a Microsoft Office Product from a local or network media source.

  .DESCRIPTION
  Installs a Microsoft Office Product (Office, Office Pro Plus, Visio, Project etc) from a specified media source and using
  a configuration XML or admin MSP file to configure the installation process.

  This script would usually be used in conjunction with a Config.xml or Admin.MSP file that was created to install a Microsoft Office
  product silently or with specific options.

  This script could be combined with the Windows Server 2012 GPO PowerShell Start up Script feature to install a Microsoft Office product on startup.
        
  .PARAMETER ProductId
  The Microsoft Office Product Id to install. This must match the installation files for the product referred to in the SourcePath parameter.
  Defaults to 'Office15.PROPLUS'.

  .PARAMETER SourcePath
  The location of the installation source files. Can be a local or network path.

  .PARAMETER NoConfig
  Use this switch to prevent the requirement for a Config or Admin file to be specified to control the product installation. Should not be specified
  if the ConfigFile or AdminFile parameters are set. 

  .PARAMETER ConfigFile
  The location of the config XML file to use to control the product installation. Should not be specified if the AdminFile or NoConfig parameter is set.
  Must contain a valid config file with an XML extension.

  .PARAMETER AdminFile
  The location of the admin MSP file to use to control the product installation. Should not be specified if the ConfigFile or NoConfig parameter is set.
  Must contain a valid admin file with an MSP extension.

  .PARAMETER LogPath
  Optional parameter specifying where the installation log file should be written to. If not specified, an installation log file will not be written.
  The installation log file will be named with the name of the computer being installed to.
  
  .EXAMPLE
  To install a copy of Microsoft Office 2013 Pro Plus from a network software folder using a SilentInstallConfig.xml file with no log file creation:
  Install-MSOffice -ProductId 'Office15.PROPLUS' -SourcePath '\\Server\Software$\MSO2013' -ConfigFile '\\Server\Software$\MSO2013\ProPlus.ww\SilentInstallCnfig.xml'

  .EXAMPLE
  To install a copy of Microsoft Office 2013 Project from a network software folder using a SilentInstall.msp file with log file creation:
  Install-MSOffice -ProductId 'Office15.PRJPRO' -SourcePath '\\Server\Software$\MSP2013' -AdminFile '\\Server\Software$\MSP2013\ProPlus.ww\SilentInstall.msp' -LogFile '\\Server\InstallLogFiles\MSP2013\'

  .OUTPUTS

  .NOTES
#>

# AUTHOR
# Daniel Scott-Raynsford
# http://dscottraynsford.wordpress.com/
#
# VERSION
# 1.0   2015-04-05   Daniel Scott-Raynsford       Initial Version
#
# REQUIRES
# Office 2013, Office 2013 Pro Plus, Office 2013 Project, Office 2013 Visio


[CmdLetBinding(
    SupportsShouldProcess=$true
    )]

param( 
    [String]
    [Parameter(
        Position=1
        )]
    [ValidateScript({ ($_ -ne '') -and ($_ -split '\.').Count -gt 1 })]
    $ProductId='Office15.PROPLUS',
 
    [String]
    [Parameter(
        Position=2,
        Mandatory=$true
        )]
    [ValidateScript({ ($_ -ne '') -and ( Test-Path $_ ) })]
    $SourcePath,
 
    [Switch]
    [Parameter(
        Position=3,
        ParameterSetName='NoConfig'
        )]
    $NoConfig,

    [String]
    [Parameter(
        Position=3,
        ParameterSetName='ConfigFile'
        )]
    [ValidateScript({ ($_ -ne '') -and ( Test-Path $_ ) -and ( [System.IO.Path]::GetExtension($_) -eq '.xml' ) })]
    $ConfigFile='',
 
    [String]
    [Parameter(
        Position=3,
        ParameterSetName='AdminFile'
        )]
    [ValidateScript({ ($_ -ne '') -and  ( Test-Path $_ ) -and ( [System.IO.Path]::GetExtension($_) -eq '.msp' )  })]
    $AdminFile='',

    [String]
    [Parameter(
        Position=4
        )]
    [ValidateScript({ ( $_ -ne '' ) -and ( Test-Path $_ ) })]
    $LogPath
) # Param
 
Function Add-LogEntry ( [String]$Path ,[String]$Message)
{
    Write-Verbose -Message $Message
    # Only write log entry if a path was specified
    If ( $Path -ne '' ) {
        Add-Content -Path $Path -Value "$(Get-Date): $Message"
    } # ( $Path -ne '' )
} # Function Add-LogEntry

# If a Log Path was specified get up a log file name to write to.
If ($LogPath -eq '') {
    [String]$LogFile = ''
} else {
    [String]$LogFile = Join-Path -Path $LogPath -ChildPath "$($ENV:computername).txt" 
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
 
# This Office Product is not already installed - so install it.
If (-not $Installed) { 
    # Sort out the command that will be used to uinstall the product.
    [String]$Command="$(Join-Path -Path $SourcePath -ChildPath 'setup.exe')"
    If ($ConfigFile -ne '') {
        [String]$Command+=" /config $ConfigFile"
    } ElseIf ($AdminFile -ne '') {
        [String]$Command+=" /adminfile $AdminFile"
    }
    Add-LogEntry -Path $LogFile -Message "Install $ProductId using $Command started."
    If ($PSCmdlet.ShouldProcess("Install $ProductId using $Command started")) {
        # Call the product Install.
        & cmd.exe /c "$Command"
        [Int]$ErrorCode = $LASTEXITCODE
    } # ShouldProcess
    If ($ErrorCode -eq 0) {
        Add-LogEntry -Path $LogFile -Message "Install $ProductId using $Command completed successfully."
    } Else {
        Add-LogEntry -Path $LogFile -Message "Install $ProductId using $Command failed with error code $ErrorCode."
    } # ($ErrorCode -eq 0)
} Else {
    Write-Verbose -Message "$ProductId is already installed."
} # (-not $Installed)
