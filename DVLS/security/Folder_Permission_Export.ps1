<#
.SYNOPSIS
  Interactively export folder permissions from a selected folder in a selected vault.
.DESCRIPTION
  Prompts for:
    1) CSV output folder path (CLI)
    2) Vault selection (UI list)
    3) Folder selection within that vault (UI list)
  Then exports permissions for the selected folder and all its subfolders,
  replacing principal IDs with user/role display names.
.NOTES
  Version:        1.0
  Author:         William Alphonso
  Creation Date: 03-12-2025
#>

# Script Name
$ScriptName = "Folder Permission Export"

# Module import
Import-Module Devolutions.PowerShell

# Script start
Write-Host "$ScriptName started at $(Get-Date)" -ForegroundColor Green

# DVLS connection info
$DVLSURI   = "YOUR DVLS URL"
$AppKey    = "YOUR APP KEY"
$AppSecret = "YOUR APP SECRET"

# Credentials
$secAppSecret = ConvertTo-SecureString $AppSecret -AsPlainText -Force
$credObject   = New-Object System.Management.Automation.PSCredential ($AppKey, $secAppSecret)

# Start DVLS session
$DSSession = New-DSSession -BaseUri $DVLSURI -AsApplication -Credential $credObject
$DSSession

function Export-DSFolderPermissionsInteractive {

    # ---------------------------------------------------------------------
    # 1) CLI prompt for CSV output folder
    # ---------------------------------------------------------------------
    $CSVFolderPath = Read-Host "Enter the folder path where the CSV file should be saved"
    if ([string]::IsNullOrWhiteSpace($CSVFolderPath)) {
        Write-Warning "No path entered. Aborting."
        return
    }

    if (-not (Test-Path $CSVFolderPath)) {
        Write-Host "Folder '$CSVFolderPath' does not exist. Creating it..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $CSVFolderPath -Force | Out-Null
    }

    # ---------------------------------------------------------------------
    # 2) UI – select vault
    # ---------------------------------------------------------------------
    $vaults = Get-DSVault -All

    if (-not $vaults) {
        throw "No vaults found."
    }

    $selectedVault = $vaults |
        Select-Object Name, Id, Description |
        Out-GridView -Title "Select a vault for permission export" -PassThru

    if (-not $selectedVault) {
        Write-Warning "No vault selected. Aborting."
        return
    }

    $vault = $vaults | Where-Object { $_.Id -eq $selectedVault.Id }

    Write-Host "Selected vault: $($vault.Name)" -ForegroundColor Cyan

    # ---------------------------------------------------------------------
    # 3) UI – select root folder in that vault
    # ---------------------------------------------------------------------
    $folders = Get-DSFolders -VaultID $vault.ID -IncludeSubFolders

    if (-not $folders) {
        Write-Warning "No folders found in vault '$($vault.Name)'. Aborting."
        return
    }

    $selectedFolder = $folders |
        Select-Object Name, Path, Id |
        Out-GridView -Title "Select the ROOT folder (permissions will include all subfolders)" -PassThru

    if (-not $selectedFolder) {
        Write-Warning "No folder selected. Aborting."
        return
    }

    $rootFolder = $folders | Where-Object { $_.Id -eq $selectedFolder.Id }
    $RootFolderPath = $rootFolder.Path

    Write-Host "Selected root folder: $RootFolderPath" -ForegroundColor Cyan

    # ---------------------------------------------------------------------
    # Prepare CSV file
    # ---------------------------------------------------------------------
    $fileName = Join-Path $CSVFolderPath "$($vault.Name).csv"

    # Initialize CSV with header
    Set-Content -Path $fileName -Value '"Vault","Path","OverrideType","Right","Principals"'

    # ---------------------------------------------------------------------
    # Get root folder + all subfolders
    # ---------------------------------------------------------------------
    $targetFolders = $folders | Where-Object {
        $_.Path -eq $rootFolder.Path -or $_.Path -like "$($rootFolder.Path)/*"
    }

    Write-Host "Exporting permissions for $($targetFolders.Count) folder(s) under '$RootFolderPath' in vault '$($vault.Name)'..." -ForegroundColor Yellow

    # ---------------------------------------------------------------------
    # Export permissions
    # ---------------------------------------------------------------------
    foreach ($folder in $targetFolders) {
        $permissions = Get-DSEntriesPermissions -EntryID $folder.ID

        foreach ($perm in $permissions) {
            $csvFile = [PSCustomObject]@{
                Vault        = $perm.Vault
                Path         = $perm.Path
                OverrideType = $perm.OverrideType
                Right        = $perm.Right
                Principals   = $perm.Principals
            }

            # Replace the IDs by the group name or user name
            if (-not [string]::IsNullOrEmpty($csvFile.Principals)) {
                $Principals = ""
                $IDs = ($csvFile.Principals).Split(",")

                foreach ($rawID in $IDs) {
                    $ID = $rawID.Trim()
                    if ([string]::IsNullOrWhiteSpace($ID)) {
                        continue
                    }

                    # Only proceed if it is a valid GUID
                    $guid = [guid]::Empty
                    if (-not [guid]::TryParse($ID, [ref]$guid)) {
                        # Not a valid GUID => skip, avoids Get-DSRole blowing up
                        continue
                    }

                    $group = $null
                    $user  = $null

                    try {
                        $group = Get-DSRole -RoleID $guid -ErrorAction Stop
                    }
                    catch {
                        $group = $null
                    }

                    try {
                        $user  = Get-DSUser -UserID $guid -ErrorAction Stop
                    }
                    catch {
                        $user = $null
                    }

                    if ($group -or $user) {
                        if (-not [string]::IsNullOrEmpty($Principals)) {
                            $Principals += ","
                        }
                        if ($group) {
                            $Principals += $group.Display
                        }
                        elseif ($user) {
                            $Principals += $user.Display
                        }
                    }
                }

                $csvFile.Principals = $Principals

            }

            $csvFile | Export-Csv $fileName -Append -NoTypeInformation
        }
    }

    Write-Host "Export completed! CSV written to: $fileName" -ForegroundColor Green
}

# Run the interactive export
Export-DSFolderPermissionsInteractive

