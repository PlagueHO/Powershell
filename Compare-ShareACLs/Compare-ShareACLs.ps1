<#
.SYNOPSIS
This script will get all the ACLs for all shares on this computer and compare them with a baseline set of share ACLs. It will also get and store the file/folder ACL's for all files/folders in each share.

.DESCRIPTION 
If this script is run it will look for specified baseline ACL. If none are found it will create them from the shares active on this machine.
If the baseline data is found the script will output a report showing the changes to the share and file/folder ACLs.
The script makes three different types of Baseline files (.BSL) in the baseline folder:
1. _SHARES.BSL - this is the list of shares available on the computer at the time of the baseline info being created.
2. SHARE_*.BSL - this is the share ACLs for the share specified by * on the computer.
3. FILE_*.BSL - this is the full list of defined (not inherited) file/folder ACLs for the * share on this computer.
     
.PARAMETER ComputerName
This is the computer name of the machine to compare the share ACL information from.

.PARAMETER BaselinePath 
Specifies the path to the folder containing the baseline data. If none is provided it will default to the Baseline folder under the current folder.

.PARAMETER RebuildBaseline
Switch that triggers the baseline data to be rebuilt from the shares on this machine.
 
.PARAMETER ReportFile
The path to the report file to be created. If no report file is specified it will be created in the current folder with the name Report.htm.
The Report file will not be created if Baseline data is not found.
 
.PARAMETER ExcludeShares
This is a list of share names to exclude from the 

.EXAMPLE 
 Compare-ShareACLs -ComputerName DC -RebuildBaseline
 Causes the Baseline share, file and folder ACL information to be rebuilt for the DC machine.

.EXAMPLE 
 Compare-ShareACLs -ComputerName DC -BaselinePath c:\baseline\DC\
 Performs a Share, File and Folder ACL comparison with the current ACL info from all shares on the DC machine against the Baseline ACL
 info stored in the c:\baseline\DC\ folder. If baseline data does not exist in this folder it will be created as if the -RebuildBaseline
 swtich was set.

.EXAMPLE
 Compare-ShareACLs -ComputerName DC -ExcludeShares SYSVOL,NETLOGON
 Performs a Share, File and Folder ACL comparison with the current ACL info from all shares except SYSVOL and NETLOGON on the DC machine against the Baseline ACL
 info stored in the c:\baseline\DC\ folder. If baseline data does not exist in this folder it will be created as if the -RebuildBaseline
 swtich was set.
#>

[cmdletbinding()]
param (
    [string]$ComputerName='.',
    [string]$BaselinePath='.',
    [switch]$RebuildBaseline,
    [string]$ReportFile='.',
    [string[]]$ExcludeShares
) # Param

# SUPPORT FUNCTIONS
function Get-AllShares {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
        [String[]]$ExcludeShares
    ) # param
    [Array]$temp_shares = Get-WMIObject -Class win32_share -ComputerName $ComputerName |
        Where-Object { $_.Name -notlike "*$" } |
        select -ExpandProperty Name
    [Array]$shares = $null
    Foreach ($share in $temp_shares) {
        If ($share -notin $ExcludeShares) {
           $shares += $share 
        } # If
    } # Foreach
    return $shares
} # Function Get-AllShares

function Get-ShareACLs {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
        [String]$ShareName
    ) # param
    # Create an empty array to store all the Share ACLs.
    [array]$share_acls = $null
    $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$ShareName'"  -ComputerName $ComputerName 
    try {  
        $SD = $objShareSec.GetSecurityDescriptor().Descriptor
        Foreach($ace in $SD.DACL){   
            $UserName = $ace.Trustee.Name
            If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}    
            If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }      
            [Array]$share_acls += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)  
       } # Foreach           
    } catch { 
        Write-Host "Unable to obtain share ACLs for $ShareName" -ForegroundColor Red
    } # Try
    return $share_acls
} # function Get-ShareACLs

