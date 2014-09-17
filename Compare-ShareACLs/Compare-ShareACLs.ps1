<# 
           .SYNOPSIS  
           This script will get all the ACLs for all shares on this computer and compare them with a baseline set of share ACLs. It will also get and store the file/folder ACL's for all files/folders in each share.

           .DESCRIPTION 
           If this script is run it will look for specified baseline ACL. If none are found it will create them from the shares active on this machine.
           If the baseline data is found the script will output a report showing the changes to the share and file/folder ACLs.
           The script makes three different types of Baseline files (.BSL) in the baseline folder:
           1. _SHARES.BSL - this is the list of shares available on the computer at the time of the baseline info being created.
           2. SHARE_*.BSL - this is the share ACLs for the share specified by * on the computer.
           3. ACL_*.BSL - this is the full list of defined (not inherited) file/folder ACLs for the * share on this computer.
     
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
# Last updated 2014-09-04
# Ver. 2.0
  
[cmdletbinding()] 
 
param([string[]]$BaselinePath='.',[switch]$RebuildBaseline,[string[]]$ReportFile='.')  

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
$computer = '.'
$ComputerName = $(Get-WmiObject Win32_Computersystem).name

If ($RebuildBaseline) { 
    # Build new baseline files
    Write-Host "Baseline Share ACL information is being created in '$BaselinePath' folder"
    Write-Host ""
    # Remove existing baseline files first
    Remove-Item -Path "$BaselinePath\*.bsl"
    # Get the list of non hidden/non system shares
    $current_shares = gwmi -Class win32_share -ComputerName $computer | Where-Object { $_.Name -notlike "*$" } | select -ExpandProperty Name  
    # Export the list of shares to _shares.bsl
    Export-Clixml -Path "$BaselinePath\_shares.bsl" -InputObject $current_shares
    foreach ($current_share in $current_shares) {  
        $current_acl = $null  
        Write-Host $('=' * 100)  
        Write-Host $current_share -ForegroundColor Green  
        Write-Host $('-' * $current_share.Length) -ForegroundColor Green  
        $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$current_share'"  -ComputerName $computer 
        try {  
            $SD = $objShareSec.GetSecurityDescriptor().Descriptor    
            foreach($ace in $SD.DACL){   
                $UserName = $ace.Trustee.Name      
                If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}    
                If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }      
                [Array]$current_acl += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)  
                } #end foreach ACE            
            } # end try  
        catch { 
            Write-Host "Unable to obtain share ACLs for $current_share" -ForegroundColor Red
        }  
        # Write the SHARE ACL information
        Export-Clixml -Path "$BaselinePath\Share_$current_share.bsl" -InputObject $current_acl
        
        # Output the SHARE ACL information to the screen
        $current_acl

        # Create an empty array to store all the non inherited file/folder ACLs.
        [array]$current_file_acl = $null

        # Now generate the root file/folder ACLs 
        $root_file_acl = Get-Acl -Path "\\$ComputerName\$current_share"
        $purepath = $root_file_acl.Path.Substring($root_file_acl.Path.IndexOf("::\\")+2)
        $owner = $file_acl.Owner
        $group = $file_acl.Group
        $SDDL = $file_acl.SDDL
        $file_access = $root_file_acl.Access
        Foreach ($access in $file_access) {
            # Write each non-inherited ACL from the root into the array of ACL's 
            Write-Host "Path              : $purepath"
            $access
            $current_file_acl += @( $purepath, $owner, $group, $SDDL, $access )
        }
        # Generate any non-inferited file/folder ACLs
        $node_file_acl = Get-ChildItem -Path "\\$ComputerName\$current_share\" -Recurse | get-acl | Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::\\")+2)} },Owner,Group,Access,SDDL
        Foreach ($file_acl in $node_file_acl) {
            $purepath = $file_acl.PurePath
            $owner = $file_acl.Owner
            $group = $file_acl.Group
            $SDDL = $file_acl.SDDL
            $file_access = $file_acl.Access
            Foreach ($access in $file_access) {
                If (-not $access.IsInherited) {
                    Write-Host "Path              : $purepath"
                    $access
                    $current_file_acl += @( $purepath, $owner, $group, $SDDL, $access )
                }
            }
        }
        Export-Clixml -Path "$BaselinePath\ACL_$current_share.bsl" -InputObject $current_file_acl

        Write-Host $('=' * 100)  
        Write-Host ''
    } # end foreach $current_share
    Write-Host "Baseline Share ACL information created successfully in '$BaselinePath' folder"
}
Else {
    # Compare existing shares with Baseline shares

    Write-Host "Current Share ACL information is being compared with Baseline Share ACL information in '$BaselinePath' folder"
    Write-Host ""

    # Create the HTML report file
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
    $current_shares = gwmi -Class win32_share -ComputerName $computer | Where-Object { $_.Name -notlike "*$" } | select -ExpandProperty Name  
    # Get the Baseline shares
    $baseline_shares = Import-Clixml -Path "$BaselinePath\_shares.bsl"
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
            $baseline_acl = Import-Clixml -Path "$BaselinePath\Share_$current_share.bsl"
            # generate the current share ACLs for this share
            $current_acl = $null
            $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$current_share'"  -ComputerName $computer 
            try {  
                $SD = $objShareSec.GetSecurityDescriptor().Descriptor    
                foreach($ace in $SD.DACL){   
                    $UserName = $ace.Trustee.Name      
                    If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}    
                    If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }      
                    [Array]$current_acl += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)  
                    } #end foreach ACE
                } # end try  
            catch { 
                Write-Host "SHARE: " -ForegroundColor DarkBlue -NoNewline
                Write-Host "Unable to obtain ACLs for $current_share" -ForegroundColor Red
                $html += "<p class='sharebad'>Unable to obtain ACLs for $current_share</p>"
            }
            $changes = $false
            # Now compare the current share ACLs wth the baseline share ACLs
            Foreach ($cacl in $current_acl) {
                [string]$c_accesscontroltype = $cacl.AccessControlType
                [string]$c_filesystemrights = $cacl.FileSystemRights
                [string]$c_identityreference = $cacl.IdentityReference.ToString()
                $acl_found = $false
                Foreach ($bacl in $baseline_acl) {
                    [string]$b_accesscontroltype = $bacl.AccessControlType
                    [string]$b_filesystemrights = $bacl.FileSystemRights
                    [string]$b_identityreference = $bacl.IdentityReference.ToString()
                    If ($c_identityreference -eq $b_identityreference) {
                        $acl_found = $true
                        break
                    }
                }
                If ($acl_found) {
                    # The IdentityReference (user) exists in both the Baseline and the Current ACLs
                    # Check it's the same though
                    If ($c_filesystemrights -ne $b_filesystemrights) {
                        Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights" -ForegroundColor Yellow
                        $html += "<span class='typelabel'>SHARE: </span><span class='permissionchanged'>'$c_identityreference' ACL rights changed from $b_filesystemrights to $c_filesystemrights</span><br>"
                        $changes = $true
                    }
                    Elseif ($c_accesscontroltype -ne $b_accesscontroltype) {
                        Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                        Write-Host "'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype" -ForegroundColor Yellow
                        $html += "<span class='typelabel'>SHARE: </span><span class='permissionchanged'>'$c_identityreference' ACL access control type changed from $b_accesscontroltype to $c_accesscontroltype</span><br>"
                        $changes = $true
                    }
                }
                Else {
                    # The ACL wasn't found so it must be newly added
                    Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                    Write-Host "'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)" -ForegroundColor Green
                    $html += "<span class='typelabel'>SHARE: </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)</span><br>"
                    $changes = $true
                }
            }
            # Now compare the baseline share ACLs wth the current share ACLs
            # We only need to check if a ACL has been removed from the baseline
            Foreach ($bacl in $baseline_acl) {
                [string]$b_accesscontroltype = $bacl.AccessControlType
                [string]$b_filesystemrights = $bacl.FileSystemRights
                [string]$b_identityreference = $bacl.IdentityReference.ToString()
                $acl_found = $false
                Foreach ($cacl in $current_acl) {
                    [string]$c_accesscontroltype = $cacl.AccessControlType
                    [string]$c_filesystemrights = $cacl.FileSystemRights
                    [string]$c_identityreference = $cacl.IdentityReference.ToString()
                    If ($c_identityreference -eq $b_identityreference) {
                        $acl_found = $true
                        break
                    }
                }
                If (-not $acl_found) {
                    # The IdentityReference (user) exists in the Baseline but not in the Current
                    Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                    Write-Host "'$b_identityreference' ACL removed ($b_filesystemrights $b_accesscontroltype)" -ForegroundColor Red
                    $html += "<span class='typelabel'>SHARE: </span><span class='permissionremoved'>'$b_identityreference' permission removed</span><br>"
                    $changes = $true
                }
            }
            # Now we've got to do the comparison with the Baseline File/Folder ACL and the Current File/Folder ACL
            $baseline_acl = Import-Clixml -Path "$BaselinePath\ACL_$current_share.bsl"

            # Create an empty array to store all the non inherited file/folder ACLs.
            [array]$current_file_acl = $null

            # Now generate the root file/folder ACLs 
            $root_file_acl = Get-Acl -Path "\\$ComputerName\$current_share"
            $purepath = $root_file_acl.Path.Substring($root_file_acl.Path.IndexOf("::\\")+2)
            $owner = $file_acl.Owner
            $group = $file_acl.Group
            $SDDL = $file_acl.SDDL
            $file_access = $root_file_acl.Access
            Foreach ($access in $file_access) {
                # Write each non-inherited ACL from the root into the array of ACL's 
                $current_file_acl += @( $purepath, $owner, $group, $SDDL, $access )
            }
            # Generate any non-inferited file/folder ACLs
            $node_file_acl = Get-ChildItem -Path "\\$ComputerName\$current_share\" -Recurse | get-acl | Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::\\")+2)} },Owner,Group,Access,SDDL
            Foreach ($file_acl in $node_file_acl) {
                $purepath = $file_acl.PurePath
                $owner = $file_acl.Owner
                $group = $file_acl.Group
                $SDDL = $file_acl.SDDL
                $file_access = $file_acl.Access
                Foreach ($access in $file_access) {
                    If (-not $access.IsInherited) {
                        $current_file_acl += @( $purepath, $owner, $group, $SDDL, $access )
                    }
                }
            }
            # Perform the baseline to current file/folder ACL comparison
              Foreach ($file_acl in $current_file_acl) {
                
            }

            # If no changes have been made to any of the ACLs (file/folder or share) then say so
            If (-not $changes) {
                Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                Write-Host "No changes to share ACLs"
                $html += "<span class='typelabel'>SHARE: </span><span class='nochanged'>No changes to share ACLs</span><br>"
            }
        }
        Else {
            # Current Share does not exist in Baseline (Share added)
            Write-Host $('=' * 100)  
            Write-Host "$current_share - Share has been added" -ForegroundColor Green
            Write-Host $('-' * $current_share.Length)
            $html += "<h2>$current_share - <span class='shareadded'>Share has been added</span></h2>"
            $current_acl = $null
            $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$current_share'"  -ComputerName $computer 
            try {  
                $SD = $objShareSec.GetSecurityDescriptor().Descriptor    
                foreach($ace in $SD.DACL){   
                    $UserName = $ace.Trustee.Name      
                    If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}    
                    If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }      
                    [Array]$current_acl += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)  
                    } #end foreach ACE            
                } # end try  
            catch { 
                Write-Host "Unable to obtain permissions for $current_share" -ForegroundColor Red
            }
            $html += "<p class='permissionadded'>"
            Foreach ($cacl in $current_acl) {
                [string]$c_accesscontroltype = $cacl.AccessControlType
                [string]$c_filesystemrights = $cacl.FileSystemRights
                [string]$c_identityreference = $cacl.IdentityReference.ToString()
                Write-Host "SHARE: " -ForegroundColor Cyan -NoNewline
                Write-Host "$c_identityreference ACL added ($c_filesystemrights $c_accesscontroltype)" -ForegroundColor Green
                $html += "<span class='typelabel'>SHARE: </span><span class='permissionadded'>'$c_identityreference' ACL added ($c_filesystemrights $c_accesscontroltype)</span><br>"
            }
            $html += "</p>"
        }
        Write-Host $('=' * 100)  
        Write-Host ''
    }
    Foreach ($baseline_share in $baseline_shares) {
        If (-not ($current_shares.Contains($baseline_share))) {
            # Baseline Share does not exist in Current Shares (Share removed)
            Write-Host $('=' * 100)  
            Write-Host "$baseline_share - Share has been removed" -ForegroundColor Red
            Write-Host $('-' * $baseline_share.Length)
            $html += "<h2>$baseline_share - <span class='shareremoved'>Share has been removed</span></h2>"
            Write-Host $('=' * 100)  
            Write-Host ''
        }

    }
    $html += "</body></html>"
    # Save thge report html file
    Set-Content -Path $ReportFile -Value $html

    Write-Host "Share ACL Comparison report has been created in '$ReportFile'"
    Write-Host ""
} 