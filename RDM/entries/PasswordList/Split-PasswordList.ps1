<#
.SYNOPSIS
  Splits Password List entries in single credential entries.
.DESCRIPTION
  Splits Password List entries in single credential entries contained in a folder.
  The script will run across all vaults in the data source.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Erica Poirier
  Creation Date:  2021-05-14
  Purpose/Change: Initial script development
.EXAMPLE
  
#>

#-------------------------------[Script Parameters]----------------------------

Param (
  #Script parameters go here
)

#-------------------------------[Initialisations]------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
  Install-Module Devolutions.PowerShell -Scope CurrentUser
}

#--------------------------------[Declarations]--------------------------------

# Adapt the data source name in the following statement
$dsName = "YourDataSourceNameHere"

#---------------------------------[Functions]----------------------------------


Function Split-PWList {
  Param ()
  Begin {
    Write-Host 'Splitting Password List entries...'
  }
  Process {
    Try {
        # Select the current data source
        $ds = Get-RDMDataSource $dsName
        Set-RDMCurrentDataSource $ds
        Update-RDMUI
        
        $vaults = Get-RDMRepository

        foreach ($vault in $vaults) {
            Set-RDMCurrentRepository $vault
            Update-RDMUI

            # Fetch all Password List entries
            $PWDLists = Get-RDMSession | where {$_.Credentials.CredentialType -eq "PasswordList"}
            
            foreach ($PWDList in $PWDLists) {
                # Create the folder in which the credential entries will be created
                $FolderName = $PWDList.Name
                if ([string]::IsNullOrWhiteSpace($PWDList.Group)) {
                    $Folder = $FolderName
                }
                else {
                    $Folder = Join-Path $PWDList.Group $FolderName
                }
                $session = New-RDMSession -Name $FolderName -Group $Folder -Type Group
                Set-RDMSession $session -Refresh

                # Create the single credential entries
                foreach ($item in $PWDList.Credentials.PasswordList) {
                    $credential = New-RDMSession -Name $item.User -Group $Folder -Type Credential
                    $credential.Description = $item.Description
                    $credential.Credentials.Domain = $item.Domain
                    Set-RDMSession -Session $credential -Refresh
                    if (!([string]::IsNullOrWhiteSpace($item.User))) {
                        Set-RDMSessionUsername -Session $credential -UserName $item.User
                    }
                    if (!([string]::IsNullOrWhiteSpace($item.Password))) {
                        Set-RDMSessionPassword -Session $credential -Password (ConvertTo-SecureString -AsPlainText -Force $item.Password)
                    }
                    Set-RDMSession -Session $credential -Refresh
                }
            }
        }
    }
    Catch {
      Write-Host -BackgroundColor Red "Error: $($_.Exception)"
      Break
    }
  }
  End {
    If ($?) {
      Write-Host 'Completed Successfully.'
      Write-Host ' '
    }
  }
}


#---------------------------------[Execution]----------------------------------

Split-PWList

#----------------------------------[Closure]-----------------------------------
# If running in the console only, ask to press a key
if ($Host.Name -eq "ConsoleHost")
{
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.FlushInputBuffer()  
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
}