function Create-FileACLObject {
    Param (
        [Parameter(Mandatory=$true)]
        [String]$Path,
        [Parameter(Mandatory=$true)]
        [String]$Owner,
        [Parameter(Mandatory=$true)]
        [String]$Group,
        [Parameter(Mandatory=$true)]
        [String]$SDDL,
        [Parameter(Mandatory=$true)]
        [Object]$Access
    ) # Param
    # Need to correct the $Access objects to ensure the FileSystemRights values correctly converted to string
    # When the "Generic Rights" bits are set: http://msdn.microsoft.com/en-us/library/aa374896%28v=vs.85%29.aspx
    $props = @{
        'Path'=$Path;
        'Owner'=$Owner;
        'Group'=$Group;
        'SDDL'=$SDDL;
        'Access'=$Access
    }
    $acl_object = New-Object -Type PSObject -Property $props
    return $acl_object
} # function Create-FileACLObject

function Convert-FileSystemAccessToString {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$FileSystemAccess
    ) # Param
    If ($FileSystemAccess.StartsWith('-')) {
    # This contains Generic High Bits
        Return "Special Generic Rights $FileSystemAccess"
    } Else {
        Return $FileSystemAccess
    }
} # function Convert-FileSystemAccessToString

function Convert-FileSystemAppliesToString {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$InheritanceFlags,
        [Parameter(Mandatory=$true)]
        [String]$PropagationFlags
    ) # Param
    If ($PropagationFlags -eq 'None') {
        Switch ($InheritanceFlags) {
            'None' { return 'This folder only'; break }
            'ContainerInherit, ObjectInherit' { return 'This folder, subfolders and files'; break }
            'ContainerInherit' { return 'This folder and subfolders'; break }
            'ObjectInherit' { return 'This folder and files'; break }
        } # Switch
    } else {
        Switch ($InheritanceFlags) {
            'ContainerInherit, ObjectInherit' { return 'Subfolders and files only'; break }
            'ContainerInherit' { return 'Subfolders only'; break }
            'ObjectInherit' { return 'Files only'; break }
        } # Switch
    } # If
    return "Unknown"
} # function Convert-FileSystemAppliesToString

function Convert-ACEToString {
    Param(
        [Parameter(Mandatory=$true)]
        [Object]$ACE
    ) # Param
    [string]$rights=Convert-FileSystemAccessToString -FileSystemAccess $ace.FileSystemRights
    [string]$controltype=$ace.AccessControlType
    [string]$IdentityReference=$ace.IdentityReference
    [string]$IsInherited=$ace.IsInherited
    [string]$AppliesTo=Convert-FileSystemAppliesToString -InheritanceFlags $ace.InheritanceFlags -PropagationFlags $ace.PropagationFlags
    Return "FileSystemRights  : $rights`nAccessControlType : $controltype`nIdentityReference : $IdentityReference`nIsInherited       : $IsInherited`nAppliesTo         : $AppliesTo`n"
} # function Convert-FileSystemACLToString

function Convert-FileSystemACLToString {
    Param(
        [Parameter(Mandatory=$true)]
        [Object]$ACL
    ) # Param
    [string]$path=$acl.path
    [string]$owner=$acl.owner
    [string]$group=$acl.group
    [string]$acestring=Convert-ACEToString($acl.access)
    Return "Path              : $path`nOwner             : $owner`nGroup             : $group`n$acestring"
} # function Convert-FileSystemACLToString

function Get-ShareFileACLs {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
        [Parameter(Mandatory=$true)]
        [String]$ShareName
    ) # param
    # Create an empty array to store all the non inherited file/folder ACLs.
    [array]$file_acls = $null

    # Now generate the root file/folder ACLs 
    $root_file_acl = Get-Acl -Path "\\$ComputerName\$ShareName"   
    Foreach ($access in $root_file_acl.Access) {
        # Write each non-inherited ACL from the root into the array of ACL's 
        $purepath = $root_file_acl.Path.Substring($root_file_acl.Path.IndexOf("::\\")+2)
        $owner = $root_file_acl.Owner
        $group = $root_file_acl.Group
        $SDDL = $root_file_acl.SDDL
        $acl_object =  Create-FileACLObject -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
        $file_acls += $acl_object
    } # Foreach
    # Generate any non-inferited file/folder ACLs
    $node_file_acls = Get-ChildItem -Path "\\$ComputerName\$ShareName\" -Recurse |
         Get-ACL |
         Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::\\")+2)} },Owner,Group,Access,SDDL
    Foreach ($node_file_acl in $node_file_acls) {
        Foreach ($access in $node_file_acl.Access) {
            If (-not $access.IsInherited) {
                # Write each non-inherited ACL from the file/folder into the array of ACL's 
                $purepath = $node_file_acl.PurePath
                $owner = $node_file_acl.Owner
                $group = $node_file_acl.Group
                $SDDL = $node_file_acl.SDDL
                $acl_object =  Create-FileACLObject -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
                $file_acls += $acl_object
            } # If
        } # Foreach
    } # Foreach
    return $file_acls
} # Function Get-ShareFileACLs

