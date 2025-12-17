#source: https://forum.devolutions.net/topics/34932/the-poorly-privileged-mans-ad-sync
<#
.SYNOPSIS
  Sync an AD computer container/OU into an RDM vault by creating missing folders and RDP sessions.
.DESCRIPTION
  - Switches to the chosen data source and vault.
  - Resolves the AD scope from an OU name or distinguished name (DN), optionally against a specific DC/GC.
  - Ensures the required folder path exists in RDM before creating sessions.
  - Removes duplicate sessions, prunes orphans, and adds RDP entries for hosts that answer ping and TCP 3389.
  - Set `$readonly = $false` to apply changes; `$true` only prints the intended actions.
.PARAMETERS
  $rdmroot      OU name or DN that represents the top of the sync scope (e.g., CN=Computers,DC=downhill,DC=loc).
  $adServer     Optional domain controller/GC FQDN for lookups (helps with cross-domain targeting).
  $adCredential Optional credential for the target domain (`Get-Credential -UserName 'downhill\\user'`).
  $readonly     Dry-run flag; when `$true`, no changes are written to RDM.
  $dsName       Data source to target.
  $vaultName    Vault/repository to receive the sessions.
.EXAMPLE
  $rdmroot = "CN=Computers,DC=downhill,DC=loc"; $adServer = "downhill.loc"; $adCredential = Get-Credential; $readonly = $false
  Run the script to sync that AD container into the selected vault and actually create the folders/sessions.
.NOTES
  Requires Devolutions.PowerShell, AD module, and write rights to the target RDM vault when `$readonly = $false`.
#>

# Check whether the RDM PowerShell module is installed; install it for the current user if missing.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Data source and vault you want to target.
$dsName   = "CHANGEME-DATASOURCE"
$vaultName = "CHANGEME-VAULT"
# Define the top-level OU in RDM that mirrors the AD structure and control mutation behavior.
# You can use either an OU name or a distinguished name. Using a DN avoids ambiguity when names repeat.
$rdmroot = "CHANGEME-RDM-ROOT"
# Optional: target a specific AD domain controller/GC (e.g., for cross-domain queries).
$adServer = "CHANGEME-AD-SERVER"
# Optional: credentials for the target domain (use Get-Credential)
$adCredential = $null
# Example to set credentials (uncomment and edit as needed):
# $adCredential = Get-Credential -UserName "domain\\user"
$readonly = $true # Set to $false to allow modifications in RDM (use with caution).
$script:rdmGroupCache = @()

# Set the current data source and vault.
$ds = Get-RDMDataSource -Name $dsName
Set-RDMCurrentDataSource $ds

$vault = Get-RDMRepository | Where-Object { $_.Name -eq $vaultName }
Set-RDMCurrentRepository $vault

function Resolve-ADRootObject {
    param(
        [string]$Root,
        [string]$Server,
        $Credential
    )
    if ([string]::IsNullOrWhiteSpace($Root)) {
        throw "rdmroot is empty. Provide an OU name or a distinguished name."
    }

    $cleanRoot = $Root.Trim().TrimEnd(';')

    # If the value looks like a distinguished name (contains '='), resolve directly.
    if ($cleanRoot -match "=") {
        try {
            if ([string]::IsNullOrWhiteSpace($Server)) {
                return Get-ADObject -Identity $cleanRoot -Properties CanonicalName,DistinguishedName -Credential $Credential -ErrorAction Stop
            } else {
                return Get-ADObject -Server $Server -Identity $cleanRoot -Properties CanonicalName,DistinguishedName -Credential $Credential -ErrorAction Stop
            }
        } catch {
            throw "AD object with distinguished name '$cleanRoot' was not found. $_"
        }
    }

    # Otherwise resolve by name filter; must return exactly one object.
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $matches = Get-ADObject -Filter "name -eq '$cleanRoot'" -Properties CanonicalName,DistinguishedName -Credential $Credential
    } else {
        $matches = Get-ADObject -Server $Server -Filter "name -eq '$cleanRoot'" -Properties CanonicalName,DistinguishedName -Credential $Credential
    }
    if (-not $matches) {
        throw "Active Directory object named '$cleanRoot' was not found. Use the exact OU name or supply its distinguished name."
    }
    if ($matches.Count -gt 1) {
        $choices = $matches | Select-Object -ExpandProperty DistinguishedName
        throw "Multiple AD objects found for name '$cleanRoot'. Set rdmroot to the specific distinguished name. Found: $($choices -join '; ')"
    }
    return $matches | Select-Object -First 1
}

