$Files = @(
	@{ Filename = 'Install-Application.ps1'; };
	@{ Filename = 'Install-Update.ps1' };
	@{ Filename = 'README.md' };
)

##########################################################################################################################################
# Support Functions
##########################################################################################################################################
Function InitZip
{
	# If PS is version 4 or less then we require the PSCX Module to unzip/zip files
	If ($PSVersionTable.PSVersion.Major -lt 5) {
		# Is the PSCX Module Available? 
        If ( (Get-Module -ListAvailable PSCX | Measure-Object).Count -eq 0) {
            Throw "PSCX Module is not available. Please download it from http://pscx.codeplex.com/"
        } # If
        Import-Module PSCX	
	} # If
} # Function InitZip
##########################################################################################################################################

##########################################################################################################################################
Function UnzipFile ([String]$ZipFileName,[String]$DestinationPath)
{
	If ($PSVersionTable.PSVersion.Major -lt 5) {
		Expand-Archive -Path $ZipFileName -OutputPath $DestinationPath
	} Else {
		Expand-Archive -Path $ZipFileName -DestinationPath $DestinationPath -Force
	} # If
} # Function UnzipFile
##########################################################################################################################################

##########################################################################################################################################
Function ZipFolder ([String]$ZipFileName,[String]$SourcePath)
{
	If ($PSVersionTable.PSVersion.Major -lt 5) {
        Get-ChildItem -Path $SourcePath -Recurse | Write-Zip -IncludeEmptyDirectories -OutputPath $ZipFileName -EntryPathRoot $SourcePath -Level 9
	} Else {
		Compress-Archive -DestinationPath $ZipFileName -Path "$SourcePath\*" -CompressionLevel Optimal
	} # If
} # Function ZipFolder
##########################################################################################################################################

##########################################################################################################################################
Function Package-Module
{
<#
.SYNOPSIS
		Packages the files required for distributing a module.

.DESCRIPTION 
		All this function does is zip up the files required to be distributed with the a module.

		If PS 4 is used then this function requires the PSCX module to be available and installed on this computer.

 .LINK
		http://pscx.codeplex.com/
#>
    Param (
        [String]$Name
    ) # Params

    Begin {
		# Initialize the zip functions
		InitZip

		[String]$TempPath = "$Env:TEMP\Package\"
		New-Item -Path $TempPath -ItemType 'Directory' -Force | Out-Null
        New-Item -Path "$TempPath\$Name" -ItemType 'Directory' -Force | Out-Null
    } # Begin

    Process {
		Foreach ($File In $Files) {
			If ($File.Filename.Substring($File.Filename.Length-1,1) -eq '\') { 
                New-Item -Path "$TempPath\$Name\$($File.Filename)" -ItemType Directory -Force | Out-Null
            } Else {
                Copy-Item -Path "$PSScriptRoot\$($File.Filename)" -Destination "$TempPath\$Name\$($File.Filename)" -Force
            } # If
		} # Foreach
        New-Item -Path "$PSScriptRoot\Package" -ItemType Directory -Force
        If (Test-Path -Path "$PSScriptRoot\Package\$Name.zip" ) { Remove-Item -Path "$PSScriptRoot\Package\$Name.zip" -Force | Out-Null }
        ZipFolder -ZipFileName "$PSScriptRoot\Package\$Name.zip" -SourcePath $TempPath
    } # Process
    
	End {
		Remove-Item -Path $TempPath -Recurse -Force
	} # End
} # Function Package-Module
##########################################################################################################################################

Package-Module -Name 'InstallUsingGPOTools'