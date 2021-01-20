<#
    Helper function which builds the audio argument array for ffmpeg

    .PARAMETER InputFile
        The source file. This is used to determine the number of audio channels for lossy encoding
    .PARAMETER UserChoice
        Options are copy (passthrough), aac, and none
    .PARAMETER AacBitrate
        The constant bitrate to be used with ffmpeg's native AAC encoder. Value is the bitrate per audio channel
    .NOTES
        ffmpeg cannot decode Dolby Atmos streams, nor can they be identified using ffprobe. If you try and
        copy a Dolby Atmos track, the script will fail. 
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
        [int]$Bitrate
    )

    #Private inner function that returns the number of channels for the primary audio stream
    function Get-ChannelCount {
        [int]$numOfChannels = ffprobe -i $InputFile -show_entries stream=channels `
            -select_streams a:0 -of compact=p=0:nk=1 -v 0
        return $numOfChannels
    }
    #Private inner function that prints audio data when the -Bitrate parameter is used
    function Write-BitrateInfo ($channels, $bitsPerChannel) {
        Write-Host "Audio stream 0 has $channels channels. " -NoNewline
        Write-Host "If the input layout is 7.1, it will be downmixed to 5.1. " @warnColors -NoNewline
        Write-Host "Total bitrate per channel: ~ $bitsPerChannel`n"
    }

    if ($UserChoice -match "^c[opy]*$") { 
        Write-Host "** COPY AUDIO SELECTED **" @progressColors
        Write-Host "Audio stream 0 will be copied. " -NoNewline
        Write-Host "If you are attempting to copy a Dolby Atmos stream, FFENCODER WILL FAIL`n" @warnColors
        return @('-c:a', 'copy')
    }
    elseif ($UserChoice -match "c[opy]*a[ll]*") {
        Write-Host "** COPY ALL AUDIO SELECTED **" @progressColors
        Write-Host "All audio streams will be copied. " -NoNewline
        Write-Host "If you are attempting to copy a Dolby Atmos stream, FFENCODER WILL FAIL`n" @warnColors
        return @('-map', '0:a', '-c:a', 'copy')
    }
    elseif ($UserChoice -eq "aac") {
        if (!$Bitrate) { $Bitrate = 512 }
        $channels = Get-ChannelCount
        $bitsPerChannel = "$($Bitrate / $channels) kb/s"
        Write-Host "** AAC AUDIO SELECTED **" @progressColors
        Write-Host "Audio stream 0 has $channels channels. Total bitrate per channel: ~ $bitsPerChannel`n" 
        return @('-map', '0:a:0', '-c:a', 'aac', '-b:a', "$Bitrate`k")
    }
    elseif (@('ac3', 'dd') -contains $UserChoice) {
        Write-Host "** DOLBY DIGITAL (AC3) AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', '-c:a:0', 'ac3', '-b:a', "$Bitrate`k")
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", '-c:a', 'copy')
            }
            else { return @('-map', '0:a:0', '-c:a', 'ac3', '-b:a', '640k') }
        }
    }
    elseif ($UserChoice -eq "dts") {
        Write-Host "** DTS AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', '-c:a:0', 'dca', '-b:a', "$Bitrate`k", '-strict', -2)
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", '-c:a', 'copy')
            }
            else { return @('-map', '0:a:0', '-c:a', 'dca') }
        }
    }
    elseif ($UserChoice -eq "eac3") {
        Write-Host "** DOLBY DIGITAL PLUS (E-AC3) AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', '-c:a:0', 'eac3', '-b:a', "$Bitrate`k")
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", '-c:a', 'copy')
            }
            else { return @('-map', '0:a:0', '-c:a', 'eac3') }
        }
    }
    elseif ($UserChoice -match "^f[lac]*") {
        Write-Host "** FLAC AUDIO SELECTED **" @progressColors
        Write-Host "Audio Stream 0 will be transcoded to FLAC`n"
        return @('-map', '0:a:0', '-c:a', 'flac')
    }
    elseif ($UserChoice -match "^n[one]?") { 
        Write-Host "** NO AUDIO SELECTED **" @progressColors
        Write-Host "All audio streams will be excluded from the output file`n"
        return '-an' 
    }
    else { Write-Warning "No matching audio preference was found. Audio will not be copied`n"; return '-an' }
}