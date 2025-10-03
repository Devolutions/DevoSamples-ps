<#
.SYNOPSIS
    Export documents and file attachments stored in Remote Desktop Manager vaults.
.DESCRIPTION
    Ensures the Devolutions.PowerShell module is available, connects to the specified data source, and
    exports both document entries stored directly in the database and attachments associated with standard
    sessions. Each vault gets its own CSV manifest alongside the extracted files in the target directory.
.NOTES
    Update the data source names and destination path before running. The script writes one file per
    document or attachment into the supplied folder and logs the exported items in CSV files.
#>

# Ensure the Devolutions PowerShell module is available for the current user before running any RDM cmdlets.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (replace with the appropriate data source name prior to execution).
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

    # Retrieve all accessible vaults so we can export documents from each one.
    $vaults = Get-RDMVault

    foreach ($vault in $vaults)
    {
        Set-RDMCurrentRepository $vault
        Update-RDMUI
        $vaultName = $vault.Name
        $newCSVfile = $true

        # Query every document stored in the database for this vault.
        $sessions = Get-RDMSessionDocumentStoredInDatabase

        foreach ($session in $sessions)
        {
            $fileName = $session.Connection.Document.Filename
            $destination = Join-Path $path "\$fileName"
            $fileInBytes = $session.data

            # Use the entry's name if the filename is not available.
            if ([string]::IsNullOrWhiteSpace($fileName))
            {
                $name = $session.Connection.Name
                $type = $session.Connection.ConnectionTypeName
                $filename = "$name $type.txt"
                $destination = Join-Path $path "\$fileName"
            }

            if ($fileInBytes)
            {
                # Persist the binary document content to disk.
                [io.file]::WriteAllBytes($destination, $fileInBytes)
            }
            else
            {
                $filename = $fileName + " **empty file in the database** "
            }

            if ($newCSVfile)
            {
                # Create a manifest CSV for the current vault to list every exported document.
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

    # Retrieve all accessible vaults so we can export attachments from each one.
    $vaults = Get-RDMVault

    foreach ($vault in $vaults)
    {
        Set-RDMCurrentRepository $vault
        Update-RDMUI
        $vaultName = $vault.Name
        $newCSVfile = $true

        try
        {
            # Fetch every session to enumerate their database-stored attachments.
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
                            # Persist the attachment content to disk.
                            [io.file]::WriteAllBytes($destination, $fileInBytes)
                        }
                        else
                        {
                            $filename = $fileName + " **empty file in the database** "
                        }

                        if ($newCSVfile)
                        {
                            # Create a manifest CSV for the current vault to list every exported attachment.
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
            # Continue processing additional vaults if attachment retrieval fails for this one.
        }
    }

    Write-Host "ExportAttachments function completed!"
}

# Adapt the data source name MyDataSource to the one configured in the RDM user's profile which will run the script.
$ds = Get-RDMDataSource -Name QADVLS_admin
Set-RDMCurrentDataSource $ds
Update-RDMUI

# Adapt the folder destination path for the documents and the attachments.
Export-DBDocuments "C:\Temp\Temp"
Export-DBAttachment "C:\Temp\Temp"
