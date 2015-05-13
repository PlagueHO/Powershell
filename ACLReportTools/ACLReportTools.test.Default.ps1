$Script:TestPath = "c:\acltest"
$Script:MaxShares = 4 # Must be 4 or greater

##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-ACLReportToolsCreateShares {
    If (-not (Test-Path $Script:TestPath -PathType Container)) {
        New-Item -Path $Script:TestPath -ItemType Directory | Out-Null
    }
    # Create shares
    1..$Script:MaxShares | Foreach-Object {
        $SharePath = Join-Path -Path $Script:TestPath -ChildPath "Share$($_)"
        If (-not (Test-Path $SharePath -PathType Container)) {
            New-Item -Path $SharePath -ItemType Directory | Out-Null
        }
        New-SMBShare -Path $SharePath -Name "Share$($_)" | Out-Null
        Copy-Item -Path "c:\program files\windowspowershell" -Destination $SharePath -Recurse -Force | Out-Null
        If ( $_ -eq 2 ) {
            Add-NTFSAccess -Path $SharePath -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account "$ENV:ComputerName\$env:USERNAME" 
            Add-NTFSAccess -Path $SharePath -AccessRights Write -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account "$ENV:ComputerName\Administrator" 
            Add-NTFSAccess -Path $SharePath -AccessRights Read -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account "BUILTIN\Users" 
            Disable-NTFSAccessInheritance -Path $SharePath -RemoveInheritedAccessRules
            Grant-SMBShareAccess -Name "Share$($_)" -AccountName "BUILTIN\Guests" -AccessRight Full -Force | Out-Null
        }
        If ( $_ -eq 3 ) {
            Add-NTFSAccess -Path $SharePath -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account "BUILTIN\Guests" 
        }
    }
} # Test-ACLReportToolsCreateShares
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsModifyACLs {
    # Modify some permissions on the File Folders
    1..$Script:MaxShares | Foreach-Object {
        $SharePath = Join-Path -Path $Script:TestPath -ChildPath "Share$($_)"
        Write-Output "Adding NTFS Permission to $Script:TestPath AccessRights=FullControl, AppliesTo Filesonly -AccessType Allow -Account $ENV:ComputerName\$env:USERNAME"
        Add-NTFSAccess -Path $Script:TestPath -AccessRights FullControl -AppliesTo FilesOnly -AccessType Allow -Account "$ENV:ComputerName\$ENV:USERNAME" 
        If ( $_ -eq 1 ) {
            Write-Output "Setting NTFS Owner to $ENV:ComputerName\$ENV:USERNAME for $SharePath"
            Set-NTFSOwner -Account "$ENV:ComputerName\$env:USERNAME" -Path $SharePath
        }
        If ( $_ -eq 2 ) {
            Write-Output "Editing NTFS Permission to $Script:TestPath AccessRights=FullControl, AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account BUILTIN\Users"
            Get-NTFSAccess -Path $SharePath -Account "BUILTIN\Users" | Remove-NTFSAccess
            Add-NTFSAccess -Path $SharePath -AccessRights FullControl -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Allow -Account "BUILTIN\Users" 
            Write-Output "Removing ACL for $ENV:ComputerName\Administrator on $SharePath"
            Get-NTFSAccess -Path $SharePath -Account "$ENV:ComputerName\Administrator" | Remove-NTFSAccess
            Write-Output "Revoking Access to Share$($_) for Account BUILTIN\Guests"
            Revoke-SMBShareAccess -Name "Share$($_)" -AccountName "BUILTIN\Guests" -Force | Out-Null
        }
        If ( $_ -eq 3 ) {
            Write-Output "Editing NTFS Permission to $Script:TestPath AccessRights=FullControl, AppliesTo ThisFolderSubfoldersAndFiles -AccessType Deny -Account BUILTIN\Guests"
            Get-NTFSAccess -Path $SharePath -Account "BUILTIN\Guests" | Remove-NTFSAccess
            Add-NTFSAccess -Path $SharePath -AccessRights Read -AppliesTo ThisFolderSubfoldersAndFiles -AccessType Deny -Account "BUILTIN\Guests"
            Write-Output "Granting Full Access to Share$($_) for Account BUILTIN\Guests"
            Grant-SMBShareAccess -Name "Share$($_)" -AccountName "BUILTIN\Guests" -AccessRight Full -Force | Out-Null
        }
        If ( $_ -eq 4 ) {
            Write-Output "Removing Share$($_)"
            Get-SMBShare -Name "Share$($_)" | Remove-SMBShare -Force
        }

    }
} # Test-ACLReportToolsModifyACLs
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsRemoveShares {
    # Cleanup
    Get-SMBShare -Name "Share*" | Remove-SMBShare -Force
    Remove-Item $Script:TestPath -Recurse -Force
} # Test-ACLReportToolsRemoveShares
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsPathFiles {
    
    # Create a Baseline Report on the File Folders
	$BaselinePathFile1 = New-ACLPathFileReport -Path (1..$Script:MaxShares | Foreach-Object {Join-Path -Path $Script:TestPath -ChildPath "Share$($_)"} )
    $BaselinePathFile1 | Export-ACLReport -Path "$ENV:Temp\ACLReportTools.Baseline.PathFile.Report.acl" -Force
    $BaselinePathFile2 = Import-ACLReport -Path "$ENV:Temp\ACLReportTools.Baseline.PathFile.Report.acl"

    # Compare the Baseline to the current ACLs on the File Folders (should always be the same).
    $DifferencesPathFile = Compare-ACLReports -Baseline $BaselinePathFile2 -Path (1..$Script:MaxShares | Foreach-Object {Join-Path -Path $Script:TestPath -ChildPath "Share$($_)"} )
    If ($DifferencesPathFile -ne $null) {
        Write-Error "The Compare-ACLReports returned differences to Path/File ACLs when there should be none"
    }
    
    Test-ACLReportToolsModifyACLs

    # Compare the Baseline to the current ACLs on the File Folders (should always be DIFFERENT).
    $DifferencesPathFile = Compare-ACLReports -Baseline $BaselinePathFile2 -Path (1..$Script:MaxShares | Foreach-Object {Join-Path -Path $Script:TestPath -ChildPath "Share$($_)"} )
    If ($DifferencesPathFile.Count -ne 8) {
        Write-Error "The Compare-ACLReports returned $($DifferencesPathFile.Count) Differences to Path/File ACLs - Expected 8"
    }
    "Differences for Path/File Report" | Out-Default
    "--------------------------------" | Out-Default
    $DifferencesPathFile | fl *
	$DifferencesPathFile | Export-ACLDiffReport -Path "$ENV:Temp\ACLReportTools.Difference.PathFile.Report.acr" -Force
	$Comparison = Import-ACLDiffReport -Path "$ENV:Temp\ACLReportTools.Difference.PathFile.Report.acr"
	$DifferencesPathFile | Export-ACLPermissionDiffHTML -Path "$ENV:Temp\ACLReportTools.Difference.PathFile.Report.htm" -Force
} # Function Test-ACLReportToolsPathFiles
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsShares {
    
    # Test Get Shares
    Get-ACLShare | Out-Default
	Get-ACLShare -ComputerName Localhost | Out-Default

    # Create a Baseline Report on the Shares
	$BaselineShares1 = New-ACLShareReport -Include (1..$Script:MaxShares | Foreach-Object { "Share$($_)" } )
    $BaselineShares1 | Export-ACLReport -Path "$ENV:Temp\ACLReportTools.Baseline.Shares.Report.acl" -Force
    $BaselineShares2 = Import-ACLReport -Path "$ENV:Temp\ACLReportTools.Baseline.Shares.Report.acl"

    # Compare the Baseline to the current ACLs on the Shares (should always be the same).
    $DifferencesShares = Compare-ACLReports -Baseline $BaselineShares2 -Include (1..$Script:MaxShares | Foreach-Object { "Share$($_)" } )
    If ($DifferencesShares -ne $null) {
        Write-Error "The Compare-ACLReports returned differences to Share ACLs when there should be none"
    }

    Test-ACLReportToolsModifyACLs

    # Compare the Baseline to the current ACLs on the Shares (should always be DIFFERENT).
    $DifferencesShares = Compare-ACLReports -Baseline $BaselineShares2 -Include (1..$Script:MaxShares | Foreach-Object { "Share$($_)" } )
    If ($DifferencesShares.Count -ne 10) {
        Write-Error "The Compare-ACLReports returned $($DifferencesShares.Count) differences to Share ACLs - Expected 10"
    }
    "Differences for Shares Report" | Out-Default
    "-----------------------------" | Out-Default
    $DifferencesShares | fl *
	$DifferencesShares | Export-ACLDiffReport -Path "$ENV:Temp\ACLReportTools.Difference.Shares.Report.acr" -Force
	$Comparison = Import-ACLDiffReport -Path "$ENV:Temp\ACLReportTools.Difference.Shares.Report.acr"
	$DifferencesShares | Export-ACLPermissionDiffHTML -Path "$ENV:Temp\ACLReportTools.Difference.Shares.Report.htm" -Force
} # Function Test-ACLReportToolsShares
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsLoadModule {
	Get-Module ACLReportTools | Remove-Module
	Import-Module "$PSScriptRoot\ACLReportTools"
} # Function Test-ACLReportLoadModule
##########################################################################################################################################
Test-ACLReportToolsCreateShares
Test-ACLReportToolsLoadModule
Test-ACLReportToolsPathFiles
#Test-ACLReportToolsShares
Test-ACLReportToolsRemoveShares