#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

$beforeAllGroups = Get-Date

$vaults = Get-RDMVault

foreach ($vault in $vaults)
{
    Set-RDMCurrentRepository -Repository $vault
    $vaultname = $vault.Name
    Write-Host "Current vault is "$vaultname

    # Get all entries' folder path
    $sessions = Get-RDMSession 
    $allGroups = @()
    foreach($session in $sessions)
    {
        # Split the group folder location for each shortcut
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

    # Get all folders that exist in the database
    $groups = Get-RDMSession | where {$_.ConnectionType -eq "Group"}
    $realGroups = @()
    foreach ($group in $groups) 
    {
        # Split the group folder location for each shortcut
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

    # Sort arrays and extratc virtual folders
    $realGroups = $realGroups | Sort-Object -Property Levels, Name, Group -Unique
    $allGroups = $allGroups | Sort-Object -Property Levels, Name, Group -Unique
    $results = $allGroups | where {$realGroups.Group -notcontains $_.Group}
    $results = $results | Sort-Object -Property Levels, Name, Group -Unique

    # Convert virtual folders in the database
    foreach ($group in $results)
    {
        $name = $group.Name
        $folder = $group.Group
        try
        {
            $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession -ErrorAction Stop
            Update-RDMUI
        }
        catch
        {
            # Split the parent folder
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
                    $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession
                    Update-RDMUI                
                    Write-Host "Virtual folder $name has been successfully created in the database!" 
                }
            }
            $name = $group.Name
            $folder = $group.Group
            $session = New-RDMSession -Name $name -Group $folder -Type Group -SetSession
            Update-RDMUI
        }
        Write-Host "Virtual folder $name has been successfully created in the database!" 
    }
}

$afterCreatingGroups = Get-Date
Write-Host "Time taken to convert virtual folders: $(($afterCreatingGroups).Subtract($beforeAllGroups).Seconds) second(s)"

