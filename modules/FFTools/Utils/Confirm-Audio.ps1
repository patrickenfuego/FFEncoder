<#
    .SYNOPSIS
        Verifies if the primary audio stream is lossless.
    .DESCRIPTION
        Small utility function to ensure that the primary audio stream is lossless before transcoding
        to another format.
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
    elseif ($losslessStreams -contains $true) {
        $msg = "Confirm-Audio: $ul$InputPath$ulOff contains a lossless stream but " +
               'not in the expected first position. Moving the lossless stream to the ' +
               "first position is $boldOn`highly recommended$boldOff before proceeding."  
        Write-Host $msg @warnColors

        return $false
    }
    else {
        return $false
    }
}
