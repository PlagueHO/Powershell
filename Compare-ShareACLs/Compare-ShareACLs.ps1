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
     
           .PARAMETER BaselinePath 
           Specifies the path to the folder containing the baseline data. If none is provided it will default to the Baseline folder under the current folder.

           .PARAMETER RebuildBaseline
           Switch that triggers the baseline data to be rebuilt from the shares on this machine.
 
           .PARAMETER ReportFile
           The path to the report file to be created. If no report file is specified it will be created in the current folder with the name Report.htm.
           The Report file will not be created if Baseline data is not found.
 
           .OUTPUTS 
           None
 
           .EXAMPLE 
           C:\PS> .\Compare-ShareACLs 
 
	       .URI
	       http://
#> 
 
# Written by Dan Scott-Raynsford 2014-09-01 
# Last updated 2014-09-18
# Ver. 3.0
  
[cmdletbinding()] 
 
param([string[]]$BaselinePath='.',[switch]$RebuildBaseline,[string[]]$ReportFile='.')  

# SUPPORT FUNCTIONS
function Get-AllShares {
    Param(
        [String]$ComputerName
    ) # param
    $Shares = Get-WMIObject -Class win32_share -ComputerName $ComputerName | Where-Object { $_.Name -notlike "*$" } |
        select -ExpandProperty Name  
    return $Shares
} # Function Get-AllShares

function Get-ShareACLs {
    Param(
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
        } # end try  
    catch { 
        Write-Host "Unable to obtain share ACLs for $ShareName" -ForegroundColor Red
    } # Try
    return $share_acls
} # Get-ShareACLs

function Create-FileACLObject {
    Param (
        [String]$Path,
        [String]$Owner,
        [String]$Group,
        [String]$SDDL,
        $Access
    ) # Param
    $acl_object = New-Object Object
    $acl_object | Add-Member Path $Path
    $acl_object | Add-Member Owner $Owner
    $acl_object | Add-Member Group $Group
    $acl_object | Add-Member SDDL $SDDL
    $acl_object | Add-Member Access $Access
    return $acl_object
}

function Get-ShareFileACLs {
    Param(
        [String]$ComputerName,
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
    $node_file_acls = Get-ChildItem -Path "\\$ComputerName\$ShareName\" -Recurse | get-acl | Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::\\")+2)} },Owner,Group,Access,SDDL
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

# MAIN CODE START

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
$ComputerName = $(Get-WmiObject Win32_Computersystem).name

