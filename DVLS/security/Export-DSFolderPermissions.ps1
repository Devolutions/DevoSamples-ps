<#
.SYNOPSIS
This function exports folder permissions from all vaults.

.DESCRIPTION
This function exports folder permissions from all vaults and replace the IDs with the group name or user name.

.PARAMETER CSVFilePath
N/A

.EXAMPLE
Export-DSFolderPermissions -CSVFilePath "c:\temp"

.NOTES
N/A
#>

function Export-DSFolderPermissions ()
{
    param (
        [Parameter(Mandatory)]
        [string]$CSVFilePath
    )

    $vaults = Get-DSVault -All

    # Browse all vaults
    foreach ($vault in $vaults)
    {
        # CSV file creation
        $filename = $CSVFilePath + "\" + $vault.Name + ".csv"
        Set-Content -Path $filename -Value '"Vault","Path","OverrideType","Right","Principals"'

        # Browse all vault's folders
        $folders = Get-DSFolders -VaultID $vault.ID -IncludeSubFolders
        foreach ($folder in $folders)
        {
            $permissions = Get-DSEntriesPermissions -EntryID $folder.ID

            # Browse all folder's permissions
            foreach ($perm in $permissions)
            {
                $csvFile = [PSCustomObject]@{
                    Vault = $perm.Vault
                    Path = $perm.Path
                    OverrideType = $perm.OverrideType
                    Right = $perm.Right
                    Principals = $perm.Principals
                }
                
                # Replace the IDs by the group name or user name
                if (-not [string]::IsNullOrEmpty(($csvFile.Principals)))
                {
                    $Principals = ""
                    $IDs = ($csvFile.Principals).Split(",")
                    foreach ($ID in $IDs)
                    {
                        $group = Get-DSRole -RoleID $ID -ErrorAction Ignore
                        $user = Get-DSUser -UserID $ID -ErrorAction Ignore

                        if (-not [string]::IsNullOrEmpty($Principals))
                        {
                            $Principals += ","
                        }
                        if ($group)
                        {
                            $Principals += $group.Display
                        }
                        if ($user)
                        {
                            $Principals += $user.Display
                        }
                    }

                    $csvFile.Principals = $Principals
                }

                $csvFile | Export-Csv $fileName -Append
            }
        }
    }

    Close-DSSession 
    Write-Host "Export completed!!!"
}