#Requires -Version 2.0

##########################################################################################################################################
# Main CmdLets
##########################################################################################################################################

Function New-ACLShareReport {
<#
.SYNOPSIS

.DESCRIPTION 
     
.PARAMETER ComputerName
This is the computer to get the shares from. If this parameter is not set it will default to the current machine.

.PARAMETER Include
This is a list of shares to include from the computer. If this parameter is not set it will default to including all shares. This parameter can't be set if the Exclude parameter is set.

.PARAMETER Exclude
This is a list of shares to exclude from the computer. If this parameter is not set it will default to excluding no shares. This parameter can't be set if the Include parameter is set.

.EXAMPLE 
 New-ACLShareReport -ComputerName CLIENT01

.EXAMPLE 
 New-ACLShareReport -ComputerName CLIENT01 -Include MyShare,OtherShare

.EXAMPLE 
 New-ACLShareReport -ComputerName CLIENT01 -Exclude SysVol
#>
    [CmdLetBinding()]
    Param(
        [String]$ComputerName='Localhost',

        [String[]]$Include,

        [String[]]$Exclude
    ) # param

} # Function New-ACLShareReport

Function Compare-ACLShareReport {
<#
.SYNOPSIS

.DESCRIPTION 
     
.PARAMETER ComputerName
This is the computer to get the shares from. If this parameter is not set it will default to the current machine.

.PARAMETER Include
This is a list of shares to include from the computer. If this parameter is not set it will default to including all shares. This parameter can't be set if the Exclude parameter is set.

.PARAMETER Exclude
This is a list of shares to exclude from the computer. If this parameter is not set it will default to excluding no shares. This parameter can't be set if the Include parameter is set.

.EXAMPLE 
 Compare-ACLShareReport -ComputerName CLIENT01

.EXAMPLE 
 Compare-ACLShareReport -ComputerName CLIENT01 -Include MyShare,OtherShare

.EXAMPLE 
 Compare-ACLShareReport -ComputerName CLIENT01 -Exclude SysVol
#>
    [CmdLetBinding()]
    Param(
        [String]$ComputerName='Localhost',

        [String[]]$Include,

        [String[]]$Exclude
    ) # param

} # Function Compare-ACLShareReport



##########################################################################################################################################
# Support CmdLets
##########################################################################################################################################

Function Get-Shares {
<#
.SYNOPSIS
Gets all the Shares on a specified computer.

.DESCRIPTION 
This function will pull a list of shares that are set up on the specified computer. Shares can also be included or excluded from the share list by setting the Include or Exclude properties.

The Cmdlet returns an array of ACLReportTools.Share objects.
     
.PARAMETER ComputerName
This is the computer to get the shares from. If this parameter is not set it will default to the current machine.

.PARAMETER Include
This is a list of shares to include from the computer. If this parameter is not set it will default to including all shares. This parameter can't be set if the Exclude parameter is set.

.PARAMETER Exclude
This is a list of shares to exclude from the computer. If this parameter is not set it will default to excluding no shares. This parameter can't be set if the Include parameter is set.

.EXAMPLE 
 Get-Shares -ComputerName CLIENT01
 Returns a list of all shares set up on the CLIENT01 machine.

.EXAMPLE 
 Get-Shares -ComputerName CLIENT01 -Include MyShare,OtherShare
 Returns a list of shares that are set up on the CLIENT01 machine that are named either MyShare or OtherShare.

.EXAMPLE 
 Get-Shares -ComputerName CLIENT01 -Exclude SysVol
 Returns a list of shares that are set up on the CLIENT01 machine that are not called SysVol.

.EXAMPLE 
 Get-Shares -ComputerName CLIENT01,CLIENT02
 Returns a list of shares that are set up on the CLIENT01 and CLIENT02 machines.

.EXAMPLE 
 Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SysVol
 Returns a list of shares that are set up on the CLIENT01 and CLIENT02 machines that are not called SysVol.
#>
    [CmdLetBinding()]
    Param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [String[]]$ComputerName=$env:computername,

        [String[]]$Include,

        [String[]]$Exclude
    ) # param
    Begin {
        [ACLReportTools.Share[]]$SelectedShares = $null
    } # Begin
    Process {
        Foreach ($Computer in $ComputerName) {
            Write-Verbose "Getting shares list on computer $Computer"
            [Array]$AllShares = Get-WMIObject -Class win32_share -ComputerName $Computer |
                Where-Object { $_.Name -notlike "*$" } |
                select -ExpandProperty Name
            Foreach ($Share in $AllShares) {
                If ($Include.Count -gt 0) {
                    If ($Share -in $Include) {
                        Write-Verbose "$Share on computer $Computer Included"
                        $SelectedShares += New-ShareObject -ComputerName $Computer -ShareName $Share 
                    } Else {
                        Write-Verbose "$Share on computer $Computer Not Included"
                    }
                } Elseif ($Exclude.Count -gt 0) {
                    If ($Share -in $Exclude) {
                        Write-Verbose "$Share on computer $Computer Excluded"
                    } Else {
                        Write-Verbose "$Share on computer $Computer Not Excluded"
                        $SelectedShares += New-ShareObject -ComputerName $Computer -ShareName $Share
                    }
                } Else {
                    Write-Verbose "$Share on computer $Computer Included"
                    $SelectedShares += New-ShareObject -ComputerName $Computer -ShareName $Share
                } # If
            } # Foreach ($Share in $AllShares)
        } # Foreach ($Computer In $ComputerName)
    } # Process
    End {
        Return $SelectedShares
    } # End
} # Function Get-Shares