If ($RebuildBaseline) { 
    # Build new baseline files

    # Write the Host output Header
    Write-Host "Baseline Share ACL information is being created in '$BaselinePath' folder"
    Write-Host ""

    # Remove existing baseline files first
    Remove-Item -Path "$BaselinePath\*.bsl"

    # Get the list of non hidden/non system shares
    $current_shares = Get-AllShares -ComputerName $ComputerName

    # Export the list of shares to _shares.bsl
    Export-Clixml -Path "$BaselinePath\_shares.bsl" -InputObject $current_shares
    foreach ($current_share in $current_shares) {  

        # Write the Host output Share Header
        Write-Host $('=' * 100)  
        Write-Host $current_share -ForegroundColor Green  
        Write-Host $('-' * $current_share.Length) -ForegroundColor Green  

        # Get the Current SHARE ACL information
        [array]$current_share_acls = Get-ShareACLs -ComputerName $ComputerName -ShareName $current_share

        # Write the Current SHARE ACL information
        Export-Clixml -Path "$BaselinePath\Share_$current_share.bsl" -InputObject $current_share_acls
        
        # Output the SHARE ACL information to the screen
        $current_share_acls
       
        # Get the Current File/Folder ACLs to an Array
        [array]$current_file_acls = Get-ShareFileACLS -ComputerName $ComputerName -ShareName $current_share

        # Write the Current File/Folder ACL information
        Export-Clixml -Path "$BaselinePath\File_$current_share.bsl" -InputObject $current_file_acls

        # Output the File/Folder ACL information to the screen
        $current_file_acls

        # Write the Host output Share footer
        Write-Host $('=' * 100)  
        Write-Host ''
    } # Foreach

    # Write the Host output Footer
    Write-Host "Baseline Share ACL information created successfully in '$BaselinePath' folder"
} Else {
    # Compare existing shares with Baseline shares

    # Write the Host output Header
    Write-Host "Current Share ACL information is being compared with Baseline Share ACL information in '$BaselinePath' folder"
    Write-Host ""

    # Create the HTML report file
    [string]$html = ""
    $html = "<!doctype html><html><head><title>Share ACL Comparison for computer $ComputerName</title>"
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
    $html += "<h1>Share ACL Comparison<br>Computer: $ComputerName<br>Date: $(Get-Date)</h1>"

    # Get the list of non hidden/non system shares
    [array]$current_shares = Get-AllShares -ComputerName $ComputerName
    
    # Get the Baseline shares
    [array]$baseline_shares = Import-Clixml -Path "$BaselinePath\_shares.bsl"
    
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
                [string]$c_filesystemrights = $current_share_acl.FileSystemRights
                [string]$c_identityreference = $current_share_acl.IdentityReference.ToString()
                [boolean]$acl_found = $false
                Foreach ($baseline_share_acl in $baseline_share_acls) {
                    [string]$b_accesscontroltype = $baseline_share_acl.AccessControlType
                    [string]$b_filesystemrights = $baseline_share_acl.FileSystemRights
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
                [string]$b_filesystemrights = $baseline_share_acl.FileSystemRights
                [string]$b_identityreference = $baseline_share_acl.IdentityReference.ToString()
                [boolean]$acl_found = $false
                Foreach ($current_share_acl in $current_share_acls) {
                    [string]$c_accesscontroltype = $current_share_acl.AccessControlType
                    [string]$c_filesystemrights = $current_share_acl.FileSystemRights
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
                [string]$c_filesystemrights = $c_access.FileSystemRights
                [string]$c_identityreference = $c_access.IdentityReference.ToString()
                [boolean]$acl_found = $false
                Foreach ($baseline_file_acl in $baseline_file_acls) {
                    [string]$b_path = $baseline_file_acl.Path
                    [string]$b_owner = $baseline_file_acl.Owner
                    [string]$b_group = $baseline_file_acl.Group
                    [string]$b_SDDL = $baseline_file_acl.SDDL
                    $b_access = $baseline_file_acl.Access
                    [string]$b_accesscontroltype = $b_access.AccessControlType
                    [string]$b_filesystemrights = $b_access.FileSystemRights
                    [string]$b_identityreference = $b_access.IdentityReference.ToString()
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
                        If ($c_identityreference -eq $b_identityreference) {
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
                    Write-Host "'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)" -ForegroundColor Green
                    $html += "<span class='typelabel'>$c_path : </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights -> $c_accesscontroltype)</span><br>"
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
                [string]$b_filesystemrights = $b_access.FileSystemRights
                [string]$b_identityreference = $b_access.IdentityReference.ToString()
                [boolean]$acl_found = $false
                Foreach ($current_file_acl in $current_file_acls) {
                    [string]$c_path = $current_file_acl.Path
                    [string]$c_owner = $current_file_acl.Owner
                    [string]$c_group = $current_file_acl.Group
                    [string]$c_SDDL = $current_file_acl.SDDL
                    $c_access = $current_file_acl.Access
                    [string]$c_accesscontroltype = $c_access.AccessControlType
                    [string]$c_filesystemrights = $c_access.FileSystemRights
                    [string]$c_identityreference = $c_access.IdentityReference.ToString()
                    If (($c_path -eq $b_path) -and ($c_identityreference -eq $b_identityreference)) {
                        $acl_found = $true
                        break
                    } # If
                } # Foreach
                If (-not $acl_found) {
                    # The IdentityReference (user) and path exists in the Baseline but not in the Current
                    Write-Host "$b_path : " -ForegroundColor Cyan -NoNewline
                    Write-Host "'$b_identityreference' ACL removed ($b_filesystemrights -> $b_accesscontroltype)" -ForegroundColor Red
                    $html += "<span class='typelabel'>$b_path : </span><span class='permissionremoved'>'$b_identityreference' permission removed</span><br>"
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
                [string]$c_filesystemrights = $current_share_acl.FileSystemRights
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
                [string]$c_filesystemrights = $c_access.FileSystemRights
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

    $html += "</body></html>"
    # Save thge report html file
    Set-Content -Path $ReportFile -Value $html

    Write-Host "Share ACL Comparison report has been created in '$ReportFile'"
    Write-Host ""
} 
