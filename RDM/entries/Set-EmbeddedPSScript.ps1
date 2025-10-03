<#
.SYNOPSIS
  Compresses and assigns an embedded PowerShell script to an RDM session or retrieves it for review.

.DESCRIPTION
  This script demonstrates how to manipulate the `EmbeddedScriptCompressed` property on PowerShell sessions in Remote Desktop Manager (RDM).
  It includes helper functions to compress or decompress script content using `DeflateStream`, then shows how to:
  - Convert a plain text script into the compressed byte array expected by RDM and save it to a session.
  - Fetch the same property from an existing session and expand it back into readable text.

  Update the placeholders (session name, inline script contents, etc.) so the operations target the correct entries in your vault.

.NOTES
  - Requires the Devolutions.PowerShell module; import it beforehand if your environment does not load it automatically.
  - Functions emit byte arrays to the pipeline, allowing reuse in other scripts or tooling.
  - Original forum reference: https://forum.devolutions.net/topics/31591/setting-the-embedded-script-in-a-powershell-session

.EXAMPLE
  PS> Import-Module Devolutions.PowerShell
  PS> .\Set-EmbeddedPSScript.ps1
  Compresses the provided inline script, stores it in the specified session, and prints the stored content back to the console.

.LINK
  https://powershell.devolutions.net/
#>

function Get-CompressedByteArray {
    <#
    .SYNOPSIS
      Compresses the provided byte array with Deflate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [byte[]]$ByteArray
    )

    process {
        $output = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.DeflateStream($output, [IO.Compression.CompressionMode]::Compress)
        try {
            $gzipStream.Write($ByteArray, 0, $ByteArray.Length)
        }
        finally {
            $gzipStream.Dispose()
        }
        try {
            $output.ToArray()
        }
        finally {
            $output.Dispose()
        }
    }
}

function Get-DecompressedByteArray {
    <#
    .SYNOPSIS
      Decompresses a Deflate-compressed byte array back into plain bytes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [byte[]]$ByteArray
    )

    process {
        $input = New-Object System.IO.MemoryStream(,$ByteArray)
        $output = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.DeflateStream($input, [IO.Compression.CompressionMode]::Decompress)
        try {
            $gzipStream.CopyTo($output)
        }
        finally {
            $gzipStream.Dispose()
            $input.Dispose()
        }
        try {
            $output.ToArray()
        }
        finally {
            $output.Dispose()
        }
    }
}

# --- Assign a compressed embedded script to a session -----------------------------------------

# Replace with the content you want to embed. Using a here-string keeps multi-line scripts readable.
$inlineScript = @'
Write-Host "Hello from the embedded script!"
'@

# Convert the script text into bytes and compress it so it matches the format expected by RDM.
$encoding = [System.Text.Encoding]::UTF8
$bytes = $encoding.GetBytes($inlineScript)
$compressedBytes = Get-CompressedByteArray -ByteArray $bytes

# Target the session that should host the embedded script. Adjust the name to suit your environment.
$targetSessionName = '<session name to update>'
$session = Get-RDMSession -Name $targetSessionName
$session.PowerShell.EmbeddedScriptCompressed = $compressedBytes
Set-RDMSession $session -Refresh

# --- Retrieve and display an embedded script ---------------------------------------------------

# Fetch the session from which you want to read the embedded script content; reuse the same name if desired.
$sourceSessionName = '<session name to read>'
$sessionToRead = Get-RDMSession -Name $sourceSessionName
$decompressedBytes = Get-DecompressedByteArray -ByteArray $sessionToRead.PowerShell.EmbeddedScriptCompressed

# Translate the decompressed bytes back into text and output it so you can validate the stored script.
Write-Host ($encoding.GetString($decompressedBytes) | Out-String)
