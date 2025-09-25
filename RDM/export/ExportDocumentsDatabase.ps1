#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

function Export-DBDocuments
{
    param
    (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$path
    )

    Write-Host "Starting ExportDocuments function, please wait this may take a few moments!"

    $vaults = Get-RDMVault

    foreach ($vault in $vaults)
    {
        Set-RDMCurrentRepository $vault
        Update-RDMUI
        $vaultName = $vault.Name
        $newCSVfile = $true

        $sessions = Get-RDMSessionDocumentStoredInDatabase

        foreach ($session in $sessions)
        {
            $fileName = $session.Connection.Document.Filename
            $destination = Join-Path $path "\$fileName"
            $fileInBytes = $session.data

            # Use the entry's name if the filename is not available
            if ([string]::IsNullOrWhiteSpace($fileName))
            {
                $name = $session.Connection.Name
                $type = $session.Connection.ConnectionTypeName
                $filename = "$name $type.txt"
                $destination = Join-Path $path "\$fileName"
            }

            if ($fileInBytes)
            {
                [io.file]::WriteAllBytes($destination, $fileInBytes)
            }
            else
            {
                $filename = $fileName + " **empty file in the database** "
            }

            if ($newCSVfile)
            {
                $line = "Name,Group,ConnectionType,Description"
                $CSVfilename = "\" + $vaultName + "_Documents.csv"
                $CSVFileList = Join-Path $path $CSVfilename
                Out-File -FilePath $CSVFileList -InputObject $line
                $newCSVfile = $false
				Write-Host "Documents found in $vaultName vault!"
            }

            $entryName = $session.Connection.Name
            $entryFolder = $session.Connection.Group
            $connectionType = "Document"
            $line = "$entryName,$entryFolder,$connectionType,$fileName"
            Out-File -FilePath $CSVFileList -InputObject $line -Append
        }
    }

    Write-Host "ExportDocuments function completed!"
}

function Export-DBAttachment
{
    param
    (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$path
    )

    Write-Host "Starting ExportAttachments function, please wait this will be longer!"

    $vaults = Get-RDMVault

    foreach ($vault in $vaults)
    {
        Set-RDMCurrentRepository $vault
        Update-RDMUI
        $vaultName = $vault.Name
        $newCSVfile = $true

        try
        {
            $sessions = Get-RDMSession -ErrorAction SilentlyContinue

            foreach ($session in $sessions)
            {
                $attachments = Get-RDMSessionAttachment -Session $session
                foreach ($attch in $attachments)
                {
                    if (![string]::IsNullOrEmpty($attch))
                    {
                        $fileName = $attch.Filename
                        $destination = Join-Path $path "\$fileName"
                        $fileInBytes = $attch.data

                        if ($fileInBytes)
                        {
                            [io.file]::WriteAllBytes($destination, $fileInBytes)
                        }
                        else
                        {
                            $filename = $fileName + " **empty file in the database** "
                        }

                        if ($newCSVfile)
                        {
                            $line = "Name,Group,ConnectionType,Description"
                            $CSVfilename = "\" + $vaultName + "_Attachments.csv"
                            $CSVFileList = Join-Path $path $CSVfilename
                            Out-File -FilePath $CSVFileList -InputObject $line
                            $newCSVfile = $false
						    Write-Host "Attachments found in $vaultName vault!"
                        }

                        $entryName = $session.Name
                        $entryFolder = $session.Group
                        $connectionType = "Attachment"
                        $line = "$entryName,$entryFolder,$connectionType,$fileName"
                        Out-File -FilePath $CSVFileList -InputObject $line -Append
                    }
                }
            }
        }
        catch
        {
        }
    }

    Write-Host "ExportAttachments function completed!"
}

# Adapt the data source name MyDataSource to the one configured in the RDM user's profile which will run the script
$ds = Get-RDMDataSource -Name QADVLS_admin
Set-RDMCurrentDataSource $ds
Update-RDMUI

# Adapt the folder destination path for the documents and the attachments
Export-DBDocuments "C:\Temp\Temp"
Export-DBAttachment "C:\Temp\Temp"