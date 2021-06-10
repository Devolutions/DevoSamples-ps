#requires -version 4
<#
.SYNOPSIS
  Mass edit SubConnections (parent/childs) in RDM

.DESCRIPTION
  Mass edit SubConnections in RDM by Un-Parenting SubConnections by ConnectionType, 
  then make the needed edits to the entry and then re-parenting the entry

.PARAMETER <Parameter_Name>

.INPUTS
  Confirmation will be required for EACH Un-Parent

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Eric St-Martin
  Creation Date:  05/05/2021
  Purpose/Change: Initial script development
.EXAMPLE

#>

#-------------------------------[Initialisations]------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#Import Modules & Snap-ins
if ( ! (Get-Module RemoteDesktopManager.PowerShellModule)) {
Import-Module "${env:ProgramFiles(x86)}\Devolutions\Remote Desktop Manager\RemoteDesktopManager.PowerShellModule.psd1"
}

#---------------------------------[Functions]----------------------------------


#---------------------------------[Execution]----------------------------------

# Getting a list of Entries that have SubConnections
$parents = Get-RDMSession | Where-Object SubConnections

# Run the changes
foreach ($parent in $parents)
{
      # Gets the SubConnections where ConnectionType in this case is Sftp
      # This can be tweaked to fit any need. 

      $subcons = $parent.SubConnections | Where-Object ConnectionType -eq "Sftp"
      $child = $subcons

      # Runs the UnParent
      # **PS: There will be a Confirmation prompt for each entry being un-parented
      Invoke-RDMUnparentSession -Session $subcons

      # Changes the Connection type to FTP but again can be tweaked to change anything
      $child.ConnectionType = "Ftp"

      # Saves changes made above
      Set-RDMSession $child -Refresh

      # In this case we wanted to re-parent the entry
      Invoke-RDMParentSession -Session $child -ParentSession $parent  
}
Update-RDMUI

Write-Host "Changes completed!"

#----------------------------------[Closure]-----------------------------------
# If running in the console only, ask to press a key
if ($Host.Name -eq "ConsoleHost")
{
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.FlushInputBuffer()  
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
}
