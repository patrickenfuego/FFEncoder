<#
    .SYNOPSIS
        Verifies that the primary audio stream is lossless before transcoding.
    .DESCRIPTION
        Small utility function to ensure that the primary audio stream is lossless before transcoding
        to another format. If the stream is not lossless, the function will return $false and it is
        the responsibility of the calling function to handle the error. If no audio streams are found,
        the function will return $null.
    .PARAMETER InputPath
        Path to input media file.
#>
function Confirm-Audio {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Path to input video file')]
        [ValidateScript(
            { Test-Path $_ },
            ErrorMessage = "The file '{0}' does not exist"
        )]
        [Alias('FilePath', 'Path')]
        [string]$InputPath
    )

    [scriptblock]$validator = {
        param ($Audio)

        [bool]$isLossless = switch -Wildcard ($Audio) {
            '*DTS XLL*' { $true; break }
            '*MLP FBA*' { $true; break }
            '*FLAC*'    { $true; break }
            '*PCM*'     { $true; break }
            default     { $false }
        }

        return $isLossless
    }

    $audioStreams = (Get-MediaInfo $InputPath).AudioCodec.Split('/').Trim()
    # If audio was found, validate that it contains a lossless stream
    if ($audioStreams) {
        [bool[]]$losslessStreams = $audioStreams.ForEach({ & $validator -Audio $_ })
    }
    else {
        Write-Verbose "Confirm-Audio: No audio streams to validate in '$InputPath'"
        
        return $null
    }

    if ($losslessStreams[0]) {
        return $true
    }
    # Lossless was found, but not at the expected first position. Notify user and return $false
    elseif ($losslessStreams -contains $true) {
        $index = [Array]::IndexOf($losslessStreams, $true)
        $msg = "Confirm-Audio: $ul$InputPath$ulOff contains a lossless stream at position $index " +
               'but not in the expected first position. Moving the lossless stream to the first ' +
               "position is $boldOn`highly recommended$boldOff before proceeding."  
        Write-Host $msg @warnColors

        return $false
    }
    else {
        return $false
    }
}
