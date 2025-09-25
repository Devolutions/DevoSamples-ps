#source: https://forum.devolutions.net/topics/34454/changing-different-properties-on-sessions

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}


function Set-RDMDefaultSessionColor {
<#
.SYNOPSIS
 Set the color of an entry in RDM
.DESCRIPTION
 This function sets the color of a folder or session to the desired color.
.PARAMETER Color
 Specifies the color - "Black","Blue","Forest","Grey","Orange","Royal","Yellow","Purple","Black","Red","Green"
.PARAMETER Session
Specifies the session
.PARAMETER Vault
Specifies the vault/repository that contains the session
.PARAMETER DataSource
Specifies the Data Source that contains the vault/repo
.EXAMPLE
Set-RDMFolderColor -Color "Green" -Session "ID" -vault "VaultName" -DataSource "DataSourceName"
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
        #refresh the connection to RDM to prevent errors
        Update-RDMUI
    }
    
    process {
        try {
            #set the current data source, if needed
            if ($DataSource -ne ""){
                Set-RDMCurrentDataSource "$Datasource"
                Update-RDMUI
            }
            #set the current repository/vault, if needed
            if ($Vault -ne ""){
                Set-RDMCurrentRepository -Repository  $vault
                Update-RDMUI
            }
            #retreive the session, using the ID
            $RDMsession = Get-RDMSession | Where-Object {$_.id -eq $Session}
            #set the color
            $RDMSession.ImageName = "["+$Color+"]"
            #save the session back in the Data Source
            Set-RDMSession -Session $RDMsession
        }
        catch {
            Write-Output $Error[0]
        }
    }
    
    end {
        #refresh the connection to RDM to prevent errors
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
            #refresh the connection to RDM to prevent errors
            Update-RDMUI
        }
        
        process {
            try {
                #set the current data source, if needed
                if ($DataSource -ne ""){
                    Set-RDMCurrentDataSource "$Datasource"
                    Update-RDMUI
                }
                #set the current repository/vault, if needed
                if ($Vault -ne ""){
                    Set-RDMCurrentRepository -Repository  $vault
                    Update-RDMUI
                }
                #retreive the session, using the ID
                $RDMsession = Get-RDMSession | Where-Object {$_.id -eq $Session}
                #set the image - Sample is required first
                $RDMSession.ImageName = "Sample$Image"
                #save the session back in the Data Source
                Set-RDMSession -Session $RDMsession
            }
            catch {
                Write-Output $Error[0]
            }
        }
        
        end {
            #refresh the connection to RDM to prevent errors
            Update-RDMUI
        }
    }