function Get-ShareACLs {
<#
.SYNOPSIS
Gets the ACLs for a specified Share.

.DESCRIPTION 
This function will return the share ACLs for the specified share.
     
.PARAMETER ComputerName
This is the computer to get the share ACLs from. If this parameter is not set it will default to the current machine.

.PARAMETER ShareName
This is the share name to pull the share ACLs for.

.PARAMETER Shares
This is a pipeline parameter that should be used for passing in a list of shares and computers to pull ACLs for. This parameter expects an array of [ACLReportTools.Share] objects.

This parameter is usually used with the Get-Shares CmdLet.

For example:

Get-Shares -ComputerName CLIENT01,CLIENT02 -Exclude SYSVOL | Get-ShareACLs 

.EXAMPLE 
 Get-ShareACLs -ComputerName CLIENT01 -ShareName MyShre
 Returns the share ACLs for the MyShare Share on the CLIENT01 machine.
#>
    [CmdLetBinding()]
    Param(
        [Parameter(
            ParameterSetName='ByParameters')]
        [String]$ComputerName=$env:computername,
        
        [Parameter(
            ParameterSetName='ByParameters')]
        [String]$ShareName,

        [Parameter(
            ParameterSetName='ByPipeline',
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ACLReportTools.Share[]]$Shares
    ) # param

    Begin {
        # Create an empty array to store all the Share ACLs.
        [ACLReportTools.Permission[]]$share_acls = $null
    } # Begin
    Process {
        If ($PsCmdlet.ParameterSetName -eq 'ByPipeline') {
            $ComputerName = $_.ComputerName
            $ShareName = $_.Name
        }
        $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$ShareName'"  -ComputerName $ComputerName 
        try {  
            $SD = $objShareSec.GetSecurityDescriptor().Descriptor
            Foreach($ace in $SD.DACL){   
                $UserName = $ace.Trustee.Name
                If ($ace.Trustee.Domain -ne $Null)  {$UserName = "$($ace.Trustee.Domain)\$UserName" }    
                If ($ace.Trustee.Name -eq $Null) { $UserName = $ace.Trustee.SIDString }      
                $fs_rule = New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)
                $acl_object =  New-ACLObject -Type 'Share' -ComputerName $ComputerName -Path "\\$ComputerName\$ShareName\" -Access $fs_rule
                $share_acls += $acl_object
           } # Foreach           
        } catch { 
            Write-Error "Unable to obtain share ACLs for $ShareName"
        } # Try
    } # Process
    End {
        Return $share_acls
    } # End
} # function Get-ShareACLs