Function Create-HTMLReportHeader {
    Param (
        [Parameter(Mandatory=$true)]
        [String]$Title
    ) # Param
    [String]$html = ''
    $html = "<!doctype html><html><head><title>$Title</title>"
    $html += '<style type="text/css">'
    $html += 'h1, h2, h3, h4, h5, h6, p, a, ul, li, ol, td, label, input, span, div {font-weight:normal !important; font-family:Tahoma, Arial, Helvetica, sans-serif;}'
    $html += '.sharebad {color: red; font-weight: bold;}'
    $html += '.shareadded {color: green; font-weight: bold;}'
    $html += '.shareremoved {color: red; font-weight: bold;}'
    $html += '.permissionremoved {color: red; font-weight: bold;}'
    $html += '.permissionchanged {color: orange; font-weight: bold;}'
    $html += '.permissionadded { color: green; font-weight: bold;}'
    $html += '.nochange { color: gray; font-style: italic;}'
    $html += '.typelabel { color: cyan;}'
    $html += '</style>'
    $html += '</head>'
    $html += '<body>'
    $html += "<h1>$Title</h1>"
    return $html
} # Function Create-HTMLReportHeader

Function Create-HTMLReportFooter {
    [String]$html = ''
    $html = '</body></html>'
    return $html
} # Function Create-HTMLReportFooter

# MAIN CODE START
If ($ComputerName -eq '.') {
    $ComputerName = $(Get-WmiObject Win32_Computersystem).name
}

# Get the BaselinePath
If ($BaselinePath -eq '.') {
    $BaselinePath = (Get-Location).ToString() + '\Baseline'
}
# Check the Baseline folder exists
If (-not (Test-Path -Path $BaselinePath)) {
    # No - need to create the baseline folder and build a set of baseline files
    New-Item -Path $BaselinePath -Type Directory | Out-Null
    $RebuildBaseline = $true
}
Else {
    # Check *.BSL files are in Baseline folder
    If (-not (Test-Path -Path "$BaselinePath\*.bsl")) {
        # No - need to build a set of baseline files
        $RebuildBaseline = $true
    }
}

