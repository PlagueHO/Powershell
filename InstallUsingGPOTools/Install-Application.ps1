<#
  .SYNOPSIS
  Installs an Application from a local or network media source if a registry key/value is not set.

  .DESCRIPTION
  Installs an Application from a specified media source by executing the setup installer (.EXE) file.
  
  A registry key must also be provided to check for to identify if the application is already installed. Optionally a registry value in the registry key can also be checked for.

  This script would normally be used with the Windows Server 2012 GPO PowerShell Start up Script feature to install a specific application.

  .PARAMETER InstallerPath
  The location of the installation application executable. Can be a local or network path.

  .PARAMETER RegistryKey
  The registry key to check for. If the registry key does not exist then the application will be installed.

  .PARAMETER InstallerParameters
  An optional string parameter containing any installation parameters that should be passed to the installation executable, usually to force an unattended and silent installation.

  .PARAMETER RegistryName
  An optional registry value to check for in the registry key. If the registry key does not contain the registry value with this name then the application will be installed.

  .PARAMETER RegistryValue
  An optional registry value that the registry name in the key must equal. If the registry name value does not match this parameter then the application will be installed.

  .PARAMETER LogPath
  Optional parameter specifying where the installation log file should be written to. If not specified, an installation log file will not be written.
  The installation log file will be named with the name of the computer being installed to.
  
  .EXAMPLE
  Install Notepad++ 6.7.8.2 without creating a logfile:
  Install-Application -InstallerPath '\\server\Software$\Notepad++\npp.6.7.8.2.Installer.exe' -RegistryKey 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++' -RegistryName 'DisplayVersion' -RegistryValue '6.7.8.2' -InstallerParameters '/S'

  Install Notepad++ 6.7.8.2 creating log files for each machine it is installed on in \\Server\Software$\logfiles\ folder:
  Install-Application -InstallerPath '\\server\Software$\Notepad++\npp.6.7.8.2.Installer.exe' -RegistryKey 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++' -RegistryName 'DisplayVersion' -RegistryValue '6.7.8.2' -InstallerParameters '/S' -LogPath \\Server\Software$\logfiles\

  .OUTPUTS

  .NOTES
#>

# AUTHOR
# Daniel Scott-Raynsford
# http://dscottraynsford.wordpress.com/
#
# VERSION
# 1.0   2015-06-30   Daniel Scott-Raynsford       Incomplete Version
#

[CmdLetBinding(
    SupportsShouldProcess=$true
    )]

param( 
    [String]
    [Parameter(
        Position=1,
        Mandatory=$true
        )]
    [ValidateScript({ ($_ -ne '') -and ( Test-Path $_ ) })]
    $InstallerPath,
 
    [String]
    [Parameter(
        Position=2,
		Mandatory=$true
        )]
    [ValidateNotNullOrEmpty()]
    $RegistryKey='',

    [String]
    [Parameter(
        Position=3
        )]
    $InstallerParameters='',

    [String]
    [Parameter(
        Position=4
        )]
    [ValidateNotNullOrEmpty()]
    $RegistryName='',

    [String]
    [Parameter(
        Position=5
        )]
    [ValidateNotNullOrEmpty()]
	$RegistryValue='',

    [String]
    [Parameter(
        Position=6
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
If (($LogPath -eq '') -or ($LogPath -eq $null)) {
    [String]$LogFile = ''
} else {
	[String]$LogFile = Join-Path -Path $LogPath -ChildPath "$($ENV:computername)_$([System.IO.Path]::GetFileNameWithoutExtension($InstallerPath)).txt" 
} # ($LogPath -eq '')

# Perform registry checks to see if app is already installed
[Boolean]$Installed = $False
If ( Test-Path -Path $RegistryKey ) {
	Write-Verbose -Message "Registry Key $RegistryKey found."
    If ( ($RegistryName -ne $null) -and ($RegistryName -ne '') ) {
		Try {
			# Can a Registry Key Property with the name RegistryName be found? If no, then an error will be thrown and 
			$RegProperty = Get-ItemProperty -Path $RegistryKey -Name $RegistryName
			Write-Verbose -Message "Registry Item Property $RegistryName found with value $($RegProperty.$RegistryName)."
			# Does the Registry Key Property Value match registry Value?
			If ($RegProperty.$RegistryName -eq $RegistryValue) {
				# Yes, app is installed.
				[Boolean]$Installed = $True
			}
		} Catch {
			Write-Verbose -Message "Registry Item Property $RegistryName was not found."
			# Registry Key Property not found so not installed.
		} # Try
	} Else {
		# Only Registry Key was provided for check so app is installed.
		[Boolean]$Installed = $True
	} # ( ($RegistryName -eq $null) -or ($RegistryName -eq '') )
} # ( Test-Path -Path $RegistryKey )

# This application is not installed - so install it.
If (-not $Installed) { 
    [String]$Command="$InstallerPath $InstallerParameters"

    Add-LogEntry -Path $LogFile -Message "Install Application using $Command started."
    If ($PSCmdlet.ShouldProcess("Install Application using $Command started")) {
        # Call the product Install.
        & cmd.exe /c "$Command"
        [Int]$ErrorCode = $LASTEXITCODE
    } # ShouldProcess
    Switch ($ErrorCode) {
		0 { Add-LogEntry -Path $LogFile -Message "Install $Type using $Command completed successfully." }
		1641 { Add-LogEntry -Path $LogFile -Message "Install $Type using $Command completed successfully and computer is rebooting." }
		default { Add-LogEntry -Path $LogFile -Message "Install $Type using $Command failed with error code $ErrorCode." }
    } # ($ErrorCode)
} Else {
    Write-Verbose -Message "Application is already installed."
} # (-not $Installed)
