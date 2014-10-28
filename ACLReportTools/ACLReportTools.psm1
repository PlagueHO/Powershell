#Requires -Version 4.0

Function Empty-Function {
<#
.SYNOPSIS
Forces the LCM on destination computer(s) to repull DSC configuration data from a pull server.

.DESCRIPTION 
This function will cause the Local Configuration Manager on the computers listed in the ComputerName parameter to repull the DSC configuration MOF file from the pull server.

The computers listed must already have the LCM correctly configured for pull mode.

The command is executed via a call to Invoke-Command on the destination computer's LCM which will be called via WinRM.
Therefore WinRM must be enabled on the destination computer's LCM and the appropriate firewall ports opened.
     
.PARAMETER ComputerName
This must contain a list of computers that will have the LCM repull triggered on.

.EXAMPLE 
 Invoke-DSCPull -ComputerName CLIENT01,CLIENT02,CLIENT03
 Causes the LCMs on computers CLIENT01, CLIENT02 and CLIENT03 to repull DSC Configuration MOF files from the DSC Pull server.
#>
    [CmdletBinding()]
    Param (
    ) # Param
} # Function Invoke-DSCPull
