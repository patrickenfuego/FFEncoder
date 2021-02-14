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
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$UserChoice,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Bitrate,

        [Parameter(Mandatory = $false, Position = 3)]
        [int]$Stream,

        # Parameter help description
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$Stereo,

        # Parameter help description
        [Parameter()]
        [int]$AudioFrames,

        # Parameter help description
        [Parameter()]
        [bool]$RemuxStream,

        # Parameter help description
        [Parameter()]
        [hashtable]$Paths
    )

    #Private inner function that returns the number of channels for the primary audio stream
    function Get-ChannelCount {
        [int]$numOfChannels = ffprobe -i $Paths.InputFile -show_entries stream=channels `
            -select_streams a:0 -of compact=p=0:nk=1 -v 0
        return $numOfChannels
    }
    #Private inner function that prints audio data when the -Bitrate parameter is used
    function Write-BitrateInfo ($channels, $bitsPerChannel) {
        Write-Host "Audio stream 0 has $channels channels. " -NoNewline
        if (@("eac3", "dts", "ac3", "dd") -contains $UserChoice) {
            Write-Host "7.1 channel layout will be downmixed to 5.1" @warnColors
        }
        elseif (1..5 -contains $Bitrate) { Write-Host "`n"; return }
        Write-Host "Bitrate per channel: ~ $bitsPerChannel`n"
    }

    Write-Host "**** Audio Stream $($Stream + 1) ****" @emphasisColors

    $atmosWarning = "If you're copying a Dolby Atmos stream, you must have the latest ffmpeg build or the SCRIPT WILL FAIL"
    #Params for downmixing to stereo. Passed to the Convert-ToStereo function
    $stereoParams = @{
        Paths       = $Paths
        Codec       = $UserChoice
        Bitrate     = $Bitrate
        AudioFrames = $AudioFrames
        RemuxStream = $RemuxStream
    }
    if ($Stereo) {
        #If the RemuxStream flag is set (stream copy + filtering selected)
        if ($RemuxStream) { 
            $temp = Convert-ToStereo @stereoParams 
            return $temp
        }
        else {
            $stereoArray = Convert-ToStereo @stereoParams
            if ($null -ne $stereoArray) { return @('-map', '0:a:0', "-c:a:$Stream") + $stereoArray }
            else { return $null }
        }
    }
    #Set the audio args array based on user selection and return it to the caller function
    $audioArgs = switch -Regex ($UserChoice) {
        "^c[opy]*$" {
            Write-Host "** COPY AUDIO SELECTED **" @progressColors
            Write-Host "Audio stream 0 will be copied. " -NoNewline  
            Write-Host $atmosWarning @warnColors `n
            @('-map', '0:a:0', '-c:a:0', 'copy')
            break
        }
        "c[opy]*a[ll]*" {
            Write-Host "** COPY ALL AUDIO SELECTED **" @progressColors
            Write-Host "All audio streams will be copied. " -NoNewline
            Write-Host $atmosWarning @warnColors `n
            @('-map', '0:a', '-c:a', 'copy')
            break
        }
        "^aac$" {
            Write-Host "** AAC AUDIO SELECTED **" @progressColors
            if (!$Bitrate) { $Bitrate = 512 }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'aac', "-b:a:$Stream", "$Bitrate`k") }
            break
        }
        "^dts$" {
            Write-Host "** DTS AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-strict', -2) }
            break
        }
        "^eac3$" {
            Write-Host "** DOLBY DIGITAL PLUS (E-AC3) AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'eac3') }
            break
        }
        "f[dk]*aac$" {
            Write-Host "** FDK AAC AUDIO SELECTED **" @progressColors
            if (!$Bitrate) { 
                Write-Host "No bitrate specified. Using VBR 3" @warnColors
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', 3)
            }
            elseif (1..5 -contains $Bitrate) { 
                Write-Host "VBR selected. Quality value: $Bitrate"
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', $Bitrate)
            }
            else {
                Write-Host "CBR Selected. Bitrate: $Bitrate`k"
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-b:a', "$Bitrate`k")
            }
            break
        }
        { @('ac3', 'dd') -contains $_ } {
            Write-Host "** DOLBY DIGITAL (AC3) AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'ac3', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'ac3', "-b:a:$Stream", '640k') }
            break
        }
        { 0..5 -contains $_ } { 
            Write-Host "AUDIO STREAM $UserChoice SELECTED" @progressColors
            Write-Host "Stream $UserChoice from input will be mapped to stream $Stream in output"
            @('-map', "0:a:$UserChoice`?", "-c:a:$Stream", 'copy')
            break
        }
        "^f[lac]*" {
            Write-Host "** FLAC AUDIO SELECTED **" @progressColors
            @('-map', '0:a:0', "-c:a:$Stream", 'flac')
            break
        }
        "^n[one]?" {
            Write-Host "** NO AUDIO SELECTED **" @progressColors
            Write-Host "All audio streams will be excluded from the output file`n"
            '-an'
        }
        default { Write-Warning "No matching audio preference was found. Audio will not be copied`n"; return '-an' }
    } 
    #Print relevant info to console based on user choice 
    if (@('copy', 'c', 'copyall', 'ca', 'none', 'n', 'flac', 'f') -contains $UserChoice) {  } #do nothing
    elseif (@('dts', 'ac3', 'dd', 'eac3') -contains $UserChoice) {
        $channels = Get-ChannelCount
        $bitsPerChannel = "$($Bitrate / 6) kb/s"
        Write-BitrateInfo $channels $bitsPerChannel
    }
    else {
        $channels = Get-ChannelCount
        $bitsPerChannel = "$($Bitrate / $channels) kb/s"
        Write-BitrateInfo $channels $bitsPerChannel
    }

    return $audioArgs
}
