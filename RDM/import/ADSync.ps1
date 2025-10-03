#source: https://forum.devolutions.net/topics/34932/the-poorly-privileged-mans-ad-sync
###########################################################################
#
# Synchronize an Active Directory structure with Remote Desktop Manager.
#
###########################################################################

<#
.SYNOPSIS
    Synchronize RDP sessions in Remote Desktop Manager with computers in a given Active Directory OU.
.DESCRIPTION
    Ensures the Devolutions.PowerShell module is available, connects to the specified data source, and gathers
    all AD computer objects beneath the configured OU. The script can report or apply changes: it removes
    duplicate or orphaned RDM sessions and adds new RDP entries for AD computers that respond on TCP 3389.
    By default, `$readonly` prevents destructive changes and prints the intended cmdlets instead.
.NOTES
    Update the data source name, `$rdmroot`, and the `$readonly` flag before running. A domain account with
    rights to query Active Directory is required, and modifications require RDM permissions.
#>

# Check whether the RDM PowerShell module is installed; install it for the current user if missing.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (replace with your RDM data source name before execution).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Define the top-level OU in RDM that mirrors the AD structure and control mutation behavior.
$rdmroot = "[YOUR-TOP-LEVEL-OU-HERE]"
$readonly = $true # Set to $false to allow modifications in RDM (use with caution).

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
            If (Test-Connection -Count 1 -Quiet $rdmhost){
                try {
                    (New-Object System.Net.Sockets.TcpClient).Connect($rdmhost, 3389)
                    Write-Debug "Found RDP, adding entry"
                    if ($readonly){
                        Write-Host "`$session = New-RdmSession -Name $rdmname -group $rdmgroup -host $rdmhost -Type RDPConfigured; Set-RDMSession `$session"
                    } else {
                        $session = New-RDMSession -Name $rdmname -group $rdmgroup -host $rdmhost -Type RDPConfigured; Set-RDMSession $session
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
$adcomputers = Get-ADComputer -Filter * -SearchBase (Get-ADObject -Filter {name -eq $rdmroot}).DistinguishedName -SearchScope 2 -Properties Name,CanonicalName
$adrootCanonicalName = Get-ADObject -Filter {name -eq $rdmroot} -Properties CanonicalName | select -ExpandProperty CanonicalName

Write-Host "Updating RDM Repository"
Update-RDMRepository
Write-Host "Checking for Duplicates"
Remove-RDMDuplicates
Write-Host "Checking for Orphans"
Remove-RDMOrphans
Write-Host "Adding missing objects"
Add-RDMADobjects