function Get-ShareFileACLs {
<#
.SYNOPSIS
Gets all the non inherited file/folder ACLs definited within a specified Share.

.DESCRIPTION 
This function will return a list of non inherited file/folder ACLs for the specified share. If the Recurse switch is used then files/folder ACLs will be scanned recursively.
     
.PARAMETER ComputerName
This is the computer to get the share ACLs from. If this parameter is not set it will default to the current machine.

.PARAMETER ShareName
This is the share name to pull the file/folder ACLs for.

.PARAMETER Recurse
Setting this switch will cause the non inherited file/folder ACLs to be pulled recursively.

.EXAMPLE 
 Get-ShareFileACLs -ComputerName CLIENT01 -ShareName MyShare
 Returns the file/folder ACLs for the root of MyShare Share on the CLIENT01 machine.

.EXAMPLE 
 Get-ShareFileACLs -ComputerName CLIENT01 -ShareName MyShare -Recurse
 Returns the file/folder ACLs for all files/folders recursively inside the MyShare Share on the CLIENT01 machine.
#>    
    [CmdLetBinding()]
    Param(
        [Parameter(
            ParameterSetName='ByParameters')]
        [String]$ComputerName=$env:computername,
        
        [Parameter(
            ParameterSetName='ByParameters')]
        [String]$ShareName,

        [Parameter(
            ParameterSetName='ByPipeline',
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ACLReportTools.Share[]]$Shares,

        [Switch]$Recurse
    ) # param

    Begin {
        # Create an empty array to store all the non inherited file/folder ACLs.
        [ACLReportTools.Permission[]]$file_acls = $null
    } # Begin
    Process {
        If ($PsCmdlet.ParameterSetName -eq 'ByPipeline') {
            $ComputerName = $_.ComputerName
            $ShareName = $_.Name
        }
        # Now generate the root file/folder ACLs 
        $root_file_acl = Get-Acl -Path "\\$ComputerName\$ShareName"   
        Foreach ($access in $root_file_acl.Access) {
            # Write each non-inherited ACL from the root into the array of ACL's 
            $purepath = $root_file_acl.Path.Substring($root_file_acl.Path.IndexOf("::\\")+2)
            $owner = $root_file_acl.Owner
            $group = $root_file_acl.Group
            $SDDL = $root_file_acl.SDDL
            $acl_object =  New-ACLObject -Type 'Folder' -ComputerName $ComputerName -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
            $file_acls += $acl_object
        } # Foreach
        If ($Recurse) {
            # Generate any non-inferited file/folder ACLs for subfolders and/or files containined within the share recursively
            $node_file_acls = Get-ChildItem -Path "\\$ComputerName\$ShareName\" -Recurse |
                 Get-ACL |
                 Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::\\")+2)} },Owner,Group,Access,SDDL
            Foreach ($node_file_acl in $node_file_acls) {
                Foreach ($access in $node_file_acl.Access) {
                    If (-not $access.IsInherited) {
                        # Write each non-inherited ACL from the file/folder into the array of ACL's 
                        If ($node_file_acl.PSChildName -eq '') { $type = 'Folder' } else { $type = 'File' }
                        $purepath = $node_file_acl.PurePath
                        $owner = $node_file_acl.Owner
                        $group = $node_file_acl.Group
                        $SDDL = $node_file_acl.SDDL
                        $acl_object =  New-ACLObject -Type $type -ComputerName $ComputerName -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
                        $file_acls += $acl_object
                    } # If
                } # Foreach
            } # Foreach
        } # If
    } # Process
    End {
        Return $file_acls
    } # End
} # Function Get-ShareFileACLs

function Get-PathFileACLs {
<#
.SYNOPSIS
Gets all the non inherited file/folder ACLs definited within a specified Path.

.DESCRIPTION 
This function will return a list of non inherited file/folder ACLs for the specified share. If the Recurse switch is used then files/folder ACLs will be scanned recursively.
     
.PARAMETER Path
This is the path to pull the file/folder ACLs for.

.PARAMETER Recurse
Setting this switch will cause the non inherited file/folder ACLs to be pulled recursively.

.EXAMPLE 
 Get-PathFileACLs -Path C:\Users
 Returns the file/folder ACLs for the root of C:\Users folder.

.EXAMPLE 
 Get-PathFileACLs -ShareName MyShre -Recurse
 Returns the file/folder ACLs for all files/folders recursively inside the C:\Users folder.
#>    
    [CmdLetBinding()]
    Param(
        [String]$ComputerName=[Localhost],

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Switch]$Recurse
    ) # param

    # Create an empty array to store all the non inherited file/folder ACLs.
    [array]$file_acls = $null

    # Now generate the root file/folder ACLs 
    $root_file_acl = Get-Acl -Path $path   
    $purepath = $root_file_acl.Path.Substring($root_file_acl.Path.IndexOf("::")+2)
    $owner = $root_file_acl.Owner
    $group = $root_file_acl.Group
    $SDDL = $root_file_acl.SDDL
    Foreach ($access in $root_file_acl.Access) {
        # Write each non-inherited ACL from the root into the array of ACL's 
        $acl_object =  New-ACLObject -Type 'Folder' -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
        $file_acls += $acl_object
    } # Foreach
    If ($Recurse) {
        # Generate any non-inferited file/folder ACLs for subfolders and/or files containined within the share recursively
        $node_file_acls = Get-ChildItem -Path $path -Recurse |
             Get-ACL |
             Select-Object -Property @{ l='PurePath';e={$_.Path.Substring($_.Path.IndexOf("::")+2)} },Owner,Group,Access,SDDL
        Foreach ($node_file_acl in $node_file_acls) {
            $purepath = $node_file_acl.PurePath
            $owner = $node_file_acl.Owner
            $group = $node_file_acl.Group
            $SDDL = $node_file_acl.SDDL
            Foreach ($access in $node_file_acl.Access) {
                If (-not $access.IsInherited) {
                    # Write each non-inherited ACL from the file/folder into the array of ACL's 
                    If ($node_file_acl.PSChildName -eq '') { $type = 'Folder' } else { $type = 'File' }
                    $acl_object =  New-ACLObject -Type $type -Path $purepath -Owner $owner -Group $group -SDDL $SDDL -Access $access
                    $file_acls += $acl_object
                } # If
            } # Foreach
        } # Foreach
    } # If
    return $file_acls
} # Function Get-PathFileACLs


