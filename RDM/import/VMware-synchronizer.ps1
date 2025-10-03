#source: https://forum.devolutions.net/topics/35520/improved-vmware-synchronizer-with-powershell
###########################################################################
#
# Synchronize VMware virtual machines into Remote Desktop Manager entries.
#
###########################################################################

<#
.SYNOPSIS
    Mirror VMware virtual machines into Remote Desktop Manager sessions.
.DESCRIPTION
    Ensures the Devolutions.PowerShell and VMware PowerCLI modules are available, connects to the specified
    RDM data source, and authenticates against vSphere using an existing credential entry. For each VM, the
    script derives the group path from the vSphere folder structure, creates any missing folders in RDM, and
    creates or updates the RDM session with properties appropriate for Windows (RDP) or non-Windows (VMRC)
    guests. Existing sessions with mismatched types are recreated so settings stay consistent.
.NOTES
    Replace the placeholders for the data source name, vSphere host, and credential ID before running. The
    script installs modules for the current user if they are missing and prompts an Out-GridView summary when
    finished.
#>

# Ensure the Devolutions PowerShell module is installed for the current user.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (update with your environment name).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

Write-Host 'Loading PowerCLI...'
Import-Module VMware.PowerCLI

# Retrieve the credential stored in RDM that will authenticate to vSphere (replace ID value first).
$id = @{ID = 'your-guid-here-please'}

Write-Host 'Connecting to vSphere...'
$vsphere = 'your.vsphere.server.com'
$srv = Connect-VIServer -Server $vsphere -Credential (New-Object System.Management.Automation.PSCredential((Get-RDMSessionUserName @id), (Get-RDMSessionPassword @id)))

Get-VM | % {
    # Build the RDM group path from the VM's folder hierarchy (ignoring the root 'vm' container).
    $g = $(
        $folder = $_.Folder
        $path = $null
        while ($folder -ne $null) {
            if ($folder.Name -cne 'vm') {
                if ($path -eq $null) {
                    $path = $folder.Name
                } else {
                    $path = '{0}\{1}' -f $folder.Name, $path
                }
            }
            if ($folder.ParentFolder -ne $null) {
                $folder = $folder.ParentFolder
            } else {
                $folder = $folder.Parent
            }
        }
        'VMware\{0}' -f $path
    )

    # Select session type based on guest OS; Windows hosts use RDP otherwise fall back to VMRC.
    if ($_.GuestId -match '^win(dows|XP|Net|Longhorn)') {
        $ct = 'RDPConfigured'
        $h = $_.Name
    } else {
        $ct = 'VMRC'
        $h = $vsphere
    }

    # Locate any existing session; remove it if the connection type no longer matches.
    $s = $null
    $s = Get-RDMSession -Name $_.Name -GroupName $g -CaseSensitive -ErrorAction SilentlyContinue
    if ($s) {
        if ($s.ConnectionType.ToString() -ne $ct) {
            Remove-RDMSession -ID $s.ID
            $s = $null
        }
    }

    # Create missing folders and the new session when it does not already exist.
    if (-not $s) {
        $split = $g.Split('\\')
        $cur = New-Object System.Collections.ArrayList
        while ($cur.Count -lt $split.Count) {
            $cur.Add($split[$cur.Count]) | Out-Null
            $curstr = $cur -join '\\'
            if (-not (Get-RDMSession -Name $cur[-1] -GroupName $curstr -ErrorAction SilentlyContinue)) {
                Set-RDMSessionCredentials -CredentialsType Inherited -PSConnection (New-RDMSession -Name $cur[-1] -Group $curstr -Type Group) -SetSession
            }
        }

        $s = New-RDMSession -Name $_.Name -Host $h -Group $g -Type $ct
        Set-RDMSessionCredentials -PSConnection $s -CredentialsType Inherited
        $s.OpenEmbedded = $true
        $s.AuthentificationLevel = 'ConnectDontWarnMe'
        if ($ct -eq 'VMRC') {
            $s.VMRC.VMWareConsole = 'VMWareVMRC8'
        }
    }

    # Update shared properties for both new and existing sessions.
    $s.Description = $_.Notes
    if ($ct -eq 'VMRC') {
        $s.VMRC.VMid = $_.Id.Remove(0, 15)
    }
    Set-RDMSession -Session $s

    # Output each session for Operator review in the grid view UI.
    $s
} | Out-GridView

Update-RDMUI
Disconnect-VIServer $srv -Force -Confirm:$false
Pause
