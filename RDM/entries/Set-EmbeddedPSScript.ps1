# source: https://forum.devolutions.net/topics/31591/setting-the-embedded-script-in-a-powershell-session

function Get-CompressedByteArray 
# This function actually does all the encrytion necessary to populate the Embedded PowerShell Script property.
{ 
    [CmdletBinding()] 
    Param (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][byte[]] $byteArray = $(Throw("-byteArray is required")) 
    ) 
    Process { 
        # Write-Verbose "Get-CompressedByteArray" 
        [System.IO.MemoryStream] $output = New-Object System.IO.MemoryStream 
        $gzipStream = New-Object System.IO.Compression.DeflateStream $output, ([IO.Compression.CompressionMode]::Compress) 
        $gzipStream.Write( $byteArray, 0, $byteArray.Length ) 
        $gzipStream.Close() 
        $output.Close() 
        $tmp = $output.ToArray() 
        # Write-Output $tmp 
    }
}

function Get-DecompressedByteArray 
# This function actually reads the content of an already Embedded PowerShell Script property.
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [byte[]] $byteArray = $(Throw("-byteArray is required"))
    )
    Process 
    {
        # Write-Verbose "Get-DecompressedByteArray"
        $input = New-Object System.IO.MemoryStream( , $byteArray )
        $output = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.DeflateStream $input, ([IO.Compression.CompressionMode]::Decompress)
        $gzipStream.CopyTo( $output )
        $gzipStream.Close()
        $input.Close()
        [byte[]] $byteOutArray = $output.ToArray()
        # Write-Output $byteOutArray
    }
}

#
# The following section use the Get-CompressedByteArray and set it in the Embedded PowerShell script session's property.
#
$InlineScript = '<paste the script you want to input in the embedded script section>'
$bytes = [System.Text.Encoding]::ASCII.GetBytes($InlineScript) 
$CompressedBytes = Get-CompressedByteArray $bytes

# At this point, we get a fully functional compressed string that will be easily set to the EmbeddedScriptCompressed property of a powershell session, such as : 
# if applicable, Import the RDM Powershell Module 
$session = Get-RDMSession -Name "<name of the session you want to set the embedded script into>"
$session.PowerShell.EmbeddedScriptCompressed = $CompressedBytes
Set-RDMSession $session


#
# The following section use the Get-DecompressedByteArray from an Embedded PowerShell script session's property to display it on the screen.
#
$session = Get-RDMSession -Name "<name of the session you want to get the embedded script from>"
$DecompressedBytes = Get-DecompressedByteArray ($s.PowerShell.EmbeddedScriptCompressed)

# Display the text
Write-Host ( $enc.GetString( $decompressedByteArray ) | Out-String )