function Get-RDMGroupCache {
    if (-not $script:rdmGroupCache -or $script:rdmGroupCache.Count -eq 0) {
        $script:rdmGroupCache = Get-RDMSession | Where-Object { $_.ConnectionType -eq "Group" } | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_.Group)) { $_.Name } else { "$($_.Group)\$($_.Name)" }
        }
    }
    return $script:rdmGroupCache
}

function Ensure-RDMGroupPath {
    param([string]$GroupPath)
    if ([string]::IsNullOrWhiteSpace($GroupPath)) { return }

    $null = Get-RDMGroupCache
    $segments = $GroupPath -split "\\"
    $currentParent = ""
    foreach ($segment in $segments) {
        $currentPath = if ([string]::IsNullOrWhiteSpace($currentParent)) { $segment } else { "$currentParent\$segment" }
        if ($script:rdmGroupCache -notcontains $currentPath) {
            $groupParam = if ([string]::IsNullOrWhiteSpace($currentParent)) { $null } else { $currentParent }
            if ($readonly) {
                Write-Host "New-RDMSession -Name '$segment' -Group '$currentParent' -Type Group -SetSession"
                $script:rdmGroupCache += $currentPath
            } else {
                New-RDMSession -Name $segment -Group $groupParam -Type Group -SetSession | Out-Null
                $script:rdmGroupCache += $currentPath
            }
        }
        $currentParent = $currentPath
    }
}

function Convertto-RDMGroupName ([string]$CanonicalName){
    # Build the target RDM group path from an AD computer's canonical name.
    $rdmgroups = $rdmsessions | where {$_.ConnectionType -like "RDPConfigured"} | select -ExpandProperty group | sort -Unique
    $firstmatch = $CanonicalName -match ".*${rdmroot}*(.*)"
    $patha = $Matches.1
    $pathb = $patha -split "/"
    $pathb = ($pathb | select -SkipLast 1) -join '\'
    $name = $rdmroot + $pathb
    $rdmgroup = $rdmgroups -like $name
    if ($rdmgroup) {
        return $rdmgroup
    } else {
        return $name
    }
}

function Convertto-ADCanonical ($rdmsessionobject){
    # Produce the expected AD canonical path for a given RDM session to validate existence.
    $name = $rdmsessionobject.name
    $group = $rdmsessionobject.group
    $patha= $group -split "\\"
    $pathb = ($patha | select -Skip 1) -join "/"
    return $adrootCanonicalName + "/" + $pathb + "/" + $name
}
    
