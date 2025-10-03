<#
.SYNOPSIS
  Converts virtual folders in Remote Desktop Manager (RDM) vaults into persisted group entries.

.DESCRIPTION
  This script leverages the Devolutions.PowerShell module to:
  - Enumerate every vault returned by Get-RDMVault and set it as the active repository.
  - Collect all folder paths referenced by Get-RDMSession (including shortcut paths) to detect virtual-only folders.
  - Create any missing group entries with New-RDMSession, ensuring parent folders exist before retrying.
  - Refresh the RDM UI so the new folders become visible immediately.

  Run the script in a context that has access to every target vault and permission to create group entries.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if necessary.
  - Module installation may need an internet connection and a trusted PSGallery repository.

.EXAMPLE
  PS> .\ConvertVirtualFolders.ps1
  Converts all virtual folders to persisted groups across the vaults you can access.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is present before calling any RDM cmdlets.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

$beforeAllGroups = Get-Date

$vaults = Get-RDMVault

foreach ($vault in $vaults)
{
    # Switch the working context to the current vault so that subsequent Get-/New-RDMSession calls target it.
    Set-RDMCurrentRepository -Repository $vault
    $vaultname = $vault.Name
    Write-Host "Current vault is "$vaultname

    # Retrieve every entry within the vault to capture any virtual folder paths that users created on the fly.
    $sessions = Get-RDMSession 
    $allGroups = @()
    foreach($session in $sessions)
    {
        # Each entry may reference multiple shortcut paths (separated by ';'); evaluate each one individually.
        $tempFolder = $session.Group
        $shortcuts = $tempFolder.split(';')

        foreach ($shortcut in $shortcuts)
        {    
            $folder = $shortcut
            if ($folder)
            {
                $levels = $folder.split('\')
                $nblevels = 1
                $Groupfolder = ""
                foreach($level in $levels)
                {
                    $name = $level
                    if ($nblevels -eq 1)
                    {
                        $Groupfolder = $name
                    }
                    else
                    {
                        $Groupfolder = $Groupfolder + "\" + $name
                    }
                    $item = New-Object PSObject -Property @{Name = $name; Group = $Groupfolder; Levels = $nbLevels}
                    $allGroups += $item
                    $nblevels++
                }
            }
        }
    }

    # Enumerate every persisted folder (ConnectionType Group) already stored in the data source.
    $groups = Get-RDMSession | where {$_.ConnectionType -eq "Group"}
    $realGroups = @()
    foreach ($group in $groups) 
    {
        # Expand each persisted folder path recorded in the Group property; it can include multiple shortcuts too.
        $tempFolder = $group.Group
        $shortcuts = $tempFolder.split(';')

        foreach ($shortcut in $shortcuts)
        {    
            $folder = $group.Group
            if ($folder)
            {
                $levels = $folder.split('\')
                $nbLevels = $levels.Count
                $name = $group.Name
                $item = New-Object PSObject -Property @{Name = $name; Group = $folder; Levels = $nbLevels}
                $realGroups += $item
            }
        }
    }

    # Determine which folder paths exist only virtually by removing those already persisted in the data source.
    $realGroups = $realGroups | Sort-Object -Property Levels, Name, Group -Unique
    $allGroups = $allGroups | Sort-Object -Property Levels, Name, Group -Unique
    $results = $allGroups | where {$realGroups.Group -notcontains $_.Group}
    $results = $results | Sort-Object -Property Levels, Name, Group -Unique

    # Persist each missing folder by creating a new `Group` entry via New-RDMSession.
    foreach ($group in $results)
    {
        $name = $group.Name
        $folder = $group.Group
        try
        {
            # Straightforward case: create the folder and refresh the UI when it succeeds.
            $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession -ErrorAction Stop
            Update-RDMUI
        }
        catch
        {
            # If the folder creation fails, ensure each parent folder exists before retrying the requested folder.
            $tempFolder = $folder.Replace("\$name",'')
            $parents = $tempFolder.split('\')
            
            foreach ($parent in $parents)
            {
                try
                {
                    $exist = Get-RDMSession -Name $parent -ErrorAction Stop
                }
                catch
                {
                    $name = $parent
                    $index = $parents.Indexof($parent)
                    $folder = ""
                    for ($item = 0;$item -le $index;$item++)
                    {
                        if ($item -gt 0)
                        {
                            $folder += "\"
                        }
                        $folder += $parents[$item]
                    }
                    # Create the missing parent folder and refresh the UI.
                    $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession
                    Update-RDMUI                
                    Write-Host "Virtual folder $name has been successfully created in the database!" 
                }
            }
            $name = $group.Name
            $folder = $group.Group
            # Retry the original folder creation once all parents exist.
            $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession
            Update-RDMUI
        }
        Write-Host "Virtual folder $name has been successfully created in the database!" 
    }
}

$afterCreatingGroups = Get-Date
Write-Host "Time taken to convert virtual folders: $(($afterCreatingGroups).Subtract($beforeAllGroups).Seconds) second(s)"
