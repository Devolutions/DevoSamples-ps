##########
#
# Object : Set permissions on folders in given vaults
#
# Parameters   :
# $dsName      : Name of the RDM data source.
# $fileName    : Name and full path of the CSV file.
# $logFileName : Name and full path of the log file. To be used with the -Verbose switch for maximum log information.
#
# CSV file headers
# Vault             : Name of the Vault
# Folder            : Folder full path (no leading or trailing "\")
# RoleOverride      : Default, Everyone, Never or Custom
# ViewRoles         : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Add               : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Edit              : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Delete            : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# ViewPassword      : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Execute           : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# EditSecurity      : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# ConnectionHistory : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# PasswordHistory   : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Remotetools       : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Inventory         : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Attachment        : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# EditAttachment    : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# Handbook          : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# EditHandbook      : Default, Everyone, Never or list of Roles and/or Users separated with ";". User accounts need to end with "|u" to be added in the permissions (ex:"bob@windjammer.loc|u")
# 

param (
    [Parameter(Mandatory=$True,Position=1)]
    [string]$dsName,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$fileName,
    [Parameter(Mandatory=$false,Position=3)]
    [string]$logFileName
    )

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

if (-not [string]::IsNullOrEmpty($logFileName))
{
    Start-Transcript -Path $logFileName -Force
}

# Set the data source
$ds = Get-RDMDataSource -Name $dsName
Set-RDMCurrentDataSource $ds

$CSVpermissions = Import-Csv $fileName

$vaultName = ""

foreach ($CSVPerm in $CSVpermissions)
{
    # Select the vault
    if ($CSVPerm.Vault -ne $vaultName -or [string]::IsNullOrEmpty($vaultName))
    {
        $vault = Get-RDMRepository -Name $CSVPerm.Vault
        Set-RDMCurrentRepository $vault
        Update-RDMUI
        $vaultName = $vault.Name
        Write-Verbose "Vault $vaultName selected..."
    }

    # Select the folder. If doesn't exist, create the folder.
    $folder = $CSVPerm.Folder
    $levels = $folder.split('\')
    $nbLevels = $levels.Count
    $folderName = $levels[$nbLevels - 1]
    try
    {
        $session = Get-RDMSession -Name $folderName -ErrorAction Stop | where {$_.ConnectionType -eq "Group" -and $_.Group -eq $folder}
        if ([string]::IsNullOrEmpty($session))
        {
            Write-Verbose "Creating folder $folder..."
            $session = New-RDMSession -Name $folderName -Group $folder -Type Group -SetSession
            Update-RDMUI
        }
    }
    catch
    {
        Write-Verbose "Creating folder $folder..."
        $session = New-RDMSession -Name $folderName -Group $folder -Type Group -SetSession
        Update-RDMUI
    }

    # Set Permission
    $session.Security.RoleOverride = $CSVPerm.RoleOverride

    if ($CSVPerm.RoleOverride -eq "Custom")
    {
        # Set View Permission
        if ($CSVPerm.ViewRoles -in "Everyone", "Default", "Never")
        {
            $session.Security.ViewOverride = $CSVPerm.ViewRoles
        }
        else
        {
            $session.Security.ViewOverride = "Custom"
            [string]$viewPermission = $CSVPerm.ViewRoles
            $viewPerm = $viewPermission.Split(';')
            $session.Security.ViewRoles = $viewPerm
        }

        # Set all other permissions
        $otherPermissions = @()
        foreach($object_properties in $CSVPerm.PsObject.Properties)
        {
            if ($object_properties.Name -notin "Vault", "Folder", "RoleOverride", "ViewRoles" -and $object_properties.Value -ne "Default")
            {
                $permission = New-Object Devolutions.RemoteDesktopManager.Business.ConnectionPermission
                $permission.Right = $object_properties.Name
                if ($object_properties.Value -in "Everyone", "Default", "Never")
                {
                    $permission.Override = $object_properties.Value
                }
                else
                {
                    $permission.Override = "Custom"
                    [string]$tempPerm = $object_properties.Value
                    $permStr = $tempPerm -replace [Regex]::Escape(";"), ", "
                    $perm = $tempPerm.Split(';')
                    $permission.Roles = $perm
                    $permission.RoleValues = $permStr
                }
                $otherPermissions += $permission
            }
        }

        $session.Security.Permissions = $otherPermissions
    }

    # Save the modifications
    Set-RDMSession $session -Refresh
    Write-Verbose "Permissions updated on folder $folder..."
}

Update-RDMUI
Write-Host "Done!!!"

if (-not [string]::IsNullOrEmpty($logFileName))
{
    Stop-Transcript
}
