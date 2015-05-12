##########################################################################################################################################
# Self Test functions
##########################################################################################################################################
Function Test-ACLReportToolsDefault {
    $TestPath = "c:\acltest"
    $MaxShares = 3
    If (-not (Test-Path $TestPath -PathType Container)) {
        New-Item -Path $TestPath -ItemType Directory | Out-Null
    }
    # Create shares
    1..$MaxShares | Foreach-Object {
        $SharePath = Join-Path -Path $TestPath -ChildPath "Share$($_)"
        If (-not (Test-Path $SharePath -PathType Container)) {
            New-Item -Path $SharePath -ItemType Directory | Out-Null
        }
        New-SMBShare -Path $SharePath -Name "Share$($_)" | Out-Null
        Copy-Item -Path "c:\program files\windowspowershell" -Destination $SharePath -Recurse -Force | Out-Null
    }
    # Test Get Shares
    Get-ACLShare | Out-Default
	Get-ACLShare -ComputerName Localhost | Out-Default

    # Create a Baseline Report on the File Folders
	$Baseline1 = New-ACLPathFileReport -Path (1..$MaxShares | Foreach-Object {Join-Path -Path $TestPath -ChildPath "Share$($_)"} )
    $Baseline1 | Export-ACLs -Path "$ENV:Temp\ACLReportTools.Baseline.Report.acl" -Force
    $Baseline2 = Import-ACLs -Path "$ENV:Temp\ACLReportTools.Baseline.Report.acl"

    # Compare the Baseline to the current ACLs on the File Folders (should always be the same).
	$Current1 = New-ACLPathFileReport -Path (1..$MaxShares | Foreach-Object {Join-Path -Path $TestPath -ChildPath "Share$($_)"} )
    $Differences = Compare-ACLReports -Baseline $Baseline2 -With $Current1
    If ($Differences -ne $null) {
        Write-Error "The Compare-ACLReports returned differences when there should be none"
    }

    # Modify some permissions on the File Folders
    1..$MaxShares | Foreach-Object {
        $SharePath = Join-Path -Path $TestPath -ChildPath "Share$($_)"
        $ACL = Get-ACL -Path $TestPath
        Set-ACL -Path $SharePath -AclObject $ACL
    }

    # Compare the Baseline to the current ACLs on the File Folders (should always be DIFFERENT).
	$Current2 = New-ACLPathFileReport -Path (1..$MaxShares | Foreach-Object {Join-Path -Path $TestPath -ChildPath "Share$($_)"} )
    $Differences = Compare-ACLReports -Baseline $Baseline2 -With $Current2
    If ($Differences -eq $null) {
        Write-Error "The Compare-ACLReports returned no differences when there should be some"
    }
    "Differences" | Out-Default
    $Differences

    # Cleanup
    1..$MaxShares | Foreach-Object {
       Remove-SMBShare -Name "Share$($_)" -Force
    }
    Remove-Item $TestPath -Recurse -Force
} # Function Test-ACLReportToolsDefault
##########################################################################################################################################

##########################################################################################################################################
Function Test-ACLReportToolsLoadModule {
	Get-Module ACLReportTools | Remove-Module
	Import-Module "$PSScriptRoot\ACLReportTools"
} # Function Test-ACLReportLoadModule
##########################################################################################################################################

Test-ACLReportToolsLoadModule
Test-ACLReportToolsDefault