function Save-ACLs {
<#
.SYNOPSIS
Saves the ACLs that are in the pipeline as a file.

.DESCRIPTION 
This Cmdlet will save what ever ACLs (ACLReportTools.Permissions) to a file.
     
.PARAMETER Path
This is the path to the ACL output file. This parameter is required.

.PARAMETER InputObject
Specifies the Permissions objects to export to th file. Enter a variable that contains the objects or type a command or expression that gets the objects. You can also pipe ACLReportTools.Permissions objects to Save-ACLs.

.PARAMETER Force
Causes the file to be overwritten if it exists.

.EXAMPLE 
 Save-ACLs -Path C:\ACLReports\server01.acl -InputObject $Acls

 Saves the ACLs in the $Acls variable to the file C:\ACLReports\server01.acl.  If the file exists it will be overwritten if the Force switch is set.

.EXAMPLE 
 Save-ACLs -Path C:\ACLReports\server01.acl -InputObject (Get-Shares -ComputerName SERVER01 | Get-ShareFileACLs -Recurse)

 Saves the file ACLs for all shares on the compuer SERVER01 to the file C:\ACLReports\server01.acl. If the file exists it will be overwritten if the Force switch is set.
#>    
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({$_.GetType().FullName -ne 'ACLReportTools.Permission[]'})]
        [ACLReportTools.Permission[]]$InputObject,

        [Switch]$Force

    ) # param

    Begin {
        If ((Test-Path -Path $Path -PathType Leaf) -and ($force -eq $false)) {
            Write-Error "The file $Path already exists. Use Force to overwrite it."
            return
        }
        [array]$Output = $null
    } # Begin
    Process {
        Foreach ($Permission in $InputObject) {
            $Output += $Permission
        } # Foreach
    } # Process
    End {
        $Output | Export-Clixml -Path $Path -Force
    } # End
} # Function Save-ACLs




##########################################################################################################################################
# Hidden Support CmdLets
##########################################################################################################################################

