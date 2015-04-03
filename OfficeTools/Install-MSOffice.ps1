[CmdLetBinding()]
param( 
    [String]
    [ValidateNotNullOrEmpty()]
    $ProductId='Office15.PROPLUS',
 
    [String]
    [Parameter(
            Mandatory=$true
            )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    $DeployPath,
 
    [String]
    [Parameter(
            Mandatory=$true
            )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    $ConfigFile,
 
    [String]
    [ValidateScript({  ( $_ -eq '' ) -or ( Test-Path $_ ) })]
    $LogPath
) # Param
 
# If a Log Path was specified get up a log file name to write to.
If ($LogPath -eq '') {
    [String]$LogFile = ''
} else {
    [String]$LogFile = "$LogPath\$ENV:computername.txt"
} # ($LogPath -eq '')

# If Office needs to be installed (because it isn't already) then set the Install variable to $true.
[Boolean]$Install = $True
If ( $env:PROCESSOR_ARCHITECTURE -eq 'AMD64' ) {
    # Operating system is AMD64
    
    If ( Test-Path -Path "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" ) {
        # 32-bit Office is installed.
        [Boolean]$Install = $False
    } # ( Test-Path -Path "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" )

} # ( $env:PROCESSOR_ARCHITECTURE -eq 'AMD64' )
If ( Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" ) {
    # 32 or 64-bit Office is installed.
    [Boolean]$Install = $False
} # ( Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductId" )
 
# 
If ($Install) { 
    Add-Content -Path $Path -Message "$ProductId Setup started."
    [Int]$ErrorCode = Invoke-Expression "$DeployPath\setup.exe /config $ConfigFile | Out-String"
    If ($ErrorCode -eq 0) {
        Add-LogEntry -Path $Path -Message "$ProductId Setup completed successfully."
    } Else {
        Add-LogEntry -Path $LogFile -Message "$ProductId Setup failed with error code $ErrorCode."
    }
}

Function Add-LogEntry 
{
    Param( 
        [String]
        [Parameter(
            Mandatory=$true
            )]
        $Path,

        [String]
        $Message
    ) # Param
    # Only write log entry if a path was specified
    If ( $Path -ne '' ) {
        Add-Content -Path $Path -Value "$(Get-Date): $Message"
    } # ( $Path -ne '' )
} # Function Add-LogEntry