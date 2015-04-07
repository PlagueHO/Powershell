Workflow Optimize-VHDsWorkflow
{
<#
  .SYNOPSIS
  Workflow that optimizes all VHD/VHDx files attached to the Hyper-V VMs on a list of computers.

  .DESCRIPTION
  This workflow will perform a specified optimization on all VHD/VHDx files attached to a list of Hyper-V VMs on specific computers in
  parallel.

  If the ComputerName parameter is set but the VMName parameter is not set then all VHD/VHDx files attached to all VMs on the computers
  specified in the ComputerName parameter will be optimized.

  If the VMName parameter is set but the ComputerName parameter is not set the all VHD/VHDx files attached to any VMs on the current machine with names in the list specified in the VMWare parameter will be optimized.
        
  .PARAMETER ComputerName
  The list of computers that contain the VMs that will have their VHD/VHDx files optimized. If this parameter is not specified then it will default to the local computer.

  .PARAMETER VMName
  The list of Hyper-V VMs that will have their VHD/VHDx files optimized for. If this parameter is not specified then it will default to all the VMs on each computer.
  
  .PARAMETER AllowRestart
  If a VM is running when the workflow is called, setting this parameter will allow the VM to be stopped and then restarted automatically after optimization.
  
  The VM will be stopped using a guest OS shutdown. This requires the guest OS to be running and the Hyper-V Integration tools be installed and running on the guest.
  If the guest OS can not be shutdown properly the VHD/VHDx files will not be optimized but the workflow will continue.

  .PARAMETER Mode
  Specifies the mode in which the virtual hard disk is to be optimized. For a VHD disk, the default mode is Full. For a VHDX disk, the default mode is Quick. Valid modes are as follows:
        
  --Full scans for zero blocks and reclaims unused blocks. (Allowable only if the virtual hard disk is mounted read-only.)
        
  --Pretrimmed performs as Quick mode, but does not require the virtual hard disk to be mounted read-only. The detection of unused space is less effective than Quick mode (in which the virtual hard disk had been mounted 
  read-only) because the scan cannot query information about free space in the NTFS file system within the virtual hard disk. Useful when the VHDX-format file has been used by operating system instances that are at least 
  Windows 8 or Windows Server 2012, or when this cmdlet has already been run on a .vhdx file in Retrim mode.
        
  --Prezeroed performs as Quick mode, but does not require the virtual hard disk to be mounted read-only. The unused space detection will be less effective than if the virtual hard disk had been mounted read-only as the 
  scan will be unable to query information about free space in the NTFS file system within the virtual hard disk. Useful if a tool was run previously to zero all the free space on the virtual disk as this mode of 
  compaction can then reclaim that space for subsequent block allocations. This form of compaction can also be useful in handling virtual hard disk containing file systems other than NTFS.
        
  --Quick reclaims unused blocks, but does not scan for zero blocks. (Allowable only if the virtual hard disk is mounted read-only.)
        
  --Retrim sends down retrims without scanning for zero blocks or reclaiming unused blocks. (Allowable only if the virtual hard disk is mounted read-only.) 

  .EXAMPLE
   Optimize-VHDsWorkflow -AllowRestart -Mode Full
  Optimize all VHD/VHDx files attached to VMs on the machine the workflow is run on. Full optimization mode will be used and any running VMs will be stopped and restarted after optimization is complete.
  
  .EXAMPLE
   Optimize-VHDsWorkflow -ComputerName HV-01,HV-02 -VMName NTB01,NTB02,NTB03 -Mode Quick
  Optimize all VHD/VHDx files attached any VMs names NTB01,NTB02 or NTB03 on the machines HV-01 and HV-02. Quick optimization mode will be used and only VHD/VHDx files on stopped VMs will be optimized.
#>
    Param (
        [string[]]
        $ComputerName,

        [String[]]
        $VMName,

        [Switch]
        $AllowRestart,

        [ValidateSet("Full", "Pretrimmed", "Prezeroed", "Quick", "Retrim")]
        [String]
        $Mode
    ) # Param
    
    # If no VHD Optimize mode was provided, use quick.
    If (($Mode -eq '') -or ($Mode -eq $null)) {
        $Mode = "Quick"
    }

    If (($ComputerName -eq '') -or ($ComputerName -eq $null)) {
        $ComputerName = $env:COMPUTERNAME
    }

    Foreach -parallel ($Computer in $ComputerName) {
        Write-Verbose "Beginning Optimization of VM VHDs on $Computer"
        # Get a list of all VM Names.
        If (($VMName -eq $null) -or ($VMName -eq '')) {
            $VMNames = (Get-VM -ComputerName $Computer).Name
        } Else {
            $VMNames = (Get-VM -ComputerName $Computer -Name $VMName).Name
        }

        Foreach -parallel ($VMName in $VMNames)
        {
            Write-Verbose "Beginning processing VM $VMName on $Computer"
            [Boolean]$Running = ((Get-VM -ComputerName $Computer -Name $VMName).State -eq 'Running')
            If ( $Running ) {
                If ( $AllowRestart ) {
                    Sequence {
                        # VM is running so need to shut it down before trying to optimize the disks
                        Write-Verbose -Message "Stopping VM $VMName on $Computer"
                        Stop-VM -ComputerName $Computer -Name $VMName
                        # Optimize the disks
                        Write-Verbose -Message "Optimizing VM $VMName VHDs on $Computer"
                        Get-VMHardDiskDrive -VMName $VMName -ComputerName $Computer | Optimize-VHD -Mode $Mode
                        # VM was running so need to start it back up
                        Write-Verbose -Message "Restarting VM $VMName on $Computer"
                        Start-VM -ComputerName $Computer -Name $VMName
                    } # Sequence
                } Else {
                    Write-Warning -Message "Can't Optimize VM $VMName VHDs on $Computer because it is running. Shut it down first or set the AllowRestart parameter."
                } # ( $AllowRestart )
            } Else {
                # Optimize the disks
                Sequence {
                    Write-Verbose -Message "Optimizing VM $VMName VHDs on $Computer"
                    Get-VMHardDiskDrive -VMName $VMName -ComputerName $Computer | Optimize-VHD -Mode $Mode
                } # Sequence
            } # ( $Running )
            Write-Verbose -Message "Finished Processing VM $VMName on $Computer"
        } # Foreach -Parallel ($VMName in $VMNames)
        Write-Verbose "Finished Optimization of VM VHDs on $Computer"
    } # Foreach -parallel ($Computer in $ComputerName)
} # Workflow Optimize-VHDs

<#
Get-Module HyperVTools | Remove-Module
Import-Module HyperVTools
Optimize-VHDsWorkflow -ComputerName PLAGUE02 -Verbose -AllowRestart -VM "Windows Server 2012 R2 Domain Controller","Windows Server 2012 R2 Domain Member","Windows Server 2012 R2 Domain RODC" -Mode Full
Optimize-VHDsWorkflow -ComputerName PLAGUE02 -Verbose -AllowRestart -VM "Windows Server 2012 R2 Domain Controller","Windows Server 2012 R2 Domain Member","Windows Server 2012 R2 Domain RODC"
Optimize-VHDsWorkflow -Verbose -AllowRestart -VM "Windows Server 2012 R2 Domain Controller","Windows Server 2012 R2 Domain Member","Windows Server 2012 R2 Domain RODC"
Optimize-VHDsWorkflow -ComputerName PLAGUE02 -Verbose -AllowRestart
Optimize-VHDsWorkflow -ComputerName PLAGUE02 -Verbose
Optimize-VHDsWorkflow -ComputerName PLAGUE02 -Verbose -Mode Full
#>