function Remove-RDMDuplicates {
    # Identify duplicate sessions inside each RDM group and optionally remove extras, keeping the newest.
    $rdmsessions = get-rdmsession | where {$_.Group -like "${rdmroot}*"}
    $rdmgroups = $rdmsessions | where {$_.ConnectionType -like "RDPConfigured"} | select -ExpandProperty group | sort -Unique
    foreach ($rdmgroup in $rdmgroups){
        $rdmgroupsessions = $rdmsessions | where {$_.group -like $rdmgroup -and $_.ConnectionType -like "RDPConfigured"}
        $rdmgroupsessionsnames = $rdmgroupsessions.name | sort -Unique
        foreach ($rdmgroupsessionsname in $rdmgroupsessionsnames){
            $arrayrdmgroupsessions = @($rdmgroupsessions | where {$_.name -eq $rdmgroupsessionsname} | sort CreationDateTime -Descending)
            $arrayrdmgroupsessionscount = ($arrayrdmgroupsessions).Count
            if ($arrayrdmgroupsessionscount -gt 1){
                Write-Host "Warning, $arrayrdmgroupsessionscount duplicate(s) found for `"$rdmgroupsessionsname`""
                if ($readonly){
                    $arrayrdmgroupsessions | select -Skip 1 | %{
                        Write-Host "remove-rdmsession -ID $($_.id) -force"
                    }
                } else {
                    $arrayrdmgroupsessions | select -Skip 1 | %{
                        remove-rdmsession -ID $_.id -force
                    }
                }
            }
        }
    }
}

function Remove-RDMOrphans {
    # Remove sessions that no longer have a corresponding AD computer object.
    $rdmsessions = get-rdmsession | where {$_.Group -like "${rdmroot}*"}
    $rdmgroups = $rdmsessions | where {$_.ConnectionType -like "RDPConfigured"} | select -ExpandProperty group | sort -Unique
    foreach ($rdmgroup in $rdmgroups){
        $rdmgroupsessions = $rdmsessions | where {$_.group -like $rdmgroup -and $_.ConnectionType -like "RDPConfigured"}
        foreach ($rdmgroupsession in $rdmgroupsessions){
            if ($adcomputers.CanonicalName -match (Convertto-ADCanonical $rdmgroupsession)){
                Write-Debug "AD Object found for $($rdmgroupsession.name)"
            } else {
                Write-Debug "AD Object not found for $($rdmgroupsession.name) ($(Convertto-ADCanonical $rdmgroupsession))"
                if ($readonly){
                    Write-Host "remove-rdmsession -id $($rdmgroupsession.id) -force"
                } else {
                    remove-rdmsession -id $rdmgroupsession.id -force
                }
                    
            }
        }
    }
}

function Add-RDMADobjects {
    # Create new RDP sessions in RDM for AD computers that can be contacted.
    $rdmsessions = get-rdmsession | where {$_.Group -like "${rdmroot}*"}

    foreach ($adcomputer in $adcomputers){
        $rdmname = $adcomputer.name
        $rdmgroup = Convertto-RDMGroupName $adcomputer.CanonicalName
        $found = $rdmsessions | where {$_.name -like $rdmname -and $_.group -like $rdmgroup} 
        if ($found){
            Write-Debug "Found $($adcomputer.name)"
        } else {
            Write-Debug "Did not find $($adcomputer.name)"
            $rdmhost = $rdmname + "." + ($adcomputer.CanonicalName).Split("/")[0]
            Ensure-RDMGroupPath $rdmgroup
            If (Test-Connection -Count 1 -Quiet $rdmhost){
                try {
                    (New-Object System.Net.Sockets.TcpClient).Connect($rdmhost, 3389)
                    Write-Debug "Found RDP, adding entry"
                    if ($readonly){
                        Write-Host "read-only"+"`$session = New-RdmSession -Name $rdmname -group $rdmgroup -host $rdmhost -Type RDPConfigured; Set-RDMSession `$session"
                    } else {
                        $session = New-RDMSession -Name $rdmname -group $rdmgroup -host $rdmhost -Type RDPConfigured 
                        Set-RDMSession $session
                        Write-Host "Added Session $rdmname" 
                    }
                } catch {
                    Write-Debug "Could not connect via RDP. Skipping."
                }
            } else {
                Write-Debug "Could not ping host. Skipping."
            }
        }
    }
}

# Query Active Directory for the computers under the requested OU and capture canonical naming details.
$rdmRootObject = Resolve-ADRootObject -Root $rdmroot -Server $adServer -Credential $adCredential
if ([string]::IsNullOrWhiteSpace($adServer)) {
    $adcomputers = Get-ADComputer -Filter * -SearchBase $rdmRootObject.DistinguishedName -SearchScope 2 -Properties Name,CanonicalName -Credential $adCredential
} else {
    $adcomputers = Get-ADComputer -Server $adServer -Filter * -SearchBase $rdmRootObject.DistinguishedName -SearchScope 2 -Properties Name,CanonicalName -Credential $adCredential
}
$adrootCanonicalName = $rdmRootObject.CanonicalName

Write-Host "Updating RDM Repository"
Update-RDMRepository
Write-Host "Checking for Duplicates"
Remove-RDMDuplicates
Write-Host "Checking for Orphans"
Remove-RDMOrphans
Write-Host "Adding missing objects"
Add-RDMADobjects
