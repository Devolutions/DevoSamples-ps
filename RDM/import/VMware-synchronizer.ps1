#source: https://forum.devolutions.net/topics/35520/improved-vmware-synchronizer-with-powershell
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

Write-Host 'Loading PowerCLI...'
Import-Module VMware.PowerCLI
$id = @{ID = 'your-guid-here-please'} #ID for vSphere local admin credential object
Write-Host 'Connecting to vSphere...'
$vsphere = 'your.vsphere.server.com'
$srv = Connect-VIServer -Server $vsphere -Credential (New-Object System.Management.Automation.PSCredential((Get-RDMSessionUserName @id), (Get-RDMSessionPassword @id)))
Get-VM | % {
    # calculate expected group path based on VM folder
    $g = $(
        $folder = $_.Folder
        $path = $null
        while ($folder -ne $null) {
            # root folder is 'vm', ignore it
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
        # you can change what toplevel group to put the VMs in below
        'VMware\{0}' -f $path
    )
    # calculate expected session type based on VM guest type ID
    if ($_.GuestId -match '^win(dows|XP|Net|Longhorn)') {
        $ct = 'RDPConfigured'
        $h = $_.Name
    } else {
        $ct = 'VMRC'
        $h = $vsphere
    }
    # find existing session
    # XXX: Get-RMDSession uses ValidateSet to check if the session is present in the group.
    #      this causes a non-suppressable error message and does not assign to $s.
    #      because of this, we have to set $s to null and even if it is working OK we will get spammed with ParameterArgumentValidationErrors.
    $s = $null
    $s = Get-RDMSession -Name $_.Name -GroupName $g -CaseSensitive -ErrorAction SilentlyContinue
    if ($s) {
        if ($s.ConnectionType.ToString() -ne $ct) {
            # delete session of wrong type
            Remove-RDMSession -ID $s.ID
            $s = $null
        }
    }
    # create new session if it does not exist
    if (-not $s) {
        # create folders that do not exist
        # XXX: probably breaks on any vm folders with backslashes in the name, if that's possible
        $split = $g.Split('\')
        $cur = New-Object System.Collections.ArrayList
        while ($cur.Count -lt $split.Count) {
            $cur.Add($split[$cur.Count]) | Out-Null
            $curstr = $cur -join '\'
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
    # things to update regardless of if the session was just created or if it already existed
    $s.Description = $_.Notes
    if ($ct -eq 'VMRC') {
        $s.VMRC.VMid = $_.Id.Remove(0, 15)
    }
    Set-RDMSession -Session $s
    # push it down the pipe to the GridView
    $s
} | Out-GridView
Update-RDMUI
Disconnect-VIServer $srv -Force -Confirm:$false
Pause