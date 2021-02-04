<#
    .SYNOPSIS
        Helper function which builds the audio argument arrays for ffmpeg based on user input
    .PARAMETER InputFile
        The source (input) file. This is used to determine the number of audio channels for lossy encoding
    .PARAMETER UserChoice
        Audio option selected before running the script. See documentation for all available options
    .PARAMETER Bitrate
        Bitrate for the selected audio stream in kb/s. Values 1-5 are reserved for libfdk's variable bitrate 
        (vbr) encoder
    .PARAMETER Stream
        References the different output streams if a second audio option is passed to the script
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
        [int]$Bitrate,

        [Parameter(Mandatory = $false, Position = 3)]
        [int]$Stream
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
        if (@("eac3", "dts", "ac3", "dd") -contains $UserChoice) {
            Write-Host "7.1 channel layout will be downmixed to 5.1" @warnColors
        }
        Write-Host "Total bitrate per channel: ~ $bitsPerChannel`n"
    }

    $atmosWarning = "If you are attempting to copy a Dolby Atmos stream,`n you must have the latest ffmpeg build or the SCRIPT WILL FAIL`n"

    if ($UserChoice -match "^c[opy]*$") { 
        Write-Host "** COPY AUDIO SELECTED **" @progressColors
        Write-Host "Audio stream 0 will be copied. " -NoNewline
        Write-Host $atmosWarning @warnColors
        return @('-map', '0:a:0', '-c:a:0', 'copy')
    }
    elseif ($UserChoice -match "c[opy]*a[ll]*") {
        Write-Host "** COPY ALL AUDIO SELECTED **" @progressColors
        Write-Host "All audio streams will be copied. " -NoNewline
        Write-Host $atmosWarning @warnColors
        return @('-map', '0:a', '-c:a', 'copy')
    }
    elseif ($UserChoice -eq "aac") {
        if (!$Bitrate) { $Bitrate = 512 }
        $channels = Get-ChannelCount
        $bitsPerChannel = "$(($Bitrate / $channels),2) kb/s"
        Write-Host "** AAC AUDIO SELECTED **" @progressColors
        Write-BitrateInfo $channels $bitsPerChannel
        return @('-map', '0:a:0', "-c:a:$Stream", 'aac', "-b:a:$Stream", "$Bitrate`k")
    }
    elseif (@("fdkaac", "faac") -contains $UserChoice) {
        Write-Host "** FRAUNHOFER AAC AUDIO SELECTED **" @progressColors
        if (!$Bitrate) {
            Write-Host "No bitrate specified. Using variable bitrate (VBR) quality 4`n" @warnColors
            return @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', 4) 
        }
        if (1..5 -contains $Bitrate) {
            Write-Host "Variable bitrate (VBR) selected. Quality value: $Bitrate"`n
            return @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', $Bitrate)
        }
        else {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / $channels) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-b:a', "$Bitrate`k")
        }
    }
    elseif (@('ac3', 'dd') -contains $UserChoice) {
        Write-Host "** DOLBY DIGITAL (AC3) AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', "-c:a:$Stream", 'ac3', '-b:a', "$Bitrate`k")
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { return @('-map', '0:a:0', "-c:a:$Stream", 'ac3', "-b:a:$Stream", '640k') }
        }
    }
    elseif ($UserChoice -eq "dts") {
        Write-Host "** DTS AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', "-c:a:$Stream", 'dca', "-b:a:$Stream", "$Bitrate`k", '-strict', -2)
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { return @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-strict', -2) }
        }
    }
    elseif ($UserChoice -eq "eac3") {
        Write-Host "** DOLBY DIGITAL PLUS (E-AC3) AUDIO SELECTED **" @progressColors
        if ($Bitrate) {
            $channels = Get-ChannelCount
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
            Write-BitrateInfo $channels $bitsPerChannel
            return @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', "$Bitrate`k")
        }
        else {
            $i = Get-AudioStream -Codec $UserChoice -InputFile $InputFile
            if ($i) {
                return @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { return @('-map', '0:a:0', "-c:a:$Stream", 'eac3') }
        }
    }
    elseif ($UserChoice -match "^f[lac]*") {
        Write-Host "** FLAC AUDIO SELECTED **" @progressColors
        Write-Host "Audio Stream 0 will be transcoded to FLAC`n"
        return @('-map', '0:a:0', "-c:a:$Stream", 'flac')
    }
    elseif (1..5 -contains $UserChoice) {
        return @('-map', "0:a:$UserChoice", '-c:a', 'copy')
    }
    elseif ($UserChoice -match "^n[one]?") { 
        Write-Host "** NO AUDIO SELECTED **" @progressColors
        Write-Host "All audio streams will be excluded from the output file`n"
        return '-an' 
    }
    else { Write-Warning "No matching audio preference was found. Audio will not be copied`n"; return '-an' }
}