<#
.SYNOPSIS
  Adjusts default colors and images on Remote Desktop Manager (RDM) entries.

.DESCRIPTION
  This script ensures the Devolutions.PowerShell module is present before exposing two helper functions:
  - `Set-RDMDefaultSessionColor` assigns a stock color to any session or folder by updating its `ImageName` metadata.
  - `Set-RDMImage` applies a specific built-in icon (and matching color accent) to a session for quick visual cues.

  Both functions optionally switch the active data source and vault prior to updating the targeted session.

.NOTES
  - Requires the Devolutions.PowerShell module; install it first if not already registered.
  - Original discussion: https://forum.devolutions.net/topics/34454/changing-different-properties-on-sessions

.EXAMPLE
  PS> Set-RDMDefaultSessionColor -Color Green -Session $sessionId -Vault "Production" -DataSource "Main"
  PS> Set-RDMImage -Image "FlagGreen" -Session $sessionId -Vault "Production"
  Updates the session color and icon for the entry identified by `$sessionId`.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}


function Set-RDMDefaultSessionColor {
<#
.SYNOPSIS
 Sets the color of an RDM session or folder.
.DESCRIPTION
 Updates the `ImageName` to the desired stock color and persists the entry.
.PARAMETER Color
 Specifies one of the built-in color accents: "Black","Blue","Forest","Grey","Orange","Royal","Yellow","Purple","Black","Red","Green".
.PARAMETER Session
 Session ID of the entry to update.
.PARAMETER Vault
 Optional vault/repository name containing the session.
.PARAMETER DataSource
 Optional data source name containing the vault.
.EXAMPLE
 Set-RDMDefaultSessionColor -Color "Green" -Session "{GUID}" -Vault "Operations" -DataSource "Prod"
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateSet("Black","Blue","Forest","Grey","Orange","Royal","Yellow","Purple","Black","Red","Green")]
        [String]
        $Color,
        [Parameter(Mandatory=$True)]
        [String]
        $Session,
        [Parameter()]
        [String]
        $Vault,
        [Parameter()]
        [String]
        $DataSource
    )
    
    begin {
        # Refresh the UI to synchronize cached data before making changes.
        Update-RDMUI
    }

    process {
        try {
            # Switch data source when specified so the session lookup uses the correct repository list.
            if ($DataSource -ne ""){
                Set-RDMCurrentDataSource "$Datasource"
                Update-RDMUI
            }
            # Switch the active vault when provided to target the correct session container.
            if ($Vault -ne ""){
                Set-RDMCurrentRepository -Repository  $vault
                Update-RDMUI
            }
            # Retrieve the session by ID so we can modify its visual properties.
            $RDMsession = Get-RDMSession | Where-Object {$_.id -eq $Session}
            # Assign the stock color through the ImageName metadata.
            $RDMSession.ImageName = "["+$Color+"]"
            # Persist the update back into the data source.
            Set-RDMSession -Session $RDMsession
        }
        catch {
            Write-Output $Error[0]
        }
    }

    end {
        # Issue a final refresh so the UI reflects the recent changes.
        Update-RDMUI
    }
}


function Set-RDMImage {
    <#
    .SYNOPSIS
     Set the image and color of the entry
    .DESCRIPTION
     This function sets a custom icon and color to an entry in RDM
    .PARAMETER Image
     Specifies the image of the folder
    .PARAMETER Session
    Specifies the session of the folder
    .PARAMETER Vault
    Specifies the vault/repository that contains the session
    .PARAMETER DataSource
    Specifies the Data Source that contains the session
    .EXAMPLE
    Set-RDMImage -image "FlagGreen" -Session $session -vault $vault -DataSource $datasource
    #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$True)]
            [String]
            $Image,
            [Parameter(Mandatory=$True)]
            [String]
            $Session,
            [Parameter()]
            [String]
            $Vault,
            [Parameter()]
            [String]
            $DataSource
        )
        
        begin {
            # Refresh the UI at the beginning to maintain a valid session context.
            Update-RDMUI
        }

        process {
            try {
                # Switch to the requested data source prior to fetching the session.
                if ($DataSource -ne ""){
                    Set-RDMCurrentDataSource "$Datasource"
                    Update-RDMUI
                }
                # Switch to the requested vault so the session lookup hits the correct container.
                if ($Vault -ne ""){
                    Set-RDMCurrentRepository -Repository  $vault
                    Update-RDMUI
                }
                # Retrieve the session by ID and adjust its icon.
                $RDMsession = Get-RDMSession | Where-Object {$_.id -eq $Session}
                # Apply the built-in icon; "Sample" prefix ensures RDM resolves it against internal assets.
                $RDMSession.ImageName = "Sample$Image"
                # Persist the update back into the data source.
                Set-RDMSession -Session $RDMsession
            }
            catch {
                Write-Output $Error[0]
            }
        }

        end {
            # Complete with a refresh so the UI mirrors the latest icon change.
            Update-RDMUI
        }
    }