If ($ReportFile -eq '.') {
    $ReportFile = (Get-Location).ToString() + '\Report.htm'
}
If ($RebuildBaseline) { 
    # Build new baseline files

    # Write the Host output Header
    Write-Host "Baseline Share ACL information for '$ComputerName' is being created in '$BaselinePath' folder"
    Write-Host ""

    # Create the HTML report file
    [string]$html = Create-HTMLReportHeader -Title "Share ACL Baseline Creation '$ComputerName' $(Get-Date)"

    # Remove existing baseline files first
    Remove-Item -Path "$BaselinePath\*.bsl"

    # Get the list of non hidden/non system shares
    $current_shares = Get-AllShares -ComputerName $ComputerName -ExcludeShares $ExcludeShares

    # Export the list of shares to _shares.bsl
    Export-Clixml -Path "$BaselinePath\_shares.bsl" -InputObject $current_shares
    If ($current_shares.Length -eq 0) {
        Write-Host "No accessible shares were found on '$ComputerName'" -ForegroundColor Red
        Write-Host ""
        $html += "<h2>No accessible shares were found on '$ComputerName'</h2>"
    } Else {
        Foreach ($current_share in $current_shares) {  

            # Write the Host output Share Header
            Write-Host $('=' * 100)  
            Write-Host $current_share -ForegroundColor Green  
            Write-Host $('-' * $current_share.Length) -ForegroundColor Green  
            $html += "<h2>$current_share</h2>"

            # Get the Current SHARE ACL information
            [array]$current_share_acls = Get-ShareACLs -ComputerName $ComputerName -ShareName $current_share

            # Write the Current SHARE ACL information
            Export-Clixml -Path "$BaselinePath\Share_$current_share.bsl" -InputObject $current_share_acls
        
            # Output the SHARE ACL information to the screen
            Foreach ($current_share_acl in $current_share_acls) {
                $current_share_acl
            }

            # Get the Current File/Folder ACLs to an Array
            [array]$current_file_acls = Get-ShareFileACLS -ComputerName $ComputerName -ShareName $current_share

            # Write the Current File/Folder ACL information
            Export-Clixml -Path "$BaselinePath\File_$current_share.bsl" -InputObject $current_file_acls

            # Output the File/Folder ACL information to the screen
            Foreach ($current_file_acl in $current_file_acls) {
                Convert-FileSystemACLToString($current_file_acl) | Write-Host
            }

            # Write the Host output Share footer
            Write-Host $('=' * 100)  
            Write-Host ''
        } # Foreach
    } # If

    $html += Create-HTMLReportFooter

    # Write the Host output Footer
    Write-Host "Baseline Share ACL information for '$ComputerName' created successfully in '$BaselinePath' folder"

    # Save thge report html file
    Set-Content -Path "$BaselinePath\Baseline.htm" -Value $html
} Else {
    # Compare existing shares with Baseline shares

    # Write the Host output Header
    Write-Host "Current Share ACL information for '$ComputerName' is being compared with Baseline Share ACL information in '$BaselinePath' folder"
    Write-Host ""

    # Create the HTML report file
    [string]$html = Create-HTMLReportHeader -Title "Share ACL Comparison '$ComputerName' $(Get-Date)"
    
    # Get the list of non hidden/non system shares
    [array]$current_shares = Get-AllShares -ComputerName $ComputerName -ExcludeShares $ExcludeShares
    
    # Get the Baseline shares
    [array]$baseline_shares = Import-Clixml -Path "$BaselinePath\_shares.bsl"
    
    If ($current_shares.Length -eq 0) {
        Write-Host "No accessible shares were found on '$ComputerName'" -ForegroundColor Red
        Write-Host ""
        $html += "<h2>No accessible shares were found on '$ComputerName'</h2>"
    } Else {
        # Go through each current share and compare the ACLs
        Foreach ($current_share in $current_shares) {
            # Does the current_share exist in the list of Baseline Shares?
            If ($baseline_shares.Contains($current_share)) {
                # Current share exists in Baseline
                Write-Host $('=' * 100)
                Write-Host $current_share
                Write-Host $('-' * $current_share.Length)                                
                $html += "<h2>$current_share</h2>"
            
                # Read the baseline share ALCs for this share
                [array]$baseline_share_acls = Import-Clixml -Path "$BaselinePath\Share_$current_share.bsl"
            
                # generate the current share ACLs for this share
                [array]$current_share_acls = Get-ShareACLs -ComputerName $ComputerName -ShareName $current_share

                [boolean]$changes = $false
            
                # Now compare the current share ACLs wth the baseline share ACLs
                Foreach ($current_share_acl in $current_share_acls) {
                    [string]$c_accesscontroltype = $current_share_acl.AccessControlType
                    [string]$c_filesystemrights = Convert-FileSystemAccessToString($current_share_acl.FileSystemRights)
                    [string]$c_identityreference = $current_share_acl.IdentityReference.ToString()
                    [boolean]$acl_found = $false
                    Foreach ($baseline_share_acl in $baseline_share_acls) {
                        [string]$b_accesscontroltype = $baseline_share_acl.AccessControlType
                        [string]$b_filesystemrights = Convert-FileSystemAccessToString($baseline_share_acl.FileSystemRights)
                        [string]$b_identityreference = $baseline_share_acl.IdentityReference.ToString()
                        If ($c_identityreference -eq $b_identityreference) {
                            $acl_found = $true
                            break
                        } # If
                    } # Foreach
                    If ($acl_found) {
                        # The IdentityReference (user) exists in both the Baseline and the Current ACLs
                        # Check it's the same though
                        If ($c_filesystemrights -ne $b_filesystemrights) {
                            Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                            Write-Host "'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights" -ForegroundColor Yellow
                            $html += "<span class='typelabel'>SHARE: </span><span class='permissionchanged'>'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights</span><br>"
                            $changes = $true
                        } Elseif ($c_accesscontroltype -ne $b_accesscontroltype) {
                            Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                            Write-Host "'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype" -ForegroundColor Yellow
                            $html += "<span class='typelabel'>SHARE: </span><span class='permissionchanged'>'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype</span><br>"
                            $changes = $true
                        } # If
                    } Else {
                        # The ACL wasn't found so it must be newly added
                        Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)" -ForegroundColor Green
                        $html += "<span class='typelabel'>SHARE: </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights -> $c_accesscontroltype)</span><br>"
                        $changes = $true
                    } # If
                } # Foreach
            
                # Now compare the baseline share ACLs wth the current share ACLs
                # We only need to check if a ACL has been removed from the baseline
                Foreach ($baseline_share_acl in $baseline_share_acls) {
                    [string]$b_accesscontroltype = $baseline_share_acl.AccessControlType
                    [string]$b_filesystemrights = Convert-FileSystemAccessToString($baseline_share_acl.FileSystemRights)
                    [string]$b_identityreference = $baseline_share_acl.IdentityReference.ToString()
                    [boolean]$acl_found = $false
                    Foreach ($current_share_acl in $current_share_acls) {
                        [string]$c_accesscontroltype = $current_share_acl.AccessControlType
                        [string]$c_filesystemrights = Convert-FileSystemAccessToString($current_share_acl.FileSystemRights)
                        [string]$c_identityreference = $current_share_acl.IdentityReference.ToString()
                        If ($c_identityreference -eq $b_identityreference) {
                            $acl_found = $true
                            break
                        } # If
                    } # Foreach
                    If (-not $acl_found) {
                        # The IdentityReference (user) exists in the Baseline but not in the Current
                        Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$b_identityreference' ACL removed ($b_filesystemrights $b_accesscontroltype)" -ForegroundColor Red
                        $html += "<span class='typelabel'>SHARE: </span><span class='permissionremoved'>'$b_identityreference' permission removed</span><br>"
                        $changes = $true
                    } # If
                } # Foreach

                # Now we've got to do the comparison with the Baseline File/Folder ACL and the Current File/Folder ACL
                [array]$baseline_file_acls = Import-Clixml -Path "$BaselinePath\File_$current_share.bsl"

                # Get the Current File/Folder ACLs to an Array
                [array]$current_file_acls = Get-ShareFileACLs -ComputerName $ComputerName -ShareName $current_share
            
                # Set the last processed path to a path string that can never occur
                [string]$last_path = '.'

                # Perform the baseline to current file/folder ACL comparison
                Foreach ($current_file_acl in $current_file_acls) {
                    # Put all the Current File ACL props into variables for easy access.
                    [string]$c_path = $current_file_acl.Path
                    [string]$c_owner = $current_file_acl.Owner
                    [string]$c_group = $current_file_acl.Group
                    [string]$c_SDDL = $current_file_acl.SDDL
                    $c_access = $current_file_acl.Access
                    [string]$c_accesscontroltype = $c_access.AccessControlType
                    [string]$c_filesystemrights = Convert-FileSystemAccessToString -FileSystemAccess $c_access.FileSystemRights
                    [string]$c_identityreference = $c_access.IdentityReference.ToString()
                    [string]$c_appliesto=Convert-FileSystemAppliesToString -InheritanceFlags $c_access.InheritanceFlags -PropagationFlags $c_access.PropagationFlags
                    [boolean]$acl_found = $false
                    Foreach ($baseline_file_acl in $baseline_file_acls) {
                        [string]$b_path = $baseline_file_acl.Path
                        [string]$b_owner = $baseline_file_acl.Owner
                        [string]$b_group = $baseline_file_acl.Group
                        [string]$b_SDDL = $baseline_file_acl.SDDL
                        $b_access = $baseline_file_acl.Access
                        [string]$b_accesscontroltype = $b_access.AccessControlType
                        [string]$b_filesystemrights = Convert-FileSystemAccessToString -FileSystemAccess $b_access.FileSystemRights
                        [string]$b_identityreference = $b_access.IdentityReference.ToString()
                        [string]$b_appliesto=Convert-FileSystemAppliesToString -InheritanceFlags $b_access.InheritanceFlags -PropagationFlags $b_access.PropagationFlags
                        If ($c_path -eq $b_path) {
                            # Perform an owner/group check on each file/folder only once
                            # If we've already checked this path, don't bother checking the owner/group again.
                            If ($last_path -ne $c_path) {
                                If ($c_owner -ne $b_owner) {
                                    Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                                    Write-Host "Owner changed from $b_owner to $c_owner" -ForegroundColor Yellow
                                    $html += "<span class='typelabel'>c_path  : </span><span class='permissionchanged'>Owner changed from $b_owner to $c_owner</span><br>"
                                    $changes = $true
                                }
                                If ($c_group -ne $b_group) {
                                    Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                                    Write-Host "Group changed from $b_group to $c_group" -ForegroundColor Yellow
                                    $html += "<span class='typelabel'>c_path  : </span><span class='permissionchanged'>Group changed from $b_group to $c_group</span><br>"
                                    $changes = $true
                                } # If
                                $last_path = $c_path
                            } # If
                            # Check that the Identity Reference (user) is the same one
                            # And that the Applies To is the same
                            If (($c_identityreference -eq $b_identityreference) -and ($c_appliesto -eq $b_appliesto)){
                                $acl_found = $true
                                break
                            }
                        } # If
                    } # Foreach
                    If ($acl_found) {
                        # The IdentityReference (user) and path exists in both the Baseline and the Current ACLs
                        # Check it's the same though
                        If ($c_filesystemrights -ne $b_filesystemrights) {
                            Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                            Write-Host "'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights" -ForegroundColor Yellow
                            $html += "<span class='typelabel'>$c_path  : </span><span class='permissionchanged'>'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights</span><br>"
                            $changes = $true
                        } Elseif ($c_accesscontroltype -ne $b_accesscontroltype) {
                            Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                            Write-Host "'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype" -ForegroundColor Yellow
                            $html += "<span class='typelabel'>$c_path : </span><span class='permissionchanged'>'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype</span><br>"
                            $changes = $true
                        } # If
                    } Else {
                        # The ACL wasn't found so it must be newly added
                        Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$c_identityreference' ACL added ($c_filesystemrights -> $c_accesscontroltype -> $c_appliesto)" -ForegroundColor Green
                        $html += "<span class='typelabel'>$c_path : </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights -> $c_accesscontroltype -> $c_appliesto)</span><br>"
                        $changes = $true
                    } # If
                } # Foreach

                # Now compare the baseline file ACLs wth the current file ACLs
                # We only need to check if a ACL has been removed from the baseline
                Foreach ($baseline_file_acl in $baseline_file_acls) {
                    [string]$b_path = $baseline_file_acl.Path
                    [string]$b_owner = $baseline_file_acl.Owner
                    [string]$b_group = $baseline_file_acl.Group
                    [string]$b_SDDL = $baseline_file_acl.SDDL
                    $b_access = $baseline_file_acl.Access
                    [string]$b_accesscontroltype = $b_access.AccessControlType
                    [string]$b_filesystemrights = Convert-FileSystemAccessToString -FileSystemAccess $b_access.FileSystemRights
                    [string]$b_identityreference = $b_access.IdentityReference.ToString()
                    [string]$b_appliesto=Convert-FileSystemAppliesToString -InheritanceFlags $b_access.InheritanceFlags -PropagationFlags $b_access.PropagationFlags
                    [boolean]$acl_found = $false
                    Foreach ($current_file_acl in $current_file_acls) {
                        [string]$c_path = $current_file_acl.Path
                        [string]$c_owner = $current_file_acl.Owner
                        [string]$c_group = $current_file_acl.Group
                        [string]$c_SDDL = $current_file_acl.SDDL
                        $c_access = $current_file_acl.Access
                        [string]$c_accesscontroltype = $c_access.AccessControlType
                        [string]$c_filesystemrights = Convert-FileSystemAccessToString -FileSystemAccess $c_access.FileSystemRights
                        [string]$c_identityreference = $c_access.IdentityReference.ToString()
                        [string]$c_appliesto=Convert-FileSystemAppliesToString -InheritanceFlags $c_access.InheritanceFlags -PropagationFlags $c_access.PropagationFlags
                        If (($c_path -eq $b_path) -and ($c_identityreference -eq $b_identityreference) -and ($c_appliesto -eq $b_appliesto)) {
                            $acl_found = $true
                            break
                        } # If
                    } # Foreach
                    If (-not $acl_found) {
                        # The IdentityReference (user) and path exists in the Baseline but not in the Current
                        Write-Host "$b_path : " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$b_identityreference' ACL removed ($b_filesystemrights -> $b_accesscontroltype -> $b_appliesto)" -ForegroundColor Red
                        $html += "<span class='typelabel'>$b_path : </span><span class='permissionremoved'>'$b_identityreference' ACL removed ($b_filesystemrights -> $b_accesscontroltype -> $b_appliesto)</span><br>"
                        $changes = $true
                    } # If
                } # Foreach

                # If no changes have been made to any of the Share or File/Folder ACLs then say so
                If (-not $changes) {
                    Write-Host "SHARE/FILE/FOLDER : " -ForegroundColor Cyan -NoNewline
                    Write-Host "No changes to share, file or folder ACLs"
                    $html += "<span class='typelabel'>SHARE/FILE/FOLDER : </span><span class='nochanged'>No changes to share, file or folder ACLs</span><br>"
                } # If
            } Else {
                # Current Share does not exist in Baseline (Share added)
                Write-Host $('=' * 100)  
                Write-Host "$current_share - Share has been added" -ForegroundColor Green
                Write-Host $('-' * $current_share.Length)
                $html += "<h2>$current_share - <span class='shareadded'>Share has been added</span></h2>"
                $html += "<p class='permissionadded'>"

                # Get the Current SHARE ACL information
                [array]$current_share_acls = Get-ShareACLs -ComputerName $ComputerName -ShareName $current_share

                # Output the current share ACLs into the report
                Foreach ($current_share_acl in $current_share_acls) {
                    [string]$c_accesscontroltype = $current_share_acl.AccessControlType
                    [string]$c_filesystemrights = Convert-FileSystemAccessToString($current_share_acl.FileSystemRights)
                    [string]$c_identityreference = $current_share_acl.IdentityReference.ToString()
                    Write-Host "SHARE : " -ForegroundColor Cyan -NoNewline
                    Write-Host "'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)" -ForegroundColor Green
                    $html += "<span class='typelabel'>SHARE : </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights -> $c_accesscontroltype)</span><br>"
                }

                # Get the Current File/Folder ACLs to an Array
                [array]$current_file_acls = Get-ShareFileACLs -ComputerName $ComputerName -ShareName $current_share

                # Output the current share ACLs into the report
                Foreach ($current_file_acl in $current_file_acls) {
                    [string]$c_path = $current_file_acl.Path
                    [string]$c_owner = $current_file_acl.Owner
                    [string]$c_group = $current_file_acl.Group
                    [string]$c_SDDL = $current_file_acl.SDDL
                    $c_access = $current_file_acl.Access
                    [string]$c_accesscontroltype = $c_access.AccessControlType
                    [string]$c_filesystemrights = Convert-FileSystemAccessToString($c_access.FileSystemRights)
                    [string]$c_identityreference = $c_access.IdentityReference.ToString()
                    Write-Host "$c_path : " -ForegroundColor Cyan -NoNewline
                    Write-Host "'$c_identityreference' ACL added ($c_filesystemrights $c_identityreference Owner: $c_owner Group: $c_group)" -ForegroundColor Green
                    $html += "<span class='typelabel'>$c_path : </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights $c_identityreference Owner: $c_owner Group: $c_group)</span><br>"
                }

                $html += "</p>"
            }
            Write-Host $('=' * 100)  
            Write-Host ''
        }

        # Check for any removed shares
        Foreach ($baseline_share in $baseline_shares) {
            If (-not ($current_shares.Contains($baseline_share))) {
                # Baseline Share does not exist in Current Shares (Share removed)
                Write-Host $('=' * 100)  
                Write-Host "$baseline_share - Share has been removed" -ForegroundColor Red
                Write-Host $('-' * $baseline_share.Length)
                $html += "<h2>$baseline_share - <span class='shareremoved'>Share has been removed</span></h2>"
                Write-Host $('=' * 100)  
                Write-Host ''
            } # If
        } # Foreach
    } # If

    $html += Create-HTMLReportFooter

    # Save thge report html file
    Set-Content -Path $ReportFile -Value $html

    Write-Host "Share ACL Comparison report for '$ComputerName' has been created in '$ReportFile'"
    Write-Host ""
} 