function Initialize-Module {
<#
.SYNOPSIS
This function creates the a support module containing classes and enums via reflection.

.DESCRIPTION 
This function creates a .net dynamic module via reflection and adds classes and enums to it that are then used by other functions in this module.
#>
    [CmdLetBinding()]
    Param (
        [String]$ModuleName = 'ACLReportTools'
    ) # Param

    $Domain = [AppDomain]::CurrentDomain
    # Do we need to define the Module?
    If (($Domain.GetAssemblies() | Where-Object -FilterScript { $_.FullName -eq "$ModuleName, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null" } | Measure-Object).Count-eq 0) {
        # Define the module
        $DynAssembly = New-Object Reflection.AssemblyName($ModuleName)
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, 'Run')
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule($ModuleName, $False)

        # Define the ACLReportTools.Permission Class
        $Attributes = 'AutoLayout, AnsiClass, Class, Public'
        $TypeBuilder  = $ModuleBuilder.DefineType('ACLReportTools.Permission',$Attributes,[System.Object])
        $TypeBuilder.DefineField('ComputerName', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Type', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Path', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Owner', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Group', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('SDDL', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Access', [Security.AccessControl.AccessRule], 'Public') | Out-Null
        $TypeBuilder.CreateType() | Out-Null

        # Define the ACLReportTools.Share Class
        $Attributes = 'AutoLayout, AnsiClass, Class, Public'
        $TypeBuilder  = $ModuleBuilder.DefineType('ACLReportTools.Share',$Attributes,[System.Object])
        $TypeBuilder.DefineField('ComputerName', [string], 'Public') | Out-Null
        $TypeBuilder.DefineField('Name', [string], 'Public') | Out-Null
        $TypeBuilder.CreateType() | Out-Null

    } # If
} # Function Initialize-Module

function New-ShareObject {
<#
.SYNOPSIS
This function creates an ACLReportTools.Share object and populates it.

.DESCRIPTION 
This function creates an ACLReportTools.Share object from the class definition in the dynamic module ACLREportsModule and assigns the function parameters to the field values of the object.
#>
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ShareName
    ) # Param

    $share_object = New-Object -TypeName 'ACLReportTools.Share'
    $share_object.ComputerName = $ComputerName
    $share_object.Name = $ShareName
    return $share_object
} # function New-ShareObject

function New-ACLObject {
<#
.SYNOPSIS
This function creates an ACLReportTools.Permission object and populates it.

.DESCRIPTION 
This function creates an ACLReportTools.Permission object from the class definition in the dynamic module ACLREportsModule and assigns the function parameters to the field values of the object.
#>
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('File','Folder','Share')]
        [String]$Type,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,
        
        [String]$Owner='',
        
        [String]$Group='',
        
        [String]$SDDL='',

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Security.AccessControl.AccessRule]$Access
    ) # Param

    # Need to correct the $Access objects to ensure the FileSystemRights values correctly converted to string
    # When the "Generic Rights" bits are set: http://msdn.microsoft.com/en-us/library/aa374896%28v=vs.85%29.aspx
    $acl_object = New-Object -TypeName 'ACLReportTools.Permission'
    $acl_object.Type = $Type
    $acl_object.ComputerName = $ComputerName
    $acl_object.Path = $Path
    $acl_object.Owner = $OWner
    $acl_object.Group = $Group
    $acl_object.SDDL = $SDDL
    $acl_object.Access = $Access
    return $acl_object
} # function New-ACLObject

function Convert-FileSystemAccessToString {
<#
.SYNOPSIS

.DESCRIPTION 
#>
    [CmdLetBinding()]
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
<#
.SYNOPSIS

.DESCRIPTION 
#>
    [CmdLetBinding()]
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
<#
.SYNOPSIS

.DESCRIPTION 
#>
    [CmdLetBinding()]
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
} # function Convert-ACEToString

function Convert-FileSystemACLToString {
<#
.SYNOPSIS

.DESCRIPTION 
#>
    [CmdLetBinding()]
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

# Ensure all the custom classes are loaded in available
Initialize-Module

# Export the Module Cmdlets
Export-ModuleMember -Function Get-Shares,Get-ShareACLs,Get-PathFileACLs,Get-ShareFileACLs,Save-ACLs
