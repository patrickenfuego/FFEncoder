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
    elseif ($UserChoice -like "aac") {
        if (!$Bitrate) { $Bitrate = 512 }
        $channels = Get-ChannelCount
        $bitsPerChannel = "$($Bitrate / $channels) kb/s"
        Write-Host "** AAC AUDIO SELECTED **" @progressColors
        Write-Host "Audio stream 0 has $channels channels. Total bitrate per channel: ~ $bitsPerChannel`n" 
        return @('-map', '0:a:0', '-c:a', 'aac', '-b:a', "$Bitrate`k")
    }
    elseif (@("dd", "ac3", "dts") -contains $UserChoice) {
        Write-Host "** $($UserChoice.ToUpper()) AUDIO SELECTED **" @progressColors
        if ($UserChoice -eq "dd") { $UserChoice = 'ac3' }
        #Get the index of the desired stream. If no stream is found, $i will be $false
        $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
        if ($i) {
            return @('-map', "0:a:$i", '-c:a', 'copy')
        }
        else {
            switch ($UserChoice) {
                "DTS" { return @('-map', '0:a:0', '-c:a:0', 'dca', '-strict', -2) }
                "AC3" { return @('-map', '0:a:0', '-c:a:0', 'ac3', '-b:a', '640k') }
            }
        }
    }
    elseif ($UserChoice -eq "eac3") {
        Write-Host "** E-AC3 AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-Host "Audio stream 0 has $channels channels. 7.1 will be reduced to 5.1. Total bitrate per channel: ~ $bitsPerChannel`n"
            return @('-map', '0:a:0', '-c:a', 'eac3', '-b:a', "$Bitrate`k")
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