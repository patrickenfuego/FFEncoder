<#
    .SYNOPSIS
        Converts, multiplexes, and returns parameters for stereo downmixing
    .DESCRIPTION
        As ffmpeg cannot stream copy and filter simultaneously, this function
        is used to multiplex audio tracks out of their container and convert
        them to stereo separately before being re-added back into the output 
        container at the end of the script. If stream copy is not selected, this 
        function returns the stereo arguments back to the calling function
#>

function Convert-ToStereo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$InputFile,

        [Parameter()]
        [string]$Codec,

        [Parameter()]
        [int]$Bitrate,

        [Parameter()]
        [int]$AudioFrames,

        [Parameter()]
        [bool]$RemuxStream,

        [Parameter()]
        [hashtable]$OutputPath
    )
    #Assign the audio parameter array based on codec
    $audioArgs = switch ($Codec) {
        { @('fdkaac', 'faac') -contains $_ } { 
            Write-Host "** FDK AAC AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'libfdk_aac', '-vbr', 3) }
            elseif (1..5 -contains $Bitrate) { @('-c:a', 'libfdk_aac', '-vbr', $Bitrate) }
            else { @('-c:a', 'libfdk_aac', '-b:a', $Bitrate) }
        }
        { @('dd', 'ac3') -contains $_ } {
            Write-Host "** DOLBY DIGITAL AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'ac3', '-b:a', '192k') }
            else { @('-c:a', 'ac3', '-b:a', $Bitrate) }
        }
        'aac' {
            Write-Host "** AAC AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'aac', '-b:a', '128k') }
            else { @('-c:a', 'aac', '-b:a', $Bitrate) }
        }
        'eac3' {
            Write-Host "** DOLBY DIGITAL PLUS AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'eac3', '-b:a', '128k') }
            else { @('-c:a', 'eac3', '-b:a', $Bitrate) }
        }
        'dts' {
            Write-Host "** DTS AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'dca', '-strict', -2) }
            else { @('-c:a', 'dca', '-b:a', $Bitrate, '-strict', -2) }
        }
        'flac' { 
            Write-Host "** FLAC AUDIO SELECTED - STEREO **" @progressColors
            @('-c:a', 'flac')
        }
        Default { 
            Write-Warning "Could not verify argument array or codec during stereo downmix. Stream will be ignored"
            return $null 
        }
    }
    
    $stereoArgs = $audioArgs + @('-af', 'pan=stereo|FL=0.5*FC+0.707*FL+0.707*BL+0.5*LFE|FR=0.5*FC+0.707*FR+0.707*BR+0.5*LFE')
    [string]$muxedStreamPath = Join-Path -Path $OutputPath.Root -ChildPath "muxed.mkv"

    if ($RemuxStream) {
        Write-Host "Copy stream and audio filtering cannot be used simultaneously. " @warnColors -NoNewline
        Write-Host "Multiplexing audio stream 0 out of the container for conversion..."
        if (Test-Path -Path $muxedStreamPath) {
            Write-Host "Multiplexed audio file found. Skipping creation..." @warnColors
        }
        else { 
            ffmpeg -hide_banner -i $InputFile -loglevel error -map 0:a:0 -c:a copy -map -0:t? -map_chapters -1 `
                -vn -sn $muxedStreamPath
        }
        Write-Host "Downmixing multi-channel audio file to stereo...`n" @progressColors
        if ($PSBoundParameters['AudioFrames']) {
            $AudioFrames = $AudioFrames * 1.5
            ffmpeg -ss 00:01:30 -i $muxedStreamPath -loglevel error -frames:a $AudioFrames $stereoArgs -y $OutputPath.StereoPath
        }
        else {
            ffmpeg -i $muxedStreamPath -loglevel error $stereoArgs -y $OutputPath.StereoPath
            Start-Sleep -Seconds 1
        }

        return $null
    }
    else { 
        Write-Host "Downmixing multi-channel audio stream to stereo...`n" @progressColors
        $stereoArgs = $stereoArgs[1..($stereoArgs.Length - 1)]
        return $stereoArgs 
    }
}

