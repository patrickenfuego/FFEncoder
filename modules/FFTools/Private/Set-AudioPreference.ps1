<#
    Helper function which builds the audio argument array for ffmpeg

    .PARAMETER InputFile
        The source file. This is used to determine the number of audio channels for lossy encoding
    .PARAMETER UserChoice
        Options are copy (passthrough), aac, and none
    .PARAMETER AacBitrate
        The constant bitrate to be used with ffmpeg's native AAC encoder. Value is the bitrate per audio channel
#>
function Set-AudioPreference {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$UserChoice,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$AacBitrate
    )

    if ($UserChoice -match "^c[opy]?") { 
        Write-Host "** COPY AUDIO SELECTED **" @progressColors
        Write-Host "Audio stream 0 will be copied. " -NoNewline
        Write-Host "If you are attempting to copy a Dolby Atmos stream, FFENCODER WILL FAIL`n" @warnColors
        return @('-c:a', 'copy') 
    }
    elseif ($UserChoice -match "aac") {
        [int]$numOfChannels = ffprobe -i $InputFile -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0
        $bitrate = "$($numOfChannels * $AacBitrate)k"
        Write-Host "** AAC AUDIO SELECTED **" @progressColors
        Write-Host "Primary audio stream has $numOfChannels channels. Total AAC bitrate: ~ $bitrate`n" 
        return @('-c:a', 'aac', '-b:a', $bitrate)
    }
    elseif ($UserChoice -match "^n[one]?") { 
        Write-Host "** NO AUDIO SELECTED **" @progressColors
        Write-Host "All audio streams will be excluded from the file`n"
        return '-an' 
    }
    else { Write-Warning "No matching audio preference was found. Audio will not be copied`n"; return '-an' }
}